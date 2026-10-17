import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var eventBus = AppEventBus.shared

    var body: some View {
        Group {
            if let startupError = environment.startupError {
                StartupErrorView(message: startupError)
            } else if environment.showOnboarding {
                OnboardingView()
            } else {
                MainWindowView()
            }
        }
        .frame(minWidth: 940, minHeight: 580)
        .onChange(of: eventBus.queuedFileURLs) { _, urls in
            guard !urls.isEmpty else { return }
            environment.handleIncomingFiles(urls)
            eventBus.queuedFileURLs = []
        }
        .task {
            // Files opened before the environment was wired up (cold start via
            // Finder) are drained here.
            if !eventBus.queuedFileURLs.isEmpty {
                environment.handleIncomingFiles(eventBus.queuedFileURLs)
                eventBus.queuedFileURLs = []
            }
        }
    }
}

/// Shown when the shared local storage directory cannot be opened. AppDrop
/// refuses to fall back to a different database so both processes share one store.
struct StartupErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(AppStrings.string("startup.title"), systemImage: "exclamationmark.triangle")
                .font(.title2)
                .bold()
            Text(AppStrings.string("startup.body"))
                .foregroundStyle(.secondary)
            Text(AppStrings.string("startup.storageHint"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.12)))
            ScrollView {
                Text(message)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
            HStack {
                Spacer()
                Button(AppStrings.string("startup.quit")) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
    }
}

