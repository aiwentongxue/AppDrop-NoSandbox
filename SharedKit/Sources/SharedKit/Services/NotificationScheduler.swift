import Foundation
import UserNotifications

/// Notification permission state, decoupled from UserNotifications types.
public enum NotificationPermissionStatus: String, Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    public init(_ settingsAuthorization: UNAuthorizationStatus) {
        switch settingsAuthorization {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .provisional: self = .provisional
        case .ephemeral: self = .ephemeral
        @unknown default: self = .unknown
        }
    }
}

/// Payload for one price-drop notification.
public struct PriceDropNotification: Sendable, Equatable {
    public var appName: String
    public var trackId: String
    public var countryCode: String
    public var formattedPrice: String
    public var currency: String
    public var dropPercent: Decimal
    public var isNewLow: Bool
    public var recordID: UUID

    public init(
        appName: String,
        trackId: String,
        countryCode: String,
        formattedPrice: String,
        currency: String,
        dropPercent: Decimal,
        isNewLow: Bool,
        recordID: UUID
    ) {
        self.appName = appName
        self.trackId = trackId
        self.countryCode = countryCode
        self.formattedPrice = formattedPrice
        self.currency = currency
        self.dropPercent = dropPercent
        self.isNewLow = isNewLow
        self.recordID = recordID
    }
}

/// Injectable notification interface (keeps the refresh engine testable).
public protocol UserNotifying: Sendable {
    func permission() async -> NotificationPermissionStatus
    func requestPermission() async -> NotificationPermissionStatus
    /// Returns true when a notification for this payload has been scheduled.
    func sendPriceDrop(_ notification: PriceDropNotification) async -> Bool
}

/// Does nothing; used by tests and diagnostic modes.
public struct NoopNotifier: UserNotifying {
    public init() {}
    public func permission() async -> NotificationPermissionStatus { .notDetermined }
    public func requestPermission() async -> NotificationPermissionStatus { .notDetermined }
    public func sendPriceDrop(_ notification: PriceDropNotification) async -> Bool { false }
}

/// Localized strings that live inside the SharedKit resource bundle.
public enum SharedText {
    /// Looks a string up in the SharedKit bundle for an explicit locale.
    /// `String(localized:bundle:locale:)` only uses the locale for formatting,
    /// so the `.lproj` directory is resolved explicitly here.
    public static func string(_ key: String, locale: Locale? = nil) -> String {
        let target = locale ?? .current
        if let bundle = bundle(for: target) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return Bundle.module.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func bundle(for locale: Locale) -> Bundle? {
        var candidates: [String] = [locale.identifier]
        if let language = locale.language.languageCode?.identifier {
            candidates.append(language)
        }
        if locale.identifier.lowercased().hasPrefix("zh") {
            candidates.append("zh-Hans")
        }
        for candidate in candidates {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }
}

/// UserNotifications backed scheduler used by both the app and the helper.
/// The permission identity is the bundle of the calling process, which is why
/// the embedded helper requests its own authorization once.
public final class UserNotificationScheduler: UserNotifying, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func permission() async -> NotificationPermissionStatus {
        let settings = await center.notificationSettings()
        return NotificationPermissionStatus(settings.authorizationStatus)
    }

    public func requestPermission() async -> NotificationPermissionStatus {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return await permission()
    }

    public func sendPriceDrop(_ notification: PriceDropNotification) async -> Bool {
        let status = await permission()
        guard status == .authorized || status == .provisional else {
            AppLog.info("notification skipped: permission is \(status.rawValue)")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = String(format: SharedText.string("notification.drop.title"), notification.appName)
        let country = StoreCountry.displayCode(for: notification.countryCode)
        let percent = PriceFormatting.percentString(notification.dropPercent) + "%"
        let bodyKey = notification.isNewLow ? "notification.drop.body.newLow" : "notification.drop.body"
        content.body = String(
            format: SharedText.string(bodyKey),
            notification.formattedPrice,
            country,
            percent
        )
        content.sound = .default
        content.userInfo = [
            "trackId": notification.trackId,
            "countryCode": notification.countryCode,
            "recordID": notification.recordID.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: "price-drop-\(notification.recordID.uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
            return true
        } catch {
            AppLog.error("notification could not be scheduled: \(error.localizedDescription)")
            return false
        }
    }
}

