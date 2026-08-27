import Foundation
import Combine

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadTask] = []
    @Published var totalProgress: Double = 0

    private var urlSessions: [String: URLSession] = [:] // keyed by DownloadTask.id
    private var taskIdToDownloadId: [Int: String] = [:] // URLSessionDownloadTask.taskIdentifier -> DownloadTask.id
    private var downloadTasksById: [String: URLSessionDownloadTask] = [:]

    private let fileManager = FileManager.default
    private let downloadsDirectoryURL: URL
    private let resumeDataDirectoryURL: URL
    private let vmManager = VMManager.shared

    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.qemubox.downloads")
        config.waitsForConnectivity = true
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        downloadsDirectoryURL = documentsURL.appendingPathComponent("QEMUBox_Downloads", isDirectory: true)
        resumeDataDirectoryURL = downloadsDirectoryURL.appendingPathComponent("resume", isDirectory: true)
        try? fileManager.createDirectory(at: downloadsDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: resumeDataDirectoryURL, withIntermediateDirectories: true)

        loadDownloads()
        restoreDownloads()
    }

    // MARK: - Public: Background completion handler
    func setBackgroundSessionCompletionHandler(_ handler: @escaping () -> Void) {
        backgroundCompletionHandler = handler
    }

    // MARK: - Download OS
    func downloadOS(_ os: OSImage, vmName: String, cpuCores: Int, ramGB: Int, completion: @escaping (Bool) -> Void) {
        let downloadTask = DownloadTask(
            id: UUID().uuidString,
            osId: os.id,
            osName: os.name,
            downloadURL: os.downloadURL,
            fileName: "\(os.name)-\(os.version).iso",
            totalSize: os.size,
            vmName: vmName,
            cpuCores: cpuCores,
            ramGB: ramGB,
            progress: 0,
            status: .downloading,
            createdAt: Date()
        )

        DispatchQueue.main.async {
            self.downloads.append(downloadTask)
            self.saveDownloads()
        }

        let destinationURL = downloadsDirectoryURL.appendingPathComponent(downloadTask.fileName)

        // Start download via URLSession background task
        startDownload(for: downloadTask, to: destinationURL, completion: completion)
    }

    // MARK: - Start download (new or resume)
    private func startDownload(for download: DownloadTask, to destinationURL: URL, completion: @escaping (Bool) -> Void) {
        // If resume data exists, resume
        let resumeURL = resumeDataURL(for: download.id)
        if fileManager.fileExists(atPath: resumeURL.path), let data = try? Data(contentsOf: resumeURL) {
            let task = session.downloadTask(withResumeData: data)
            register(task: task, for: download)
            task.resume()
            completion(true)
            return
        }

        guard let url = URL(string: download.downloadURL) else {
            updateDownloadStatus(download.id, status: .failed)
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(Int.max)

        let task = session.downloadTask(with: request)
        register(task: task, for: download)
        task.resume()

        completion(true)
    }

    private func register(task: URLSessionDownloadTask, for download: DownloadTask) {
        taskIdToDownloadId[task.taskIdentifier] = download.id
        downloadTasksById[download.id] = task
        urlSessions[download.id] = session
    }

    // MARK: - Pause Download
    func pauseDownload(_ taskId: String) {
        if let task = downloadTasksById[taskId] {
            task.cancel(byProducingResumeData: { data in
                if let data = data {
                    try? data.write(to: self.resumeDataURL(for: taskId))
                }
                DispatchQueue.main.async {
                    self.updateDownloadStatus(taskId, status: .paused)
                    self.downloadTasksById.removeValue(forKey: taskId)
                    self.taskIdToDownloadId = self.taskIdToDownloadId.filter { $0.value != taskId }
                    self.saveDownloads()
                }
            })
        } else {
            // No active URLSession task — just mark paused
            updateDownloadStatus(taskId, status: .paused)
            saveDownloads()
        }
    }

    // MARK: - Resume Download
    func resumeDownload(_ taskId: String) {
        guard let download = downloads.first(where: { $0.id == taskId }) else { return }
        updateDownloadStatus(taskId, status: .downloading)
        saveDownloads()

        let destinationURL = downloadsDirectoryURL.appendingPathComponent(download.fileName)
        startDownload(for: download, to: destinationURL) { _ in }
    }

    // MARK: - Cancel Download
    func cancelDownload(_ taskId: String) {
        if let task = downloadTasksById[taskId] {
            task.cancel()
            downloadTasksById.removeValue(forKey: taskId)
            taskIdToDownloadId = taskIdToDownloadId.filter { $0.value != taskId }
        }

        // Remove resume data
        try? fileManager.removeItem(at: resumeDataURL(for: taskId))

        // Remove file
        if let download = downloads.first(where: { $0.id == taskId }) {
            let fileURL = downloadsDirectoryURL.appendingPathComponent(download.fileName)
            try? fileManager.removeItem(at: fileURL)
        }

        downloads.removeAll { $0.id == taskId }
        saveDownloads()
        updateTotalProgress()
    }

    // MARK: - Update Download Status
    private func updateDownloadStatus(_ taskId: String, status: DownloadStatus) {
        DispatchQueue.main.async {
            if let index = self.downloads.firstIndex(where: { $0.id == taskId }) {
                self.downloads[index].status = status
                self.saveDownloads()
            }
        }
    }

    // MARK: - Update Progress
    private func updateProgress(_ taskId: String, progress: Double) {
        DispatchQueue.main.async {
            if let index = self.downloads.firstIndex(where: { $0.id == taskId }) {
                self.downloads[index].progress = progress
                self.updateTotalProgress()
                self.saveDownloads()
            }
        }
    }

    // MARK: - Update Total Progress
    private func updateTotalProgress() {
        guard !downloads.isEmpty else {
            totalProgress = 0
            return
        }

        let avgProgress = downloads.map { $0.progress }.reduce(0, +) / Double(downloads.count)
        totalProgress = avgProgress
    }

    // MARK: - Persistence
    private var persistedDownloadsURL: URL {
        return downloadsDirectoryURL.appendingPathComponent("downloads.json")
    }

    private func saveDownloads() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(downloads) {
            try? data.write(to: persistedDownloadsURL)
        }
    }

    private func loadDownloads() {
        if let data = try? Data(contentsOf: persistedDownloadsURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let saved = try? decoder.decode([DownloadTask].self, from: data) {
                downloads = saved
            }
        }
    }

    private func resumeDataURL(for id: String) -> URL {
        return resumeDataDirectoryURL.appendingPathComponent("\(id).resume")
    }

    // MARK: - Restore Downloads
    func restoreDownloads() {
        // Mark completed downloads if file present
        for i in 0..<downloads.count {
            let d = downloads[i]
            let fileURL = downloadsDirectoryURL.appendingPathComponent(d.fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                updateDownloadStatus(d.id, status: .completed)
            }
        }

        // Resume any downloads that were in progress
        for download in downloads where download.status == .downloading {
            let destinationURL = downloadsDirectoryURL.appendingPathComponent(download.fileName)
            startDownload(for: download, to: destinationURL) { _ in }
        }
    }

    // MARK: - Create VM from Download
    private func createVMFromDownload(_ downloadTask: DownloadTask, osImagePath: URL) {
        let vm = vmManager.createVM(
            name: downloadTask.vmName,
            osType: downloadTask.osName,
            osPath: osImagePath,
            cpuCores: downloadTask.cpuCores,
            ramGB: downloadTask.ramGB
        )

        print("VM created: \(vm.name)")
    }
}

// MARK: - URLSessionDelegate
extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloadId = taskIdToDownloadId[downloadTask.taskIdentifier],
              let index = downloads.firstIndex(where: { $0.id == downloadId }) else { return }

        let destinationURL = downloadsDirectoryURL.appendingPathComponent(downloads[index].fileName)

        // Remove existing file if present
        try? fileManager.removeItem(at: destinationURL)

        do {
            try fileManager.moveItem(at: location, to: destinationURL)
            updateDownloadStatus(downloadId, status: .completed)

            // Cleanup resume data
            try? fileManager.removeItem(at: resumeDataURL(for: downloadId))

            // Remove mappings
            downloadTasksById.removeValue(forKey: downloadId)
            taskIdToDownloadId = taskIdToDownloadId.filter { $0.value != downloadId }

            // Create VM from the downloaded image
            createVMFromDownload(downloads[index], osImagePath: destinationURL)
        } catch {
            print("File move error: \(error.localizedDescription)")
            updateDownloadStatus(downloadId, status: .failed)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        guard let downloadId = taskIdToDownloadId[downloadTask.taskIdentifier] else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        updateProgress(downloadId, progress: progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error as NSError? {
            // Try extract resume data
            if let resumeData = err.userInfo[NSURLSessionDownloadTaskResumeData] as? Data,
               let downloadId = taskIdToDownloadId[task.taskIdentifier] {
                try? resumeData.write(to: resumeDataURL(for: downloadId))
                updateDownloadStatus(downloadId, status: .paused)
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
