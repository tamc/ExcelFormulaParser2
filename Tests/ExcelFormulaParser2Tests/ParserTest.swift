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
    
    func testArithmetic() {
        assertResult(.maths(.number(1), [.add(.number(1))]), from: "1+1")
        assertResult(.maths(.number(1), [.add(.number(1)), .add(.number(2))]), from: "1+ 1+ 2")
        
        assertResult(.maths(.number(1), [.subtract(.number(1))]), from: "1-1")
        assertResult(.maths(.number(-1), [.subtract(.number(1))]), from: "-1-1")
        assertResult(.maths(.number(1), [.add(.number(1)), .subtract(.number(2))]), from: "1+ 1-2")
        
        assertResult(.maths(.number(1), [.multiply(.number(2))]), from: "1*2")
    }
    
    func testArithmeticPrecedent() {
        assertResult(
            .maths(.number(1), [.add(.maths(.number(3), [.multiply(.number(2)), .divide(.number(5))]))]),
            from: "1+3*2/5")
        
        assertResult(
            .maths(.maths(.number(3), [.multiply(.number(2)), .divide(.number(5))]), [.subtract(.number(1))]),
            from: "3*2/5-1")
    }
    
    func testFunctions() {
        assertResult(.function(name: "NOW"), from: "NOW()")
    }
    
    func testArguments() {
        assertResult(.function(name: "IF", arguments: .list([.boolean(true), .boolean(false)])), from: "IF(TRUE, FALSE)")
    }
    
    func testNestedFunctions() {
        assertResult(
            .function(
                name: "IF",
                arguments: .list([
                    .function(
                        name: "IF",
                        arguments: .list([
                            .boolean(true),
                            .boolean(false)
                        ])),
                    .boolean(true)
                ])
            ),
            from: "IF(IF(TRUE, FALSE), TRUE)")
    }
  
    
    private func assertResult(_ expected: ExcelExpression?, from: String, file: StaticString = #file,
                              line: UInt = #line) {
        let tokens = Tokenizer(from)
        var parser = Parser(tokens)
        let result = parser.result()
        if result != expected {
            dump(result)
        }
        XCTAssertEqual(expected, result, "Parsing \(from)", file: file, line: line)
    }
}
