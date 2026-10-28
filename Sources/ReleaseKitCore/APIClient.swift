import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

package enum ReleaseKitNetworkError: Error, Sendable {case invalidURL,invalidResponse,server(String),http(Int)}
package actor APIClient {
    private let baseURL:URL
    private let appKey:String
    private let anonID:String
    private let session:URLSession
    package init(baseURL:URL,appKey:String,anonID:String,session:URLSession = .shared) {self.baseURL=baseURL;self.appKey=appKey;self.anonID=anonID;self.session=session}
    private func request<T:Decodable & Sendable>(_ path:String,query:[URLQueryItem]=[],body:Data?=nil) async throws -> T {
        guard var components=URLComponents(url:baseURL.appendingPathComponent(path),resolvingAgainstBaseURL:false) else {throw ReleaseKitNetworkError.invalidURL}
        if !query.isEmpty {components.queryItems=query}
        guard let url=components.url else {throw ReleaseKitNetworkError.invalidURL}
        var request=URLRequest(url:url,timeoutInterval:10)
        if let body {request.httpMethod="POST";request.httpBody=body;request.setValue("application/json",forHTTPHeaderField:"Content-Type")}
        request.setValue(appKey,forHTTPHeaderField:"X-RK-App-Key");request.setValue(anonID,forHTTPHeaderField:"X-RK-Anon-Id");request.setValue("ios/0.1.0-dev",forHTTPHeaderField:"X-RK-SDK")
        request.setValue(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "",forHTTPHeaderField:"X-RK-App-Version")
        request.setValue(Locale.preferredLanguages.prefix(3).joined(separator:", "),forHTTPHeaderField:"Accept-Language")
        let region:String?
        if #available(iOS 16, macOS 13, *) { region=Locale.current.region?.identifier }
        else { region=Locale.current.regionCode }
        if let region {request.setValue(region,forHTTPHeaderField:"X-RK-Region")}
        var last:Error = ReleaseKitNetworkError.invalidResponse
        for attempt in 0..<(body == nil ? 2 : 1) {
            do {
                let (data,response)=try await session.data(for:request)
                guard let http=response as? HTTPURLResponse else {throw ReleaseKitNetworkError.invalidResponse}
                guard (200..<300).contains(http.statusCode) else {
                    if let envelope=try? JSONDecoder().decode(APIErrorEnvelope.self,from:data){throw ReleaseKitNetworkError.server(envelope.error.code)}
                    throw ReleaseKitNetworkError.http(http.statusCode)
                }
                return try JSONDecoder().decode(T.self,from:data)
            } catch let error as ReleaseKitNetworkError {throw error}
            catch {last=error;if body != nil || attempt==1 {throw error}}
        }
        throw last
    }
    package func config() async throws -> AppConfig {try await request("api/v1/sdk/config")}
    package func whatsNew(version:String) async throws -> WhatsNewResponse {try await request("api/v1/sdk/whats-new",query:[URLQueryItem(name:"version",value:version)])}
    package func releases(cursor:String?=nil) async throws -> ReleasesResponse {try await request("api/v1/sdk/releases",query:cursor.map{[URLQueryItem(name:"cursor",value:$0)]} ?? [])}
    private func post<Payload:Encodable & Sendable,Response:Decodable & Sendable>(_ path:String,_ payload:Payload) async throws -> Response {try await request(path,body:JSONEncoder().encode(payload))}
    private struct Vote:Encodable,Sendable {let targetType:String;let targetId:String;let value:Int}
    private struct Content:Encodable,Sendable {let body:String;let parentId:String?;let locale:String?}
    private struct Report:Encodable,Sendable {let targetType:String="comment";let targetId:String;let reason:String}
    private struct Block:Encodable,Sendable {let commentId:String}
    private struct Empty:Encodable,Sendable {}
    private struct Event:Encodable,Sendable {let type:String;let version:String?;let releaseId:String?}
    private struct Events:Encodable,Sendable {let events:[Event]}
    package func vote(targetType:String,targetId:String,value:Int) async throws -> VoteResult {try await post("api/v1/sdk/votes",Vote(targetType:targetType,targetId:targetId,value:value))}
    package func comments(version:String,cursor:String?=nil) async throws -> CommentPage {try await request("api/v1/sdk/releases/\(version)/comments",query:cursor.map{[URLQueryItem(name:"cursor",value:$0)]} ?? [])}
    package func acceptGuidelines() async throws {let _:Accepted=try await post("api/v1/sdk/guidelines/accept",Empty())}
    package func addComment(version:String,body:String,parentId:String?=nil) async throws -> Comment {try await post("api/v1/sdk/releases/\(version)/comments",Content(body:body,parentId:parentId,locale:Locale.current.identifier))}
    package func report(commentId:String,reason:String) async throws {let _:Reported=try await post("api/v1/sdk/reports",Report(targetId:commentId,reason:reason))}
    package func block(commentId:String) async throws {let _:Blocked=try await post("api/v1/sdk/blocks",Block(commentId:commentId))}
    package func event(type:String,version:String?=nil,releaseId:String?=nil) async throws {let _:EventAccepted=try await post("api/v1/sdk/events",Events(events:[Event(type:type,version:version,releaseId:releaseId)]))}
}
