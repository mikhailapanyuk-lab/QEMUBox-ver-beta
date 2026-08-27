import Foundation

final class QEMUWrapper {
    private var qemuProcess: Process?
    private let fileManager = FileManager.default

    // MARK: - Public
    static let shared = QEMUWrapper()

    // MARK: - Launch QEMU
    func launchQEMU(for vm: VirtualMachine) throws {
        let qemuPath = getQEMUPath()

        guard fileManager.fileExists(atPath: qemuPath) else {
            throw QEMUError.qemuNotFound
        }

        let useJIT = isJITAvailable()
        let arguments = buildQEMUArguments(for: vm, useJIT: useJIT)

        qemuProcess = Process()
        qemuProcess?.executableURL = URL(fileURLWithPath: qemuPath)
        qemuProcess?.arguments = arguments

        let pipe = Pipe()
        qemuProcess?.standardOutput = pipe
        qemuProcess?.standardError = pipe

        do {
            try qemuProcess?.run()
        } catch {
            throw QEMUError.launchFailed(error.localizedDescription)
        }
    }

    // MARK: - Stop QEMU
    func stopQEMU(vmId: String) {
        if let process = qemuProcess, process.isRunning {
            process.terminate()
            qemuProcess = nil
        }
    }

    // MARK: - Build QEMU Arguments
    private func buildQEMUArguments(for vm: VirtualMachine, useJIT: Bool) -> [String] {
        var args: [String] = []

        // Acceleration: use TCG (dynarec) when available; KVM/hypervisor is not expected on iOS
        if useJIT {
            // TCG is the dynamic translator used by QEMU when running guests on incompatible hosts
            args.append(contentsOf: ["-accel", "tcg"])
        }

        // CPU configuration
        args.append(contentsOf: ["-cpu", "cortex-a72"])
        args.append(contentsOf: ["-smp", "cpus=\(vm.cpuCores)"])

        // Memory configuration
        args.append(contentsOf: ["-m", "\(vm.ramGB)G"])

        // Machine type (ARM64)
        args.append(contentsOf: ["-machine", "virt,gic-version=3"])

        // Storage configuration
        args.append(contentsOf: ["-drive", "file=\(vm.osImagePath),format=raw,if=virtio"])

        // Network configuration
        args.append(contentsOf: ["-net", "nic,model=virtio", "-net", "user,hostfwd=tcp::2222-:22"])

        // Display configuration
        args.append(contentsOf: ["-display", "none"])

        // Serial console
        args.append(contentsOf: ["-serial", "stdio"])

        // Daemonize (keep behavior consistent with prior implementation)
        args.append("-daemonize")

        return args
    }

    // MARK: - JIT / Environment Detection
    private func isDeviceJailbroken() -> Bool {
        let markers = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        return markers.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Checks whether an on-device JIT is available. Strategy:
    /// 1. If a bundled small helper `jit_test` exists, run it and return true if exit code 0.
    /// 2. Otherwise, check for known marker files produced by JIT-enabler packages.
    private func isJITAvailable() -> Bool {
        // First, if not jailbroken, we should not expect JIT
        if !isDeviceJailbroken() { return false }

        // Look for bundled runtime helper (app may bundle or Packaging may place it in /usr/local/bin)
        let helperPaths = [
            Bundle.main.path(forResource: "jit_test", ofType: nil),
            "/usr/local/bin/jit_test",
            "/usr/bin/jit_test",
            "/var/mobile/jit_test"
        ].compactMap { $0 }

        for path in helperPaths {
            if fileManager.isExecutableFile(atPath: path) {
                // Run the helper synchronously and check exit code
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: path)
                proc.arguments = []
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus == 0 {
                        return true
                    }
                } catch {
                    // ignore and fallback to marker check
                }
            }
        }

        // Fallback: check for known JIT-enabler markers (adjust these to match the packages you support)
        let altJITMarkers = [
            "/usr/lib/altjit.dylib",
            "/Library/AltJIT/altjit.dylib",
            "/usr/lib/TrollStore/TrollStore.dylib"
        ]
        if altJITMarkers.contains(where: { fileManager.fileExists(atPath: $0) }) {
            return true
        }

        // As a conservative default on jailbroken devices we can try to assume JIT can be enabled by the packaging approach,
        // but returning false avoids claiming acceleration incorrectly.
        return false
    }

    // MARK: - Get QEMU Path
    private func getQEMUPath() -> String {
        let paths = [
            "/usr/local/bin/qemu-system-aarch64",
            "/usr/bin/qemu-system-aarch64",
            "/opt/qemu/bin/qemu-system-aarch64",
            "/var/mobile/qemu/bin/qemu-system-aarch64"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return "/usr/local/bin/qemu-system-aarch64"
    }

    // MARK: - Get QEMU Version
    func getQEMUVersion() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: getQEMUPath())
        process.arguments = ["-version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Check QEMU Installation
    func isQEMUInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: getQEMUPath())
    }
}

// MARK: - QEMU Error
enum QEMUError: LocalizedError {
    case qemuNotFound
    case launchFailed(String)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .qemuNotFound:
            return "QEMU is not installed on this device"
        case .launchFailed(let reason):
            return "Failed to launch QEMU: \(reason)"
        case .invalidConfiguration:
            return "Invalid VM configuration"
        }
    }
}
