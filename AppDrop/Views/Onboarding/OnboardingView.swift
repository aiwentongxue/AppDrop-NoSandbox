import SwiftUI
import SharedKit

/// First-run flow: welcome, default storefront, notification permission,
/// background helper registration (with its own permission warm-up) and a
/// summary. The onboarding flag is only stored after the flow completes.
struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private enum Step: Int, CaseIterable {
        case welcome
        case region
        case notifications
        case background
        case summary

        var titleKey: String {
            switch self {
            case .welcome: return "onboarding.welcome.title"
            case .region: return "onboarding.region.title"
            case .notifications: return "onboarding.notifications.title"
            case .background: return "onboarding.background.title"
            case .summary: return "onboarding.summary.title"
            }
        }

        var bodyKey: String {
            switch self {
            case .welcome: return "onboarding.welcome.body"
            case .region: return "onboarding.region.body"
            case .notifications: return "onboarding.notifications.body"
            case .background: return "onboarding.background.body"
            case .summary: return "onboarding.summary.body"
            }
        }
    }

    @State private var step: Step = .welcome
    @State private var notificationStatus: NotificationPermissionStatus = .notDetermined
    @State private var isRequestingNotifications = false
    @State private var enableBackground = true
    @State private var backendBusy = false
    @State private var backendError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            footer
        }
        .padding(36)
        .task {
            notificationStatus = await environment.notificationScheduler.permission()
            environment.backend.refreshStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppStrings.string(step.titleKey))
                .font(.system(size: 26, weight: .semibold))
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { candidate in
                    Capsule()
                        .fill(candidate.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: candidate == step ? 26 : 10, height: 6)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Text(AppStrings.string(step.bodyKey))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        switch step {
        case .welcome:
            EmptyView()
        case .region:
            regionPicker
        case .notifications:
            notificationsSection
        case .background:
            backgroundSection
        case .summary:
            summarySection
        }
    }

    private var regionPicker: some View {
        Picker(AppStrings.string("settings.defaultRegion"), selection: Binding(
            get: { environment.defaultCountryCode },
            set: { environment.setDefaultCountryCode($0) }
        )) {
            ForEach(SharedConstants.supportedCountryCodes, id: \.self) { code in
                Text(AppStrings.regionLabel(code)).tag(code)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 380)
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(AppStrings.string("settings.notificationStatus") + ":")
                Text(AppStrings.string(notificationStatusKey(notificationStatus)))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button(AppStrings.string("settings.requestNotification")) {
                    isRequestingNotifications = true
                    Task {
                        notificationStatus = await environment.notificationScheduler.requestPermission()
                        isRequestingNotifications = false
                    }
                }
                .disabled(isRequestingNotifications || notificationStatus == .authorized)
                if isRequestingNotifications {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(AppStrings.string("onboarding.useBackground"), isOn: $enableBackground)
                .toggleStyle(.switch)
                .onChange(of: enableBackground) { _, enabled in
                    guard step == .background else { return }
                    if enabled {
                        registerAndWarmUp()
                    }
                }
            if backendBusy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(AppStrings.string("common.working"))
                }
            }
            if let backendError {
                Text(backendError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Text(AppStrings.format(
                "settings.backgroundStateFormat",
                AppStrings.string(backendStateKey(environment.backend.state))
            ))
            .font(.callout)
            if environment.backend.state == .requiresApproval {
                Text(AppStrings.string("settings.backend.requiresApprovalHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(AppStrings.string("settings.helperPermissionHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStrings.format("onboarding.summary.region", StoreCountry.displayCode(for: environment.defaultCountryCode)))
            Text(AppStrings.format(
                "onboarding.summary.background",
                AppStrings.string(environment.backend.state == .notRegistered
                    ? "onboarding.disabled"
                    : "onboarding.enabled")
            ))
            Text(AppStrings.format(
                "onboarding.summary.notifications",
                AppStrings.string(notificationStatusKey(notificationStatus))
            ))
        }
        .font(.callout)
    }

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button(AppStrings.string("common.back")) {
                    if let previous = Step(rawValue: step.rawValue - 1) {
                        step = previous
                    }
                }
            }
            Spacer()
            if step == .summary {
                Button(AppStrings.string("onboarding.finish")) {
                    environment.completeOnboarding()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Button(AppStrings.string("common.continue")) {
                    if let next = Step(rawValue: step.rawValue + 1) {
                        step = next
                        if step == .background {
                            registerAndWarmUp()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func registerAndWarmUp() {
        guard !backendBusy else { return }
        backendBusy = true
        backendError = nil
        Task {
            do {
                try environment.backend.enable()
            } catch {
                backendError = error.localizedDescription
            }
            environment.backend.refreshStatus()
            if enableBackground, environment.backend.state != .notRegistered {
                let output = await environment.backend.warmUpHelperNotifications()
                if let output, !output.isEmpty {
                    AppLog.info("helper warm-up output: \(output)")
                }
            }
            backendBusy = false
        }
    }
}

func notificationStatusKey(_ status: NotificationPermissionStatus) -> String {
    switch status {
    case .notDetermined: return "permission.notDetermined"
    case .denied: return "permission.denied"
    case .authorized: return "permission.authorized"
    case .provisional: return "permission.provisional"
    case .ephemeral: return "permission.ephemeral"
    case .unknown: return "permission.unknown"
    }
}

func backendStateKey(_ state: BackendState) -> String {
    switch state {
    case .notRegistered: return "settings.backend.notRegistered"
    case .enabled: return "settings.backend.enabled"
    case .requiresApproval: return "settings.backend.requiresApproval"
    case .notFound: return "settings.backend.notFound"
    case .unknown: return "settings.backend.unknown"
    }
}

