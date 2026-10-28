import Foundation
import XCTest
@testable import ReleaseKitCore

private final class SDKProtocol:URLProtocol,@unchecked Sendable {
    override class func canInit(with request:URLRequest)->Bool {request.url?.host=="example.test"}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading(){
        do {
            let fixture=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"changelog",withExtension:"json")!)) as! [String:Any]
            let vote=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"release-vote",withExtension:"json")!)) as! [String:Any]
            var status=200;let payload:Any
            if request.value(forHTTPHeaderField:"X-RK-App-Key") != "rk_pub_0123456789ABCDEFGHIJKLMN" || request.value(forHTTPHeaderField:"X-RK-Anon-Id") != "a2e6885b-9e93-4308-a632-81d8effd08bd" {
                status=401;payload=["error":["code":"invalid_app_key","message":"Invalid headers"]]
            } else if request.url!.path.hasSuffix("/config") {payload=fixture["config"]!}
            else if request.url!.path.hasSuffix("/guidelines/accept") {payload=["accepted":true]}
            else if request.url!.path.hasSuffix("/comments") {
                let comment=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"comments",withExtension:"json")!)) as! [String:Any]
                if request.httpMethod=="POST" {payload=comment["response"]!}
                else if request.url!.query?.contains("cursor=next-page")==true {payload=["items":[],"nextCursor":NSNull()]}
                else {payload=["items":[comment["response"]!],"nextCursor":"next-page"]}
            }
            else if request.httpMethod=="POST" {
                var data=request.httpBody ?? Data()
                if let stream=request.httpBodyStream {stream.open();defer{stream.close()};let buffer=UnsafeMutablePointer<UInt8>.allocate(capacity:4096);defer{buffer.deallocate()};while stream.hasBytesAvailable {let count=stream.read(buffer,maxLength:4096);if count<=0{break};data.append(buffer,count:count)}}
                let body=try JSONSerialization.jsonObject(with:data) as! [String:Any]
                if body["targetType"] as? String != "release" || body["targetId"] as? String != "rel1" || request.value(forHTTPHeaderField:"Content-Type") != "application/json" {status=400;payload=["error":["code":"invalid_request","message":"Invalid vote body"]]}
                else if body["value"] as? Int == -1 {status=429;payload=["error":["code":"rate_limited","message":"Try later"]]}
                else {payload=vote["response"]!}
            } else if URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems?.contains(where:{$0.name=="cursor"&&$0.value=="next-page"}) == true {payload=["items":[],"nextCursor":NSNull()]}
            else {payload=fixture["releases"]!}
            let response=HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!
            client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:try JSONSerialization.data(withJSONObject:payload))
            client?.urlProtocolDidFinishLoading(self)
        } catch {client?.urlProtocol(self,didFailWithError:error)}
    }
    override func stopLoading(){}
}
final class APIClientTests:XCTestCase {
    private func client()->APIClient {let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[SDKProtocol.self];return APIClient(baseURL:URL(string:"https://example.test")!,appKey:"rk_pub_0123456789ABCDEFGHIJKLMN",anonID:"a2e6885b-9e93-4308-a632-81d8effd08bd",session:URLSession(configuration:config))}
    func testLoadsConfigAndPaginatesWithAnonymousHeaders() async throws {
        let api=client();let config=try await api.config();XCTAssertTrue(config.features.votes);XCTAssertFalse(config.features.comments)
        let first=try await api.releases();XCTAssertEqual(first.items.first?.version,"4.0");XCTAssertEqual(first.nextCursor,"next-page")
        let next=try await api.releases(cursor:first.nextCursor);XCTAssertTrue(next.items.isEmpty);XCTAssertNil(next.nextCursor)
    }
    func testEncodesVoteAndDecodesServerTotals() async throws {
        let result=try await client().vote(targetType:"release",targetId:"rel1",value:1)
        XCTAssertEqual(result.upCount,1);XCTAssertEqual(result.myVote,1)
    }
    func testAcceptsGuidelinesPostsAndReloadsNamedPendingComments() async throws {
        let api=client();try await api.acceptGuidelines()
        let posted=try await api.addComment(version:"4.0",body:"Thanks for the useful update!")
        XCTAssertEqual(posted.status,"pending");XCTAssertEqual(posted.author.name,"Sunny Otter AB12")
        let page=try await api.comments(version:"4.0");XCTAssertEqual(page.items.first?.id,posted.id)
        let next=try await api.comments(version:"4.0",cursor:page.nextCursor);XCTAssertTrue(next.items.isEmpty)
    }
    func testPreservesServerVoteFailure() async throws {
        do {_=try await client().vote(targetType:"release",targetId:"rel1",value:-1);XCTFail("Expected rate limit")}
        catch ReleaseKitNetworkError.server(let code){XCTAssertEqual(code,"rate_limited")}
    }
}
