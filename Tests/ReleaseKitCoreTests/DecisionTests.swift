import XCTest
@testable import ReleaseKitCore

final class DecisionTests: XCTestCase {
    func testPresentationIsNotHandledUntilActuallyShownAndDowngradesSkip() {
        var state=LocalState();_=WhatsNewDecider.prepare(version:"3",state:&state)
        XCTAssertEqual(WhatsNewDecider.prepare(version:"4",state:&state),.fetch)
        _=WhatsNewDecider.resolve(version:"4",response:.available,state:&state,now:.now)
        XCTAssertFalse(state.handledVersions.contains("4"))
        XCTAssertEqual(WhatsNewDecider.prepare(version:"4",state:&state),.fetch)
        WhatsNewDecider.markPresented(version:"4",state:&state)
        XCTAssertEqual(WhatsNewDecider.prepare(version:"2",state:&state),.skip)
        XCTAssertEqual(WhatsNewDecider.prepare(version:"4",state:&state),.skip)
    }
    func testOptInFirstLaunchAndHiddenVersion() {
        var state=LocalState()
        XCTAssertEqual(WhatsNewDecider.prepare(version:"4",state:&state,treatFirstLaunchAsUpdate:true),.fetch)
        XCTAssertEqual(WhatsNewDecider.resolve(version:"4",response:.hidden,state:&state,now:.now),.skip)
        XCTAssertEqual(WhatsNewDecider.prepare(version:"4",state:&state),.skip)
    }
    func testVersions() {
        XCTAssertEqual(VersionNumber("4.0.0"), VersionNumber("4"))
        XCTAssertGreaterThan(VersionNumber("4.10"), VersionNumber("4.9"))
        XCTAssertEqual(VersionNumber("2.0b").normalized, "2")
    }
    func testFirstInstallThenUpdate() {
        var state = LocalState()
        XCTAssertEqual(WhatsNewDecider.prepare(version: "3.9", state: &state), .skip)
        XCTAssertEqual(WhatsNewDecider.prepare(version: "4.0", state: &state), .fetch)
        XCTAssertEqual(WhatsNewDecider.resolve(version: "4.0", response: .available, state: &state, now: .now), .show)
        WhatsNewDecider.markPresented(version: "4.0", state: &state)
        XCTAssertEqual(WhatsNewDecider.prepare(version: "4.0.0", state: &state), .skip)
    }
    func testPendingExpiresAndNotLiveDoesNot() {
        var state = LocalState()
        let now = Date(timeIntervalSince1970: 0)
        _ = WhatsNewDecider.resolve(version: "4", response: .notesPending, state: &state, now: now)
        _ = WhatsNewDecider.resolve(version: "4", response: .notesPending, state: &state, now: now.addingTimeInterval(3 * 86400 + 1))
        XCTAssertTrue(state.handledVersions.contains("4"))
        _ = WhatsNewDecider.resolve(version: "5", response: .notLiveYet, state: &state, now: now)
        XCTAssertFalse(state.handledVersions.contains("5"))
    }
}
