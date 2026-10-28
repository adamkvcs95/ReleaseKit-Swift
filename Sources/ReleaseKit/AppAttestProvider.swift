#if canImport(DeviceCheck) && canImport(UIKit)
import Foundation
import DeviceCheck
import CryptoKit
import Security
import ReleaseKitCore

/// Keys are isolated by endpoint, app key and anonymous installation; no private key leaves Secure Enclave.
actor AppAttestProvider:RequestAuthorizer {
    private let baseURL:URL
    private let appKey:String
    private let identity:String
    private let account:String
    private var keyId:String?
    private var unavailableUntil:Date?
    init(baseURL:URL,appKey:String,identity:String){self.baseURL=baseURL;self.appKey=appKey;self.identity=identity;account=SHA256.hash(data:Data("\(baseURL.absoluteString)|\(appKey)|\(identity)".utf8)).map{String(format:"%02x",$0)}.joined()}
    private var keychain:[String:Any]{[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"it.releasek.attest",kSecAttrAccount as String:account,kSecAttrSynchronizable as String:false]}
    private struct Stored:Codable {let id:String;let registered:Bool}
    private func storedKey()->Stored? {var query=keychain;query[kSecReturnData as String]=true;query[kSecMatchLimit as String]=kSecMatchLimitOne;var result:CFTypeRef?;guard SecItemCopyMatching(query as CFDictionary,&result)==errSecSuccess,let data=result as? Data else{return nil};return try? JSONDecoder().decode(Stored.self,from:data)}
    private func saveKey(_ id:String,registered:Bool=true)throws {SecItemDelete(keychain as CFDictionary);var query=keychain;query[kSecValueData as String]=try JSONEncoder().encode(Stored(id:id,registered:registered));query[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;guard SecItemAdd(query as CFDictionary,nil)==errSecSuccess else{throw ReleaseKitNetworkError.invalidResponse}}
    private func resetKey(){keyId=nil;unavailableUntil=nil;SecItemDelete(keychain as CFDictionary)}
    func invalidate(){if storedKey()?.registered==false {keyId=nil;return};resetKey()}
    private struct Challenge:Decodable {let challenge:String;let expiresAt:String}
    private struct Registered:Decodable {let registered:Bool}
    private func post<T:Decodable & Sendable>(_ path:String,body:Data=Data("{}".utf8)) async throws->T {
        var request=URLRequest(url:baseURL.appendingPathComponent(path),timeoutInterval:10);request.httpMethod="POST";request.httpBody=body
        for (name,value) in ["Content-Type":"application/json","X-RK-App-Key":appKey,"X-RK-Anon-Id":identity,"X-RK-SDK":"ios/1.0.0-rc.7"] {request.setValue(value,forHTTPHeaderField:name)}
        let (data,response)=try await URLSession.shared.data(for:request);guard let response=response as? HTTPURLResponse else{throw ReleaseKitNetworkError.invalidResponse}
        guard response.statusCode==200 else {if let error=try? JSONDecoder().decode(APIErrorEnvelope.self,from:data){throw ReleaseKitNetworkError.server(error.error.code)};throw ReleaseKitNetworkError.http(response.statusCode)}
        return try JSONDecoder().decode(T.self,from:data)
    }
    private func challenge() async throws->Challenge {try await post("api/v1/sdk/attest/challenge")}
    private func bytes(_ challenge:String)throws->Data {let value=challenge.replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/");guard let data=Data(base64Encoded:value+String(repeating:"=",count:(4-value.count%4)%4)),data.count==32 else{throw ReleaseKitNetworkError.invalidResponse};return data}
    private func key() async throws->String {
        if let keyId{return keyId};let stored=storedKey();if let stored,stored.registered {keyId=stored.id;return stored.id}
        let challenge=try await challenge()
        let id:String
        if let stored {id=stored.id}else{id=try await withCheckedThrowingContinuation{continuation in DCAppAttestService.shared.generateKey{key,error in if let key{continuation.resume(returning:key)}else{continuation.resume(throwing:error ?? ReleaseKitNetworkError.invalidResponse)}}}
        try saveKey(id,registered:false)}
        let hash=Data(SHA256.hash(data:try bytes(challenge.challenge)))
        let attestation:Data=try await withCheckedThrowingContinuation{continuation in DCAppAttestService.shared.attestKey(id,clientDataHash:hash){data,error in if let data{continuation.resume(returning:data)}else{continuation.resume(throwing:error ?? ReleaseKitNetworkError.invalidResponse)}}}
        let payload=try JSONSerialization.data(withJSONObject:["keyId":id,"attestation":attestation.base64EncodedString(),"challenge":challenge.challenge])
        let result:Registered
        do{result=try await post("api/v1/sdk/attest/register",body:payload)}catch ReleaseKitNetworkError.server(let code) where code=="attestation_invalid" {resetKey();throw ReleaseKitNetworkError.server(code)}
        guard result.registered else{throw ReleaseKitNetworkError.invalidResponse}
        try saveKey(id);keyId=id;return id
    }
    func headers(for request:URLRequest) async throws->[String:String] {
        guard DCAppAttestService.shared.isSupported else{return [:]}
        if let unavailableUntil,unavailableUntil>Date(){return [:]}
        do {
            let key=try await key(),challenge=try await challenge(),timestamp=String(Int(Date().timeIntervalSince1970))
            guard let url=request.url,let parts=URLComponents(url:url,resolvingAgainstBaseURL:false) else{throw ReleaseKitNetworkError.invalidURL}
            let bodyHash=SHA256.hash(data:request.httpBody ?? Data()).map{String(format:"%02x",$0)}.joined()
            let path=parts.percentEncodedPath+(parts.percentEncodedQuery.map{"?"+$0} ?? "")
            let payload=AttestationPayload.canonical(method:request.httpMethod ?? "POST",path:path,bodySHA256:bodyHash,timestamp:timestamp,challenge:challenge.challenge)
            let hash=Data(SHA256.hash(data:Data(payload.utf8)))
            let assertion:Data=try await withCheckedThrowingContinuation{continuation in DCAppAttestService.shared.generateAssertion(key,clientDataHash:hash){data,error in if let data{continuation.resume(returning:data)}else{continuation.resume(throwing:error ?? ReleaseKitNetworkError.invalidResponse)}}}
            return ["X-RK-Assertion":assertion.base64EncodedString(),"X-RK-Assertion-Key":key,"X-RK-Timestamp":timestamp,"X-RK-Challenge":challenge.challenge]
        }catch ReleaseKitNetworkError.server(let code) where code=="attestation_unavailable" {unavailableUntil=Date().addingTimeInterval(3600);return [:]}
        catch let error as DCError where error.code == .invalidKey {resetKey();throw ReleaseKitNetworkError.server("attestation_invalid")}
        catch is DCError {return [:]}
        catch {throw error}
    }
}
#endif
