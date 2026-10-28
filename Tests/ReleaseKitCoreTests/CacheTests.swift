import Foundation
import XCTest
@testable import ReleaseKitCore

final class CacheTests:XCTestCase {
    private func root()->URL {FileManager.default.temporaryDirectory.appendingPathComponent("rk-cache-test-"+UUID().uuidString)}
    func testPersistsAcrossInstancesAndIsolatesAccounts() throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)}
        let a=ResponseCache(directory:directory,scope:"app1:install1"),b=ResponseCache(directory:directory,scope:"app1:install2")
        a.write("releases",data:Data("saved".utf8),etag:"v1")
        XCTAssertEqual(ResponseCache(directory:directory,scope:"app1:install1").read("releases")?.data,Data("saved".utf8));XCTAssertNil(b.read("releases"))
        a.write("expired",data:Data(),etag:nil,now:Date().addingTimeInterval(-8*86400));XCTAssertNil(a.read("expired"))
    }
    func testVoteUpdatesCachedSelectionsAndBlockClearsPrivateContent() throws {
        let directory=root();defer{try? FileManager.default.removeItem(at:directory)};let cache=ResponseCache(directory:directory,scope:"app")
        cache.write("/api/v1/sdk/config|en",data:Data("{}".utf8),etag:nil)
        cache.write("releases",data:Data(#"{"items":[{"id":"r1","upCount":0,"downCount":0,"myVote":0}]}"#.utf8),etag:"old")
        cache.updateVote(Data(#"{"targetId":"r1","upCount":1,"downCount":0,"myVote":1}"#.utf8))
        let entry=try XCTUnwrap(cache.read("releases"));XCTAssertNil(entry.etag);let json=try JSONSerialization.jsonObject(with:entry.data) as! [String:Any];XCTAssertEqual((json["items"] as! [[String:Any]])[0]["myVote"] as? Int,1)
        cache.invalidateMutable();XCTAssertNil(cache.read("releases"));XCTAssertNotNil(cache.read("/api/v1/sdk/config|en"))
    }
}
