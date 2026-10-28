import Foundation

/// Private, bounded disk cache. Every envelope verifies its complete identity/locale scope.
package struct ResponseCache:Sendable {
    package struct Entry:Codable,Sendable {let scope:String;let key:String;let data:Data;let etag:String?;let savedAt:Date}
    private let directory:URL
    private let scope:String
    package init(directory:URL,scope:String){self.directory=directory.appendingPathComponent(Self.id(scope));self.scope=scope}
    private static func id(_ text:String)->String {var value:UInt64=14695981039346656037;for byte in text.utf8 {value=(value ^ UInt64(byte)) &* 1099511628211};return String(value,radix:16)}
    private func url(_ key:String)->URL{directory.appendingPathComponent(Self.id(key)+".json")}
    package func read(_ key:String)->Entry? {
        guard let bytes=try? Data(contentsOf:url(key)),bytes.count<=2_000_000,let entry=try? JSONDecoder().decode(Entry.self,from:bytes),entry.scope==scope,entry.key==key,Date().timeIntervalSince(entry.savedAt)<7*86400 else{return nil};return entry
    }
    package func write(_ key:String,data:Data,etag:String?,now:Date=Date()) {
        guard data.count<=1_000_000 else{return}
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            // Bounding by count avoids file timestamp APIs and limits cached pagination/history.
            let files=(try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? []
            if files.count>=100 && !FileManager.default.fileExists(atPath:url(key).path) {clear();try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)}
            let entry=Entry(scope:scope,key:key,data:data,etag:etag,savedAt:now)
            #if os(iOS)
            try JSONEncoder().encode(entry).write(to:url(key),options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
            #else
            try JSONEncoder().encode(entry).write(to:url(key),options:.atomic)
            #endif
        }catch{}
    }
    package func invalidateMutable(keepConfig:Bool=true){
        for file in (try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? [] {
            guard let bytes=try? Data(contentsOf:file),let entry=try? JSONDecoder().decode(Entry.self,from:bytes) else{continue}
            if entry.key=="__events"{continue}
            if !keepConfig || !entry.key.contains("/api/v1/sdk/config|"){try? FileManager.default.removeItem(at:file)}
        }
    }
    package func updateVote(_ payload:Data){
        guard let vote=(try? JSONSerialization.jsonObject(with:payload)) as? [String:Any],let id=vote["targetId"] as? String else{return}
        func patch(_ value:Any)->Any {
            if let list=value as? [Any]{return list.map(patch)}
            if var dict=value as? [String:Any]{for (key,value) in dict{dict[key]=patch(value)};if dict["id"] as? String==id {for field in ["upCount","downCount","myVote"]{dict[field]=vote[field]}};return dict}
            return value
        }
        for file in (try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? [] {
            guard let bytes=try? Data(contentsOf:file),let entry=try? JSONDecoder().decode(Entry.self,from:bytes),entry.scope==scope,let json=try? JSONSerialization.jsonObject(with:entry.data),let updated=try? JSONSerialization.data(withJSONObject:patch(json)) else{continue}
            // Mutation invalidates ETag, preserving original freshness rather than extending TTL.
            write(entry.key,data:updated,etag:nil,now:entry.savedAt)
        }
    }
    package func updateCommentCount(_ payload:Data,version:String){
        guard let response=(try? JSONSerialization.jsonObject(with:payload)) as? [String:Any],let count=response["releaseCommentCount"] as? Int else{return}
        func patch(_ value:Any)->Any {if let array=value as? [Any]{return array.map(patch)};if var dict=value as? [String:Any]{for (key,value) in dict {dict[key]=patch(value)};if dict["version"] as? String==version {dict["commentCount"]=count};return dict};return value}
        for file in (try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? [] {
            guard let bytes=try? Data(contentsOf:file),let entry=try? JSONDecoder().decode(Entry.self,from:bytes),entry.scope==scope else{continue}
            if entry.key.contains("/comments") {try? FileManager.default.removeItem(at:file);continue}
            guard let json=try? JSONSerialization.jsonObject(with:entry.data),let updated=try? JSONSerialization.data(withJSONObject:patch(json)) else{continue}
            write(entry.key,data:updated,etag:nil,now:entry.savedAt)
        }
    }
    package func invalidateConfig(){
        for file in (try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? [] {
            if let bytes=try? Data(contentsOf:file),let entry=try? JSONDecoder().decode(Entry.self,from:bytes),entry.key.contains("/api/v1/sdk/config|"){try? FileManager.default.removeItem(at:file)}
        }
    }
    package func remove(_ key:String){try? FileManager.default.removeItem(at:url(key))}
    package func clear(){try? FileManager.default.removeItem(at:directory)}
}
