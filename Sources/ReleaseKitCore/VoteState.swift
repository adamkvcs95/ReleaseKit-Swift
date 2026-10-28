/// Optimistic vote state. The API stores an absolute -1/0/1 value, so retrying is idempotent.
package struct VoteState: Equatable, Sendable {
    package var upCount: Int
    package var downCount: Int
    package var selected: Int
    package init(up: Int, down: Int, selected: Int) {
        upCount = max(0, up); downCount = max(0, down)
        self.selected = [-1, 0, 1].contains(selected) ? selected : 0
    }
    @discardableResult package mutating func toggle(_ direction: Int) -> Int {
        precondition(direction == 1 || direction == -1)
        let next = selected == direction ? 0 : direction
        if selected == 1 { upCount = max(0, upCount - 1) }
        if selected == -1 { downCount = max(0, downCount - 1) }
        if next == 1 { upCount += 1 }
        if next == -1 { downCount += 1 }
        selected = next
        return next
    }
}
