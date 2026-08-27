import Foundation
import Combine

class OSRepository: ObservableObject {
    static let shared = OSRepository()

    @Published var availableOSes: [OSImage] = []
    @Published var isLoading = false

    private let osMetadataURL = "https://raw.githubusercontent.com/ipod-master/QEMUBox/main/Resources/OSConfigs/index.json"

    init() {
        fetchAvailableOSes()
    }

    // MARK: - Fetch Available OSes
    func fetchAvailableOSes() {
        DispatchQueue.main.async {
            self.isLoading = true
        }

        // Build a list that includes macOS entries (from earliest Mac OS X to latest) and common Linux images.
        // For macOS we provide placeholders: users must supply their own installer images or recovery files
        // due to Apple licensing. The app will mark recommended variants based on host CPU.

        let macOSes: [OSImage] = [
            OSImage(id: "macos-10.0", name: "Mac OS X", version: "10.0 Cheetah", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.0 (Cheetah) — Installer not bundled. Provide your own installation image."),
            OSImage(id: "macos-10.1", name: "Mac OS X", version: "10.1 Puma", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.1 (Puma) — installer not bundled."),
            OSImage(id: "macos-10.2", name: "Mac OS X", version: "10.2 Jaguar", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.2 (Jaguar)"),
            OSImage(id: "macos-10.3", name: "Mac OS X", version: "10.3 Panther", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.3 (Panther)"),
            OSImage(id: "macos-10.4", name: "Mac OS X", version: "10.4 Tiger", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.4 (Tiger)"),
            OSImage(id: "macos-10.5", name: "Mac OS X", version: "10.5 Leopard", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.5 (Leopard)"),
            OSImage(id: "macos-10.6", name: "Mac OS X", version: "10.6 Snow Leopard", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.6 (Snow Leopard)"),
            OSImage(id: "macos-10.7", name: "Mac OS X", version: "10.7 Lion", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "Mac OS X 10.7 (Lion)"),
            OSImage(id: "macos-10.8", name: "OS X", version: "10.8 Mountain Lion", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "OS X 10.8 (Mountain Lion)"),
            OSImage(id: "macos-10.9", name: "OS X", version: "10.9 Mavericks", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "OS X 10.9 (Mavericks)"),
            OSImage(id: "macos-10.10", name: "OS X", version: "10.10 Yosemite", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "OS X 10.10 (Yosemite)"),
            OSImage(id: "macos-10.11", name: "OS X", version: "10.11 El Capitan", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "OS X 10.11 (El Capitan)"),
            OSImage(id: "macos-10.12", name: "macOS", version: "10.12 Sierra", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 10.12 (Sierra)"),
            OSImage(id: "macos-10.13", name: "macOS", version: "10.13 High Sierra", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 10.13 (High Sierra)"),
            OSImage(id: "macos-10.14", name: "macOS", version: "10.14 Mojave", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 10.14 (Mojave)"),
            OSImage(id: "macos-10.15", name: "macOS", version: "10.15 Catalina", architecture: "x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 10.15 (Catalina)"),
            OSImage(id: "macos-11", name: "macOS", version: "11 Big Sur", architecture: "arm64/x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 11 (Big Sur) — supports both Intel and Apple Silicon variants"),
            OSImage(id: "macos-12", name: "macOS", version: "12 Monterey", architecture: "arm64/x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 12 (Monterey)"),
            OSImage(id: "macos-13", name: "macOS", version: "13 Ventura", architecture: "arm64/x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 13 (Ventura)"),
            OSImage(id: "macos-14", name: "macOS", version: "14 Sonoma", architecture: "arm64/x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 14 (Sonoma) — latest available"),
            // Newly requested placeholders
            OSImage(id: "macos-15", name: "macOS", version: "15", architecture: "arm64/x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 15 — placeholder"),
            OSImage(id: "macos-26", name: "macOS", version: "26", architecture: "arm64/x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 26 — placeholder"),
            OSImage(id: "macos-27", name: "macOS", version: "27", architecture: "arm64/x86_64", downloadURL: "", size: 0, checksum: "", description: "macOS 27 — recommended on Apple Silicon hosts")
        ]

        // Existing Linux/other OS list (kept as before)
        let otherOSes = [
            OSImage(id: "ubuntu-24.04", name: "Ubuntu", version: "24.04 LTS", architecture: "ARM64", downloadURL: "https://cdimage.ubuntu.com/daily-live/current/noble-live-server-arm64.iso", size: 2_000_000_000, checksum: "", description: "Canonical Ubuntu Server - Latest LTS Release"),
            OSImage(id: "ubuntu-22.04", name: "Ubuntu", version: "22.04 LTS", architecture: "ARM64", downloadURL: "https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04-live-server-arm64.iso", size: 1_600_000_000, checksum: "", description: "Canonical Ubuntu Server - Stable LTS Release"),
            OSImage(id: "fedora-40", name: "Fedora", version: "40", architecture: "ARM64", downloadURL: "https://download.fedoraproject.org/pub/fedora/linux/releases/40/Server/aarch64/iso/Fedora-Server-40-1.14-aarch64-dvd.iso", size: 2_200_000_000, checksum: "", description: "Fedora Server - Cutting-edge Linux"),
            OSImage(id: "debian-12", name: "Debian", version: "12 (Bookworm)", architecture: "ARM64", downloadURL: "https://cdimage.debian.org/debian-cd/current/arm64/iso-dvd/debian-12.6.0-arm64-DVD-1.iso", size: 3_700_000_000, checksum: "", description: "Debian Stable - Universal Operating System"),
            OSImage(id: "debian-11", name: "Debian", version: "11 (Bullseye)", architecture: "ARM64", downloadURL: "https://cdimage.debian.org/cdimage/archive/11.8.0/arm64/iso-dvd/debian-11.8.0-arm64-DVD-1.iso", size: 3_600_000_000, checksum: "", description: "Debian Stable - Classic Release"),
            OSImage(id: "alpine-3.19", name: "Alpine Linux", version: "3.19", architecture: "ARM64", downloadURL: "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-standard-3.19.1-aarch64.iso", size: 220_000_000, checksum: "", description: "Alpine Linux - Lightweight & Secure"),
            OSImage(id: "alpine-3.18", name: "Alpine Linux", version: "3.18", architecture: "ARM64", downloadURL: "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/alpine-standard-3.18.6-aarch64.iso", size: 215_000_000, checksum: "", description: "Alpine Linux - Stable Lightweight Release"),
            OSImage(id: "centos-9", name: "CentOS Stream", version: "9", architecture: "ARM64", downloadURL: "https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/aarch64/iso/CentOS-Stream-9-latest-aarch64-dvd1.iso", size: 8_000_000_000, checksum: "", description: "CentOS Stream - Enterprise Linux")
        ]

        // Decide recommended macOS entries based on host CPU
        let recommendedMacs: [OSImage]
        if hostIsAppleSilicon() {
            // Prefer ARM macOS variants (newer macOS versions are available for arm64)
            recommendedMacs = macOSes.filter { $0.architecture.contains("arm64") || $0.architecture.contains("arm64/x86_64") || $0.id == "macos-27" }
        } else {
            // Prefer x86_64 variants
            recommendedMacs = macOSes.filter { $0.architecture.contains("x86_64") || $0.architecture.contains("arm64/x86_64") }
        }

        // Combine recommended macs first, then the rest and other OSes
        var combined: [OSImage] = []
        combined.append(contentsOf: recommendedMacs)
        combined.append(contentsOf: macOSes.filter { mac in !recommendedMacs.contains(where: { $0.id == mac.id }) })
        combined.append(contentsOf: otherOSes)

        DispatchQueue.main.async {
            self.availableOSes = combined
            self.isLoading = false
        }
    }

    // MARK: - Get OS by ID
    func getOS(by id: String) -> OSImage? {
        return availableOSes.first { $0.id == id }
    }

    // MARK: - Search OSes
    func searchOSes(query: String) -> [OSImage] {
        return availableOSes.filter { os in
            os.name.localizedCaseInsensitiveContains(query) ||
            os.version.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Host detection helpers
    private func hostIsAppleSilicon() -> Bool {
        // Use uname to detect architecture; on iOS devices this will usually be arm64.
        var uts = utsname()
        uname(&uts)
        let machineMirror = Mirror(reflecting: uts.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(bitPattern: value)))
        }

        // If the machine string contains "arm64" or begins with "iPhone"/"iPad" considered arm host
        if identifier.contains("arm64") || identifier.lowercased().contains("iphone") || identifier.lowercased().contains("ipad") || identifier.lowercased().contains("apple") {
            return true
        }

        return false
    }
}

// MARK: - OSImage Model
struct OSImage: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let version: String
    let architecture: String
    let downloadURL: String
    let size: UInt64
    let checksum: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case id, name, version, architecture, downloadURL, size, checksum, description
    }
}
