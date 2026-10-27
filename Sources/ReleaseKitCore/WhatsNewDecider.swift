import Foundation

package struct LocalState: Codable, Equatable, Sendable {
    package var firstSeenVersion: String?
    package var lastKnownVersion: String?
    package var handledVersions: Set<String> = []
    package var pendingSince: [String: Date] = [:]
    package var guidelinesAccepted = false
    package var blockedAuthorTags: Set<String> = []
    package init() {}
}
package enum ReleaseState: Sendable { case available, notesPending, notLiveYet, unknownVersion, hidden }
package enum Decision: Equatable, Sendable { case fetch, show, skip }
package enum WhatsNewDecider {
    /// Call before networking; persist state even when the decision is to skip.
    package static func prepare(version: String, state: inout LocalState, treatFirstLaunchAsUpdate: Bool = false, debugAlwaysShow: Bool = false) -> Decision {
        let version = VersionNumber(version)
        let key = version.normalized
        if debugAlwaysShow { return .fetch }
        if state.firstSeenVersion == nil {
            state.firstSeenVersion = key
            state.lastKnownVersion = key
            if !treatFirstLaunchAsUpdate { state.handledVersions.insert(key); return .skip }
        }
        if state.handledVersions.contains(key) { return .skip }
        if let last = state.lastKnownVersion, version < VersionNumber(last) {
            state.handledVersions.insert(key)
            state.lastKnownVersion = key
            return .skip
        }
        state.lastKnownVersion = key
        return .fetch
    }
    /// Mark shown only once presentation has actually happened, using `markPresented`.
    package static func resolve(version: String, response: ReleaseState, state: inout LocalState, now: Date) -> Decision {
        let key = VersionNumber(version).normalized
        switch response {
        case .available: return .show
        case .hidden: state.handledVersions.insert(key); return .skip
        case .notLiveYet: return .skip
        case .notesPending, .unknownVersion:
            let since = state.pendingSince[key] ?? now
            state.pendingSince[key] = since
            let days: TimeInterval = response == .notesPending ? 3 : 7
            if now.timeIntervalSince(since) > days * 86400 { state.handledVersions.insert(key) }
            return .skip
        }
    }
    package static func markPresented(version: String, state: inout LocalState) {
        let key = VersionNumber(version).normalized
        state.handledVersions.insert(key)
        state.pendingSince.removeValue(forKey: key)
    }
}
