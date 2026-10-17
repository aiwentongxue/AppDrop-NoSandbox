import AppKit
import SharedKit

// Headless diagnostic entry points used by integration scripts. In normal use
// the process simply runs the SwiftUI application.
//
//   --dump-store-info     print the shared store report as JSON
//   --backend-status      print the SMAppService registration state
//   --register-backend    register the background helper, then print the state
//   --unregister-backend  unregister the background helper, then print the state

let launchArguments = Array(CommandLine.arguments.dropFirst())

func hasLaunchFlag(_ flag: String) -> Bool {
    launchArguments.contains(flag)
}

if hasLaunchFlag("--dump-store-info") {
    do {
        let container = try SharedStore.makeContainer()
        let report = try await Diagnostics.storeInfo(container: container)
        print(Diagnostics.jsonString(report))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

if hasLaunchFlag("--store-diagnose") {
    var lines: [String] = []
    lines.append("process: \(ProcessInfo.processInfo.processName) pid=\(ProcessInfo.processInfo.processIdentifier)")
    lines.append("HOME: \(ProcessInfo.processInfo.environment["HOME"] ?? "-")")
    lines.append("sandbox container id: \(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] ?? "-")")
    lines.append("storage root: \(SharedStore.resolvedStorageRoot?.url.path ?? "<none>")")
    lines.append("storeURL: \(String(describing: try? SharedStore.storeURL()))")

    if let support = try? SharedStore.supportDirectoryURL() {
        let probe = support.appendingPathComponent("probe-\(UUID().uuidString).txt")
        do {
            try "probe".write(to: probe, atomically: true, encoding: .utf8)
            lines.append("local storage write: OK")
            try? FileManager.default.removeItem(at: probe)
        } catch {
            lines.append("local storage write: FAILED \(error)")
        }
    } else {
        lines.append("local storage write: support directory unavailable")
    }

    do {
        _ = try SharedStore.makeContainer()
        lines.append("ModelContainer: OK")
    } catch {
        let nsError = error as NSError
        lines.append("ModelContainer: FAILED")
        lines.append("error: \(error)")
        lines.append("nsError: domain=\(nsError.domain) code=\(nsError.code)")
        lines.append("userInfo: \(nsError.userInfo)")
        lines.append("reflected: \(String(reflecting: error))")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append("underlying: domain=\(underlying.domain) code=\(underlying.code) userInfo=\(underlying.userInfo)")
        }
    }

    let text = lines.joined(separator: "\n")
    print(text)
    let tempTarget = FileManager.default.temporaryDirectory.appendingPathComponent("appdrop-diagnose.txt")
    try? text.write(to: tempTarget, atomically: true, encoding: .utf8)
    if let support = try? SharedStore.supportDirectoryURL() {
        try? text.write(to: support.appendingPathComponent("diagnose.txt"), atomically: true, encoding: .utf8)
    }
    exit(0)
}

if hasLaunchFlag("--backend-status") || hasLaunchFlag("--register-backend") || hasLaunchFlag("--unregister-backend") {
    let backend = BackendManager()
    do {
        if hasLaunchFlag("--register-backend") {
            try backend.enable()
        }
        if hasLaunchFlag("--unregister-backend") {
            try backend.disable()
        }
        backend.refreshStatus()
        print("backend-state: \(backend.state.rawValue)")
        exit(0)
    } catch {
        print("backend-state: error")
        FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

AppDropApp.main()

