import Foundation

package struct AppConfig: Decodable, Sendable {
    package struct App: Decodable, Sendable { package let id:String; package let slug:String; package let name:String; package let iconUrl:URL?; package let latestVersion:String?; package let changelogUrl:URL; package let ideasUrl:URL? }
    package struct Developer: Decodable, Sendable { package let name:String; package let contactEmail:String; package let contactUrl:URL? }
    package struct Features: Decodable, Sendable { package let comments:Bool; package let votes:Bool; package let commentVotes:Bool?; package let ideas:Bool; package let attestation:String }
    package struct Branding: Decodable, Sendable { package let showPoweredBy:Bool }
    package struct Legal: Decodable, Sendable { package let guidelinesUrl:URL; package let termsUrl:URL; package let privacyUrl:URL }
    package struct Me: Decodable, Sendable { package let displayName:String?; package let guidelinesAccepted:Bool; package let banned:Bool; package let verified:Bool }
    package let app:App; package let developer:Developer; package let features:Features; package let branding:Branding; package let legal:Legal; package let me:Me
}
package struct Release: Decodable, Identifiable, Sendable {
    package let id:String; package let version:String; package let releaseDate:String; package let notes:String; package let notesCountry:String
    package let upCount:Int; package let downCount:Int; package let commentCount:Int; package let myVote:Int; package let url:URL
}
package struct WhatsNewResponse: Decodable, Sendable {
    package let installedVersion:String; package let latestVersion:String?; package let state:String; package let release:Release?
    package var releaseState: ReleaseState? {
        switch state {case "available": .available; case "notes_pending": .notesPending; case "not_live_yet": .notLiveYet; case "unknown_version": .unknownVersion; case "hidden": .hidden; default: nil}
    }
}
package struct ReleasesResponse: Decodable, Sendable { package let items:[Release]; package let nextCursor:String? }
package struct APIErrorEnvelope: Decodable, Sendable { package struct Payload: Decodable, Sendable { package let code:String; package let message:String }; package let error:Payload }
package struct Comment:Decodable,Identifiable,Sendable {
    package struct Author:Decodable,Sendable {package let kind:String;package let tag:String?;package let name:String?;package let verified:Bool?;package let isMe:Bool}
    package let id:String;package let author:Author;package let body:String;package let createdAt:String;package let upCount:Int;package let downCount:Int;package let myVote:Int;package let status:String;package let replies:[Comment];package let replyCount:Int;package let releaseCommentCount:Int?;package let removed:Bool?
    package var isRemoved:Bool {removed==true || status=="hidden" || status=="deleted"}
}
package struct CommentPage:Decodable,Sendable {package let items:[Comment];package let nextCursor:String?}
package struct VoteResult:Decodable,Sendable {package let targetType:String;package let targetId:String;package let upCount:Int;package let downCount:Int;package let myVote:Int}
package struct Accepted:Decodable,Sendable {package let accepted:Bool}
package struct Reported:Decodable,Sendable {package let reported:Bool;package let hidden:Bool?;package let releaseCommentCount:Int?}
package struct Blocked:Decodable,Sendable {package let blocked:Bool}

package struct EventAccepted:Decodable,Sendable {}

package let hiddenCommentNotice="This comment has been hidden because it violated the community guidelines."
