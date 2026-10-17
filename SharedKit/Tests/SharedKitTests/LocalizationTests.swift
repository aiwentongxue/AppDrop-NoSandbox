import Foundation
import Testing
@testable import SharedKit

@Suite struct LocalizationTests {
    @Test func notificationStringsResolveInBothLanguages() {
        let english = SharedText.string("notification.drop.title", locale: Locale(identifier: "en"))
        let chinese = SharedText.string("notification.drop.title", locale: Locale(identifier: "zh-Hans"))
        #expect(english.contains("Price drop"))
        #expect(chinese.contains("降价"))

        let bodyEN = SharedText.string("notification.drop.body", locale: Locale(identifier: "en"))
        let bodyZH = SharedText.string("notification.drop.body", locale: Locale(identifier: "zh-Hans"))
        #expect(bodyEN.contains("%@"))
        #expect(bodyZH.contains("%@"))
    }
}

