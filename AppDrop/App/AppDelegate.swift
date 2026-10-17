import AppKit
import SharedKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var environment: AppEnvironment?

    /// Diagnostics for window lifecycle behaviour (verified against the real
    /// "close last window" requirement).
    private var lifecycleLogURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("appdrop-window-lifecycle.log")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.info("applicationDidFinishLaunching", fileURL: lifecycleLogURL)
        let logURL = lifecycleLogURL
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { note in
            let window = note.object as? NSWindow
            let title = window?.title ?? "-"
            DispatchQueue.main.async {
                let visible = NSApp.windows.filter { $0.isVisible && $0.canBecomeMain }
                AppLog.info("window willClose: \"\(title)\" visibleWindows=\(visible.count)", fileURL: logURL)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppLog.info("applicationShouldTerminateAfterLastWindowClosed -> true", fileURL: lifecycleLogURL)
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppLog.info("applicationShouldTerminate", fileURL: lifecycleLogURL)
        return .terminateNow
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        AppLog.info("openFiles event: \(filenames)")
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        if let environment {
            environment.handleIncomingFiles(urls)
        } else {
            AppEventBus.shared.queuedFileURLs.append(contentsOf: urls)
        }
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppLog.info("open urls event: \(urls.map(\.path))")
        if let environment {
            environment.handleIncomingFiles(urls)
        } else {
            AppEventBus.shared.queuedFileURLs.append(contentsOf: urls)
        }
    }
}

