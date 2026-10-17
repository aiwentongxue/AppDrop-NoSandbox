import Foundation
import SharedKit

/// App-side localization helper. UI strings live in `Localizable.xcstrings`;
/// notification strings live in the SharedKit bundle (`SharedText`).
enum AppStrings {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }

    /// Localized storefront name, falling back to the English name (and then
    /// to the uppercased code) when the catalog has no entry for the region.
    static func regionName(_ code: String) -> String {
        let key = "region.\(StoreCountry.normalized(code)).name"
        let localized = String(localized: String.LocalizationValue(key))
        return localized == key ? StoreCountry.displayName(for: code) : localized
    }

    /// "中国香港 (HK)" / "Hong Kong (HK)" — used by every region picker.
    static func regionLabel(_ code: String) -> String {
        let name = regionName(code)
        let displayCode = StoreCountry.displayCode(for: code)
        guard !name.isEmpty, name.caseInsensitiveCompare(displayCode) != .orderedSame else {
            return displayCode
        }
        return "\(name) (\(displayCode))"
    }
}

