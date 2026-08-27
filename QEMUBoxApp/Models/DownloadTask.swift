import Foundation

struct DownloadTask: Identifiable, Codable {
    let id: String
    let osId: String
    let osName: String
    let downloadURL: String
    let fileName: String
    let totalSize: UInt64
    let vmName: String
    let cpuCores: Int
    let ramGB: Int
    var progress: Double
    var status: DownloadStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, osId, osName, downloadURL, fileName, totalSize, vmName, cpuCores, ramGB, progress, status, createdAt
    }
}

enum DownloadStatus: String, Codable {
    case downloading
    case paused
    case completed
    case failed
}
