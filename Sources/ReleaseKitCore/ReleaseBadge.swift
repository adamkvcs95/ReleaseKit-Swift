package enum ReleaseBadge: Equatable {
    case installed, latest
    package static func resolve(version: String, installed: String?, latest: String?) -> Self? {
        if let installed, VersionNumber(version) == VersionNumber(installed) { return .installed }
        if let latest, VersionNumber(version) == VersionNumber(latest), installed.map({ VersionNumber($0) != VersionNumber(latest) }) ?? true { return .latest }
        return nil
    }
}
