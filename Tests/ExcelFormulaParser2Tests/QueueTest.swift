import XCTest
@testable import ExcelFormulaParser2

final class QueueTest: XCTestCase {
    func testEmpty() {
        var q = Queue<Int>()
        XCTAssertEqual(nil, q.next())
        XCTAssertEqual(nil, q.next())
    }
    
    func testBasic() {
        var q = Queue<Int>()
        q.append(1)
        XCTAssertEqual(1, q.next())
        XCTAssertEqual(nil, q.next())
    }
    
    func testLonger() {
        var q = Queue<Int>()
        q.append(1)
        q.append(2)
        XCTAssertEqual(1, q.next())
        XCTAssertEqual(2, q.next())
        XCTAssertEqual(nil, q.next())
    }
    
    func testMixed() {
        var q = Queue<Int>()
        q.append(1)
        _ = q.next()
        q.append(2)
        XCTAssertEqual(2, q.next())
        XCTAssertEqual(nil, q.next())
    }
}
