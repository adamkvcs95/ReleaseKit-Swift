import Foundation
import XCTest
@testable import ReleaseKitCore

final class ContractTests:XCTestCase {
    func testDecodesWhatsNewContract() throws {
        let data=Data(#"{"installedVersion":"4.0","latestVersion":"4.0","state":"available","release":{"id":"r1","version":"4.0","releaseDate":"2026-10-20T07:00:00Z","notes":"Hello","notesCountry":"hu","upCount":12,"downCount":1,"commentCount":3,"url":"https://releasek.it/my-app/4.0","myVote":0}}"#.utf8)
        let response=try JSONDecoder().decode(WhatsNewResponse.self,from:data)
        XCTAssertEqual(response.release?.notesCountry,"hu")
        XCTAssertEqual(response.release?.upCount,12)
        XCTAssertEqual(response.releaseState,.available)
    }
    func testDecodesEmptyReleasePage() throws {
        let data=Data(#"{"items":[],"nextCursor":null}"#.utf8)
        let response=try JSONDecoder().decode(ReleasesResponse.self,from:data)
        XCTAssertTrue(response.items.isEmpty)
        XCTAssertNil(response.nextCursor)
    }
}
