import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

package enum ReleaseKitNetworkError: Error, Sendable {case invalidURL,invalidResponse,server(String),http(Int)}
package protocol RequestAuthorizer:Sendable {
    func headers(for request:URLRequest) async throws->[String:String]
    func invalidate() async
}
package actor APIClient {
    package private(set) var isOffline=false
    private var authorizer:(any RequestAuthorizer)?
    private let cache:ResponseCache?
    private var writing=false
    private var waiters:[CheckedContinuation<Void,Never>]=[]
    private func lockWrite() async {if writing {await withCheckedContinuation{waiters.append($0)}}else{writing=true}}
    private func unlockWrite(){if waiters.isEmpty{writing=false}else{waiters.removeFirst().resume()}}
    package func clearCache(){cache?.clear()}

    private let baseURL:URL
    private let appKey:String
    private let anonID:String
    private let session:URLSession
    package init(baseURL:URL,appKey:String,anonID:String,session:URLSession = .shared,cacheDirectory:URL?=nil,authorizer:(any RequestAuthorizer)?=nil) {
        self.baseURL=baseURL;self.appKey=appKey;self.anonID=anonID;self.session=session;self.authorizer=authorizer
        self.cache=cacheDirectory.map{ResponseCache(directory:$0,scope:"\(baseURL.absoluteString)|\(appKey)|\(anonID)")}
    }
    private func request<T:Decodable & Sendable>(_ path:String,query:[URLQueryItem]=[],body:Data?=nil,force:Bool=false) async throws -> T {
        if body != nil {await lockWrite()}
        defer{if body != nil {unlockWrite()}}
        guard var components=URLComponents(url:baseURL.appendingPathComponent(path),resolvingAgainstBaseURL:false) else {throw ReleaseKitNetworkError.invalidURL}
        if !query.isEmpty {components.queryItems=query}
        guard let url=components.url else {throw ReleaseKitNetworkError.invalidURL}
        var request=URLRequest(url:url,timeoutInterval:10)
        if let body {request.httpMethod="POST";request.httpBody=body;request.setValue("application/json",forHTTPHeaderField:"Content-Type")}
        request.setValue(appKey,forHTTPHeaderField:"X-RK-App-Key");request.setValue(anonID,forHTTPHeaderField:"X-RK-Anon-Id");request.setValue("ios/1.0.0-rc.9",forHTTPHeaderField:"X-RK-SDK")
        request.setValue(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "",forHTTPHeaderField:"X-RK-App-Version")
        request.setValue(Locale.preferredLanguages.prefix(3).joined(separator:", "),forHTTPHeaderField:"Accept-Language")
        let region:String?
        if #available(iOS 16, macOS 13, *) { region=Locale.current.region?.identifier }
        else { region=Locale.current.regionCode }
        if let region {request.setValue(region,forHTTPHeaderField:"X-RK-Region")}
        let cacheKey=url.absoluteString+"|"+(request.value(forHTTPHeaderField:"Accept-Language") ?? "")+"|"+(region ?? "")
        let cached=body == nil ? cache?.read(cacheKey):nil
        let ttl:TimeInterval=path.hasSuffix("/config") ? 86400:path=="api/v1/sdk/releases" ? 300:0
        if !force,let cached,Date().timeIntervalSince(cached.savedAt)<ttl {return try JSONDecoder().decode(T.self,from:cached.data)}
        if let etag=cached?.etag {request.setValue(etag,forHTTPHeaderField:"If-None-Match")}
        var didReattest=false
        for attempt in 0..<2 {
            do {
                if body != nil,let authorizer {
                    for (name,value) in try await authorizer.headers(for:request){request.setValue(value,forHTTPHeaderField:name)}
                }
                let (data,response)=try await session.data(for:request)
                guard let http=response as? HTTPURLResponse else {throw ReleaseKitNetworkError.invalidResponse}
                if http.statusCode==304,let cached {
                    cache?.write(cacheKey,data:cached.data,etag:cached.etag);isOffline=false
                    return try JSONDecoder().decode(T.self,from:cached.data)
                }
                guard (200..<300).contains(http.statusCode) else {
                    if body==nil && [401,403,404].contains(http.statusCode){cache?.remove(cacheKey)}
                    if let envelope=try? JSONDecoder().decode(APIErrorEnvelope.self,from:data){
                        if body != nil,http.statusCode==401,["attestation_invalid","attestation_required"].contains(envelope.error.code),let authorizer,!didReattest {didReattest=true;await authorizer.invalidate();continue}
                        throw ReleaseKitNetworkError.server(envelope.error.code)
                    }
                    throw ReleaseKitNetworkError.http(http.statusCode)
                }
                let result=try JSONDecoder().decode(T.self,from:data)
                isOffline=false
                if body==nil {cache?.write(cacheKey,data:data,etag:http.value(forHTTPHeaderField:"ETag"))}
                else if path.hasSuffix("/events") {}
                else if path.hasSuffix("/votes") {cache?.updateVote(data)}
                else if path.hasSuffix("/guidelines/accept") {cache?.invalidateConfig()}
                else if path.hasSuffix("/comments"),let version=path.split(separator:"/").dropLast().last {cache?.updateCommentCount(data,version:String(version))}
                else {cache?.invalidateMutable()}
                return result
            } catch ReleaseKitNetworkError.server(let code) where body != nil && code=="attestation_invalid" && !didReattest && authorizer != nil {
                didReattest=true;await authorizer?.invalidate();continue
            } catch let error as URLError {
                if error.code == .cancelled {throw error}
                if body==nil,let cached {isOffline=true;return try JSONDecoder().decode(T.self,from:cached.data)}
                if body != nil || attempt==1 {throw error}
            } catch {throw error}
        }
        throw ReleaseKitNetworkError.invalidResponse
    }
    package func config(force:Bool=false) async throws -> AppConfig {let config:AppConfig=try await request("api/v1/sdk/config",force:force);await flushEvents();return config}
    package func whatsNew(version:String) async throws -> WhatsNewResponse {try await request("api/v1/sdk/whats-new",query:[URLQueryItem(name:"version",value:version)])}
    package func releases(cursor:String?=nil,force:Bool=false) async throws -> ReleasesResponse {try await request("api/v1/sdk/releases",query:cursor.map{[URLQueryItem(name:"cursor",value:$0)]} ?? [],force:force)}
    private func post<Payload:Encodable & Sendable,Response:Decodable & Sendable>(_ path:String,_ payload:Payload) async throws -> Response {try await request(path,body:JSONEncoder().encode(payload))}
    private struct Vote:Encodable,Sendable {let targetType:String;let targetId:String;let value:Int}
    private struct Content:Encodable,Sendable {let body:String;let parentId:String?;let locale:String?}
    private struct Report:Encodable,Sendable {let targetType:String="comment";let targetId:String;let reason:String="other"}
    private struct Block:Encodable,Sendable {let commentId:String}
    private struct Empty:Encodable,Sendable {}
    private struct Event:Codable,Sendable {let type:String;let version:String?;let releaseId:String?}
    private struct Events:Codable,Sendable {let events:[Event]}
    package func vote(targetType:String,targetId:String,value:Int) async throws -> VoteResult {try await post("api/v1/sdk/votes",Vote(targetType:targetType,targetId:targetId,value:value))}
    package func comments(version:String,cursor:String?=nil) async throws -> CommentPage {try await request("api/v1/sdk/releases/\(version)/comments",query:cursor.map{[URLQueryItem(name:"cursor",value:$0)]} ?? [])}
    package func replies(commentId:String,cursor:String?=nil) async throws -> CommentPage {try await request("api/v1/sdk/comments/\(commentId)/replies",query:cursor.map{[URLQueryItem(name:"cursor",value:$0)]} ?? [])}
    package func acceptGuidelines() async throws {let _:Accepted=try await post("api/v1/sdk/guidelines/accept",Empty())}
    package func addComment(version:String,body:String,parentId:String?=nil) async throws -> Comment {try await post("api/v1/sdk/releases/\(version)/comments",Content(body:body,parentId:parentId,locale:Locale.current.identifier))}
    package func report(commentId:String) async throws -> Reported {try await post("api/v1/sdk/reports",Report(targetId:commentId))}
    package func block(commentId:String) async throws {let _:Blocked=try await post("api/v1/sdk/blocks",Block(commentId:commentId))}
    private func queuedEvents()->[Event]{guard let data=cache?.read("__events")?.data else{return []};return (try? JSONDecoder().decode([Event].self,from:data)) ?? []}
    private func flushEvents() async {
        let queued=queuedEvents();guard !queued.isEmpty else{return}
        do{let _:EventAccepted=try await post("api/v1/sdk/events",Events(events:queued));cache?.remove("__events")}catch{}
    }
    package func event(type:String,version:String?=nil,releaseId:String?=nil) async throws {
        let item=Event(type:type,version:version,releaseId:releaseId)
        do{let _:EventAccepted=try await post("api/v1/sdk/events",Events(events:[item]))}
        catch let error as URLError {
            var queued=queuedEvents();queued.append(item);queued=Array(queued.suffix(50))
            if let data=try? JSONEncoder().encode(queued){cache?.write("__events",data:data,etag:nil)}
            throw error
        }
    }
}
