import Foundation

package enum AppStoreReview {
    package static func url(appStoreId:String?) -> URL? {
        guard let appStoreId, (1...20).contains(appStoreId.count), appStoreId.utf8.allSatisfy({(0x30...0x39).contains($0)}) else {return nil}
        var components=URLComponents()
        components.scheme="https"
        components.host="apps.apple.com"
        components.path="/app/id\(appStoreId)"
        components.queryItems=[URLQueryItem(name:"action",value:"write-review")]
        return components.url
    }
}
