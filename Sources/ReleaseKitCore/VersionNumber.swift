import Foundation

package struct VersionNumber: Comparable, Hashable, Sendable {
    package let components: [Int]
    package init(_ raw: String) {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false).prefix(4).map { part in
            Int(String(part.prefix(while: { $0.isASCII && $0.isNumber }))) ?? 0
        }
        components = parts + Array(repeating: 0, count: max(0, 4 - parts.count))
    }
    package var normalized: String {
        var result = components
        while result.count > 1 && result.last == 0 { result.removeLast() }
        return result.map(String.init).joined(separator: ".")
    }
    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}
