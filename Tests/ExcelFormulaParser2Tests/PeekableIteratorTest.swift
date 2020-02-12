import XCTest
@testable import ExcelFormulaParser2

final class PeekableIteratorTest: XCTestCase {
    func testBasic() {
        var i = PeekableIterator([1,2,3].makeIterator())
        XCTAssertEqual(1, i.peek())
        XCTAssertEqual(1, i.next())
    }
}
