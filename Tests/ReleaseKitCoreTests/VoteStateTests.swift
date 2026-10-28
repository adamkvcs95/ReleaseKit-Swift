import XCTest
@testable import ReleaseKitCore
final class VoteStateTests:XCTestCase {
    func testToggleSwitchAndUndo(){
        var state=VoteState(up:12,down:3,selected:0)
        XCTAssertEqual(state.toggle(1),1);XCTAssertEqual(state.upCount,13)
        XCTAssertEqual(state.toggle(-1),-1);XCTAssertEqual(state.upCount,12);XCTAssertEqual(state.downCount,4)
        XCTAssertEqual(state.toggle(-1),0);XCTAssertEqual(state.downCount,3)
    }
    func testFailureCanRestorePreviousState(){
        var state=VoteState(up:12,down:3,selected:1);let previous=state
        _=state.toggle(-1);state=previous
        XCTAssertEqual(state,VoteState(up:12,down:3,selected:1))
    }
    func testInconsistentServerCountsCannotBecomeNegative(){
        var state=VoteState(up:0,down:0,selected:1)
        _=state.toggle(1);XCTAssertEqual(state.upCount,0);XCTAssertEqual(state.selected,0)
    }
}
