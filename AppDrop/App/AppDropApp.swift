import SwiftData
import SwiftUI

struct AppDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .modifier(OptionalModelContainer(container: environment.container))
                .onAppear {
                    appDelegate.environment = environment
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button(AppStrings.string("toolbar.refresh")) {
                    Task { await environment.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

/// Applies `.modelContainer` only when the shared store could be opened; if
/// startup failed, `RootView` shows the error screen instead.
struct OptionalModelContainer: ViewModifier {
    let container: ModelContainer?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let container {
            content.modelContainer(container)
        } else {
            content
        }
    }
}

