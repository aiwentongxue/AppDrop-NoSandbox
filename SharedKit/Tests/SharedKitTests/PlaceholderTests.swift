import Testing
@testable import SharedKit

@Suite struct SharedConstantsTests {
    @Test func sharedConstantsAreConsistent() {
        #expect(SharedConstants.storageDirectoryName == "AppDropNoSandbox")
        #expect(SharedConstants.supportedCountryCodes == [
            "us", "cn", "hk", "tw", "jp", "gb", "de", "ca", "au",
            "fr", "kr", "sg", "tr", "ng", "ar", "br", "in"
        ])
        #expect(SharedConstants.supportedCountryCodes == StoreCountry.codes)
        #expect(SharedConstants.isSupportedCountry("US"))
        #expect(SharedConstants.isSupportedCountry("GB"))
        #expect(SharedConstants.isSupportedCountry("tw"))
        #expect(!SharedConstants.isSupportedCountry("zz"))
        #expect(SharedConstants.helperBundleIdentifier == "com.appdrop.nosandbox.helper")
        #expect(SharedConstants.helperAgentPlistName == "com.appdrop.nosandbox.helper.plist")
        #expect(SharedConstants.wishdropFormatVersion == 1)
    }
}

