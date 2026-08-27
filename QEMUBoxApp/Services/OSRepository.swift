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
        
        // Local OS configurations
        let localOSes = [
            OSImage(
                id: "ubuntu-24.04",
                name: "Ubuntu",
                version: "24.04 LTS",
                architecture: "ARM64",
                downloadURL: "https://cdimage.ubuntu.com/daily-live/current/noble-live-server-arm64.iso",
                size: 2_000_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "Canonical Ubuntu Server - Latest LTS Release"
            ),
            OSImage(
                id: "ubuntu-22.04",
                name: "Ubuntu",
                version: "22.04 LTS",
                architecture: "ARM64",
                downloadURL: "https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04-live-server-arm64.iso",
                size: 1_600_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "Canonical Ubuntu Server - Stable LTS Release"
            ),
            OSImage(
                id: "fedora-40",
                name: "Fedora",
                version: "40",
                architecture: "ARM64",
                downloadURL: "https://download.fedoraproject.org/pub/fedora/linux/releases/40/Server/aarch64/iso/Fedora-Server-40-1.14-aarch64-dvd.iso",
                size: 2_200_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "Fedora Server - Cutting-edge Linux"
            ),
            OSImage(
                id: "debian-12",
                name: "Debian",
                version: "12 (Bookworm)",
                architecture: "ARM64",
                downloadURL: "https://cdimage.debian.org/debian-cd/current/arm64/iso-dvd/debian-12.6.0-arm64-DVD-1.iso",
                size: 3_700_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "Debian Stable - Universal Operating System"
            ),
            OSImage(
                id: "debian-11",
                name: "Debian",
                version: "11 (Bullseye)",
                architecture: "ARM64",
                downloadURL: "https://cdimage.debian.org/cdimage/archive/11.8.0/arm64/iso-dvd/debian-11.8.0-arm64-DVD-1.iso",
                size: 3_600_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "Debian Stable - Classic Release"
            ),
            OSImage(
                id: "alpine-3.19",
                name: "Alpine Linux",
                version: "3.19",
                architecture: "ARM64",
                downloadURL: "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-standard-3.19.1-aarch64.iso",
                size: 220_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "Alpine Linux - Lightweight & Secure"
            ),
            OSImage(
                id: "alpine-3.18",
                name: "Alpine Linux",
                version: "3.18",
                architecture: "ARM64",
                downloadURL: "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/alpine-standard-3.18.6-aarch64.iso",
                size: 215_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "Alpine Linux - Stable Lightweight Release"
            ),
            OSImage(
                id: "centos-9",
                name: "CentOS Stream",
                version: "9",
                architecture: "ARM64",
                downloadURL: "https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/aarch64/iso/CentOS-Stream-9-latest-aarch64-dvd1.iso",
                size: 8_000_000_000,
                checksum: "",
                fileType: "iso",
                postProcessHint: nil,
                description: "CentOS Stream - Enterprise Linux"
            ),
            // macOS entries: NOTE — these DO NOT include Apple installer files. Users must supply or host pre-built macOS qcow2/raw images.
            OSImage(
                id: "macos-monterey",
                name: "macOS",
                version: "Monterey",
                architecture: "x86_64",
                downloadURL: "",
                size: 25_000_000_000,
                checksum: "",
                fileType: "qcow2",
                postProcessHint: "Provide a pre-built macOS qcow2 image; see Documentation/INSTALLATION.md for conversion instructions.",
                description: "macOS Monterey (user-supplied qcow2/raw image required)"
            ),
            OSImage(
                id: "macos-ventura",
                name: "macOS",
                version: "Ventura",
                architecture: "x86_64",
                downloadURL: "",
                size: 30_000_000_000,
                checksum: "",
                fileType: "qcow2",
                postProcessHint: "Provide a pre-built macOS qcow2 image; see Documentation/INSTALLATION.md for conversion instructions.",
                description: "macOS Ventura (user-supplied qcow2/raw image required)"
            ),
            OSImage(
                id: "macos-sonoma",
                name: "macOS",
                version: "Sonoma",
                architecture: "x86_64",
                downloadURL: "",
                size: 35_000_000_000,
                checksum: "",
                fileType: "qcow2",
                postProcessHint: "Provide a pre-built macOS qcow2 image; see Documentation/INSTALLATION.md for conversion instructions.",
                description: "macOS Sonoma (user-supplied qcow2/raw image required)"
            )
        ]
        
        DispatchQueue.main.async {
            self.availableOSes = localOSes
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
}

// MARK: - OSImage Model
struct OSImage: Identifiable, Codable {
    let id: String
    let name: String
    let version: String
    let architecture: String
    let downloadURL: String
    let size: UInt64
    let checksum: String
    let fileType: String
    let postProcessHint: String?
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, version, architecture, downloadURL, size, checksum, fileType, postProcessHint, description
    }
}
