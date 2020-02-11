import XCTest
@testable import ExcelFormulaParser2

final class ParserTest: XCTestCase {
    func testBasicTypes() {
        assertResult(nil, from: "")
        assertResult(.number(1), from: "1")
        assertResult(.number(1), from: "1")
        assertResult(.boolean(true), from: "TRUE")
        assertResult(.boolean(false), from: "FALSE")
        assertResult(.string("Hello world"), from: "\"Hello world\"")
        assertResult(.error(.num), from: "#NUM!")
    }
    
    func testNegativeNumbers() {
        assertResult(.number(-1), from: "-1")
    }
    
    func testFunctions() {
        assertResult(.function(name: "NOW"), from: "NOW()")
    }
    
    func testList() {
        assertResult(.function(name: "IF"), from: "IF()")
    }
  
    
    private func assertResult(_ expected: ExcelExpression?, from: String, file: StaticString = #file,
                              line: UInt = #line) {
        let tokens = Tokenizer(from)
        var parser = Parser(tokens)
        let result = parser.result()
        XCTAssertEqual(expected, result, "Parsing \(from)", file: file, line: line)
    }
}
