import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import ReleaseKitCore

private final class TransportState:@unchecked Sendable {
    static let shared=TransportState()
    private let lock=NSLock()
    private var modes:[String:String]=[:]
    func set(_ id:String,_ mode:String){lock.lock();defer{lock.unlock()};modes[id]=mode}
    func mode(_ id:String)->String{lock.lock();defer{lock.unlock()};return modes[id] ?? "online"}
}
private final class SDKProtocol:URLProtocol,@unchecked Sendable {
    override class func canInit(with request:URLRequest)->Bool {request.url?.host=="example.test" || request.url?.host?.hasSuffix(".example.test")==true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading(){
        let mode=TransportState.shared.mode(request.url?.host=="example.test" ? "" : request.url?.host?.components(separatedBy:".").first ?? "")
        if mode=="offline" {client?.urlProtocol(self,didFailWithError:URLError(.notConnectedToInternet));return}
        if mode=="notFound" {client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:404,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:Data());client?.urlProtocolDidFinishLoading(self);return}
        if mode=="etag",request.value(forHTTPHeaderField:"If-None-Match")=="v1" {client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:304,httpVersion:nil,headerFields:["ETag":"v1"])!,cacheStoragePolicy:.notAllowed);client?.urlProtocolDidFinishLoading(self);return}
        do {
            let fixture=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"changelog",withExtension:"json")!)) as! [String:Any]
            let vote=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"release-vote",withExtension:"json")!)) as! [String:Any]
            var status=200;let payload:Any
            if request.value(forHTTPHeaderField:"X-RK-App-Key") != "rk_pub_0123456789ABCDEFGHIJKLMN" || request.value(forHTTPHeaderField:"X-RK-Anon-Id") != "a2e6885b-9e93-4308-a632-81d8effd08bd" {
                status=401;payload=["error":["code":"invalid_app_key","message":"Invalid headers"]]
            } else if request.url!.path.hasSuffix("/config") {payload=fixture["config"]!}
            else if request.url!.path.hasSuffix("/reports") {let report=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"report-hidden",withExtension:"json")!)) as! [String:Any];payload=report["response"]!}
            else if request.url!.path.hasSuffix("/replies") {guard URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems?.contains(URLQueryItem(name:"sort",value:"new"))==true else{throw URLError(.badURL)};let nested=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"nested-comments",withExtension:"json")!)) as! [String:Any];let page=nested["page"] as! [String:Any];let root=(page["items"] as! [[String:Any]])[0];payload=["items":root["replies"]!,"nextCursor":NSNull()]}
            else if request.url!.path.hasSuffix("/events") {payload=[String:String]()}
            else if request.url!.path.hasSuffix("/guidelines/accept") {payload=["accepted":true]}
            else if request.url!.path.hasSuffix("/comments") {
                let comment=try JSONSerialization.jsonObject(with:Data(contentsOf:Bundle.module.url(forResource:"comments",withExtension:"json")!)) as! [String:Any]
                if request.httpMethod=="POST" {payload=comment["response"]!}
                else if URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems?.contains(URLQueryItem(name:"sort",value:"new")) != true {throw URLError(.badURL)}
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
            let response=HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json","ETag":"v1"])!
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
    func testAcceptsGuidelinesPostsAndReloadsNamedVisibleComments() async throws {
        let api=client();try await api.acceptGuidelines()
        let posted=try await api.addComment(version:"4.0",body:"Thanks for the useful update!")
        XCTAssertEqual(posted.status,"visible");XCTAssertEqual(posted.releaseCommentCount,1);XCTAssertEqual(posted.author.name,"Sunny Otter AB12")
        let page=try await api.comments(version:"4.0");XCTAssertEqual(page.items.first?.id,posted.id)
        let next=try await api.comments(version:"4.0",cursor:page.nextCursor);XCTAssertTrue(next.items.isEmpty)
    }
    func testNetworkFailureUsesDiskButHTTPDenialDoesNot() async throws {
        let id=UUID().uuidString.lowercased(),root=FileManager.default.temporaryDirectory.appendingPathComponent(id);defer{try? FileManager.default.removeItem(at:root)}
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[SDKProtocol.self];config.httpAdditionalHeaders=["X-Test-ID":id]
        let api=APIClient(baseURL:URL(string:"https://\(id).example.test")!,appKey:"rk_pub_0123456789ABCDEFGHIJKLMN",anonID:"a2e6885b-9e93-4308-a632-81d8effd08bd",session:URLSession(configuration:config),cacheDirectory:root)
        _=try await api.releases(force:true);TransportState.shared.set(id,"etag");let revalidated=try await api.releases(force:true);XCTAssertEqual(revalidated.items.first?.version,"4.0");TransportState.shared.set(id,"offline")
        let offline=try await api.releases(force:true);XCTAssertEqual(offline.items.first?.version,"4.0");let saved=await api.isOffline;XCTAssertTrue(saved)
        do{_=try await api.vote(targetType:"release",targetId:"rel1",value:1);XCTFail("Writes must not be queued")}catch is URLError{}
        TransportState.shared.set(id,"notFound")
        do{_=try await api.releases(force:true);XCTFail("Must not show stale hidden/removed content")}catch ReleaseKitNetworkError.http(404){}
        TransportState.shared.set(id,"offline")
        do{_=try await api.releases(force:true);XCTFail("Denied cache must be removed")}catch is URLError{}
    }
    func testOfflineEventsAreBoundedAndFlushedWhenOnline() async throws {
        let id=UUID().uuidString.lowercased(),root=FileManager.default.temporaryDirectory.appendingPathComponent(id);defer{try? FileManager.default.removeItem(at:root)}
        let sessionConfig=URLSessionConfiguration.ephemeral;sessionConfig.protocolClasses=[SDKProtocol.self];sessionConfig.httpAdditionalHeaders=["X-Test-ID":id]
        let key="rk_pub_0123456789ABCDEFGHIJKLMN",anon="a2e6885b-9e93-4308-a632-81d8effd08bd",base=URL(string:"https://\(id).example.test")!
        let api=APIClient(baseURL:base,appKey:key,anonID:anon,session:URLSession(configuration:sessionConfig),cacheDirectory:root)
        TransportState.shared.set(id,"offline")
        for _ in 0..<52 {do{try await api.event(type:"sheet_impression",version:"4.0")}catch{}}
        let disk=ResponseCache(directory:root,scope:"\(base.absoluteString)|\(key)|\(anon)")
        let queued=try XCTUnwrap(disk.read("__events"));XCTAssertEqual((try JSONSerialization.jsonObject(with:queued.data) as! [Any]).count,50)
        TransportState.shared.set(id,"online");_=try await api.config();XCTAssertNil(disk.read("__events"))
    }
    func testLoadsRepliesWithNestedChildren() async throws {
        let page=try await client().replies(commentId:"c1")
        XCTAssertEqual(page.items.first?.id,"c2");XCTAssertEqual(page.items.first?.replies.first?.id,"c3");XCTAssertNil(page.nextCursor)
    }
    func testReportReturnsHiddenStatusAndAuthoritativeCount() async throws {
        let result=try await client().report(commentId:"c1")
        XCTAssertTrue(result.reported);XCTAssertEqual(result.hidden,true);XCTAssertEqual(result.releaseCommentCount,0)
    }
    func testPreservesServerVoteFailure() async throws {
        do {_=try await client().vote(targetType:"release",targetId:"rel1",value:-1);XCTFail("Expected rate limit")}
        catch ReleaseKitNetworkError.server(let code){XCTAssertEqual(code,"rate_limited")}
    }
}
