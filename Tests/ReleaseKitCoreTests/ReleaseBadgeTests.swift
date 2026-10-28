import XCTest
@testable import ReleaseKitCore
final class ReleaseBadgeTests:XCTestCase {
    func testInstalledVersionIsNormalizedAndTakesPriority() {
        XCTAssertEqual(ReleaseBadge.resolve(version:"4.0",installed:"4.0.0",latest:"4.0"),.installed)
        XCTAssertNil(ReleaseBadge.resolve(version:"3.0",installed:"4.0",latest:"4.0"))
    }
    func testLatestOnlyWhenDifferentFromInstalled() {
        XCTAssertEqual(ReleaseBadge.resolve(version:"4.0",installed:"3.0",latest:"4.0"),.latest)
        XCTAssertEqual(ReleaseBadge.resolve(version:"3.0",installed:"3.0",latest:"4.0"),.installed)
        XCTAssertNil(ReleaseBadge.resolve(version:"3.0",installed:nil,latest:nil))
    }
}
