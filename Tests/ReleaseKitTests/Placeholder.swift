#if canImport(UIKit) && canImport(SwiftUI)
import XCTest
import Foundation
import ReleaseKit

@MainActor final class ReleaseKitSmokeTests:XCTestCase {
    func testStableDefaultsDisableAppAttestAndExperimentalOptInIsExplicit() throws {
        struct Fixture:Decodable {let defaultAppAttest:String;let experimentalAppAttest:String}
        let url=try XCTUnwrap(Bundle.module.url(forResource:"sdk-options",withExtension:"json"))
        let fixture=try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:url))
        let defaults=ReleaseKit.Options()
        switch defaults.appAttest {
        case .disabled:XCTAssertEqual(fixture.defaultAppAttest,"disabled")
        case .automatic:XCTFail("Stable defaults must not enroll in experimental App Attest")
        }
        let experimental=ReleaseKit.Options(appAttest:.automatic)
        switch experimental.appAttest {
        case .automatic:XCTAssertEqual(fixture.experimentalAppAttest,"automatic")
        case .disabled:XCTFail("Explicit experimental opt-in must be retained")
        }
    }
    func testUnconfiguredViewsCanBeConstructed() {
        _ = ReleaseKitChangelogView()
        _ = ReleaseKitSettingsLink()
        XCTAssertNil(ReleaseKit.webChangelogURL)
    }
}
#endif
