import XCTest
@testable import ExcelFormulaParser2

final class PeekableIteratorTest: XCTestCase {
    func testBasic() {
        var i = PeekableIterator([1,2,3].makeIterator())
        XCTAssertEqual(1, i.peek())
        XCTAssertEqual(1, i.next())
        XCTAssertEqual(2, i.peek())
    }
    
    func testOrder() {
        var i = PeekableIterator([1,2,3].makeIterator())
        XCTAssertEqual(1, i.next())
        XCTAssertEqual(2, i.peek())
    }
    
    func testPeekFurther() {
        var i = PeekableIterator([1,2,3].makeIterator())
        XCTAssertEqual(2, i.peekFurther())
        XCTAssertEqual(2, i.peekFurther())
        XCTAssertEqual(1, i.peek())
        XCTAssertEqual(1, i.peek())
        XCTAssertEqual(1, i.next())
        XCTAssertEqual(2, i.peek())
        XCTAssertEqual(3, i.peekFurther())
        XCTAssertEqual(2, i.next())
        XCTAssertEqual(nil, i.peekFurther())
        XCTAssertEqual(3, i.peek())
        XCTAssertEqual(3, i.next())
        XCTAssertEqual(nil, i.peek())
        XCTAssertEqual(nil, i.peekFurther())
        XCTAssertEqual(nil, i.next())

    }
}
