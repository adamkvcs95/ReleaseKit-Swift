import Foundation
import XCTest
@testable import ReleaseKitCore

final class ContractTests:XCTestCase {
    func testReportedCommentIsRedactedAndCountIsReturned() throws {
        struct Fixture:Decodable {let response:Reported;let page:CommentPage}
        let fixture=try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:Bundle.module.url(forResource:"report-hidden",withExtension:"json")!))
        XCTAssertTrue(fixture.response.reported);XCTAssertEqual(fixture.response.hidden,true);XCTAssertEqual(fixture.response.releaseCommentCount,0)
        let comment=try XCTUnwrap(fixture.page.items.first);XCTAssertTrue(comment.isRemoved);XCTAssertEqual(comment.body,hiddenCommentNotice)
    }
    func testSharedAttestationCanonicalRequestAndCommentVote() throws {
        struct Fixture:Decodable {
            struct Request:Decodable {let method:String;let path:String;let bodySHA256:String;let timestamp:String;let challenge:String}
            let request:Request;let canonicalPayload:String;let configFeatures:AppConfig.Features
        }
        let fixture=try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:Bundle.module.url(forResource:"attestation",withExtension:"json")!))
        let r=fixture.request;XCTAssertEqual(AttestationPayload.canonical(method:r.method,path:r.path,bodySHA256:r.bodySHA256,timestamp:r.timestamp,challenge:r.challenge),fixture.canonicalPayload)
        XCTAssertEqual(fixture.configFeatures.commentVotes,true);XCTAssertEqual(fixture.configFeatures.attestation,"optional")
        struct VoteFixture:Decodable {let response:VoteResult}
        let vote=try JSONDecoder().decode(VoteFixture.self,from:Data(contentsOf:Bundle.module.url(forResource:"comment-vote",withExtension:"json")!)).response
        XCTAssertEqual(vote.targetType,"comment");XCTAssertEqual(vote.myVote,1)
    }
    func testDecodesNamedVisibleComment() throws {
        struct Fixture:Decodable {let response:Comment}
        let data=try Data(contentsOf:Bundle.module.url(forResource:"comments",withExtension:"json")!)
        let comment=try JSONDecoder().decode(Fixture.self,from:data).response
        XCTAssertEqual(comment.author.name,"Sunny Otter AB12");XCTAssertTrue(comment.author.isMe);XCTAssertEqual(comment.status,"visible")
    }
    func testDecodesSharedVoteContract() throws {
        struct Fixture:Decodable {let response:VoteResult}
        let data=try Data(contentsOf:Bundle.module.url(forResource:"release-vote",withExtension:"json")!)
        let result=try JSONDecoder().decode(Fixture.self,from:data).response
        XCTAssertEqual(result.targetType,"release");XCTAssertEqual(result.myVote,1)
        XCTAssertEqual(result.upCount,1);XCTAssertEqual(result.downCount,0)
    }
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
