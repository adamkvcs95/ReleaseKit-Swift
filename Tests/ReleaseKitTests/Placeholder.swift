#if canImport(UIKit) && canImport(SwiftUI)
import XCTest
import ReleaseKit

@MainActor final class ReleaseKitSmokeTests:XCTestCase {
    func testUnconfiguredViewsCanBeConstructed() {
        _ = ReleaseKitChangelogView()
        _ = ReleaseKitSettingsLink()
        XCTAssertNil(ReleaseKit.webChangelogURL)
    }
}
#endif
