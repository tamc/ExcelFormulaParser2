import XCTest
@testable import ExcelFormulaParser2

final class ParserTest: XCTestCase {
    
    func testCanInitializeWithString() {
        let string = "1"
        var withString = Parser(string)
        var withoutString = Parser(Tokenizer(string))
        XCTAssertEqual(withString.result(), withoutString.result())
    }
    
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
        assertResult(.maths([.start(.number(1)), .add(.number(1))]), from: "1+1")
        assertResult(.maths([.start(.number(1)), .add(.number(1)), .add(.number(2))]), from: "1+ 1+ 2")
        
        assertResult(.maths([.start(.number(1)), .subtract(.number(1))]), from: "1-1")
        assertResult(.maths([.start(.number(-1)), .subtract(.number(1))]), from: "-1-1")
        assertResult(.maths([.start(.number(1)), .add(.number(1)), .subtract(.number(2))]), from: "1+ 1-2")
        
        assertResult(.maths([.start(.number(1)), .multiply(.number(2))]), from: "1*2")
    }
    
    func testArithmeticPrecedent() {
        assertResult(
            .maths([.start(.number(1)), .add(.maths([.start(.number(3)), .multiply(.number(2)), .divide(.number(5))]))]),
            from: "1+3*2/5")
        
        assertResult(
            .maths([
                .start(
                    .maths([
                        .start(.number(3)),
                        .multiply(.number(2)),
                        .divide(.number(5))
                ])),
                .subtract(.number(1))
            ]),
            from: "3*2/5-1"
        )
    }
    
    func testBrackets() {
        assertResult(.maths([
            .start(.brackets(.maths([.start(.number(1)), .add(.number(3))]))),
            .multiply(.brackets(.maths([.start(.number(2)), .divide(.number(5))])))
            ]),
            from: "(1+3)*(2/5)")
    }
    
    func testPercentage() {
        assertResult(
            .maths([.percent(.number(100))]),
            from: "100%"
        )
        assertResult(
            .maths([.percent(.brackets(.maths([.start(.number(10)), .add(.number(20))])))]),
            from: "(10+20)%"
        )
    }
    
    func testNegativePrefix() {
        assertResult(.maths([
            .subtract(
                .brackets(
                    .maths([
                        .start(.number(1)),
                        .add(.number(3))
                    ])
                )
            )
        ]),
                     from: "-(1+3)")
    }
    
    func testTextJoin() {
        assertResult(.textJoin(.string("Hello"), .string("World")), from: "\"Hello\"&\"World\"")
    }
    
    func testComparisons() {
        assertResult(
            .comparison(.equal, .number(1), .number(2)),
            from: "1=2"
        )
        assertResult(
            .comparison(.notEqual, .number(1), .number(2)),
            from: "1<>2"
        )
        assertResult(
            .comparison(.greaterThan, .number(1), .number(2)),
            from: "1>2"
        )
        assertResult(
            .comparison(.lessThan, .number(1), .number(2)),
            from: "1<2"
        )
        assertResult(
            .comparison(.greaterThanOrEqual, .number(1), .number(2)),
            from: "1>=2"
        )
        assertResult(
            .comparison(.lessThanOrEqual, .number(1), .number(2)),
            from: "1<=2"
        )
    }
    
    func testComparisonPrecedence() {
        assertResult(
            .comparison(
                .equal,
                .number(3),
                .maths([
                    .start(.number(1)),
                    .add(.number(2))
                ])
            ),
            from: "3=1+2"
        )
        assertResult(
            .comparison(
                .equal,
                .string("AB"),
                .textJoin(
                    .string("A"),
                    .string("B")
                )
            ),
            from: """
            "AB"="A"&"B"
            """
        )
    }
    
    func testStringJoinPrecedence() {
        assertResult(
            .textJoin(
                .maths([
                    .start(.number(1)),
                    .add(.number(2))
                ]),
                .maths([
                    .start(.number(3)),
                    .multiply(.number(4))
                ])
            ),
            from: "1+2&3*4"
        )
    }
    
    func testFunctions() {
        assertResult(.function(name: "NOW"), from: "NOW()")
    }
    
    func testArguments() {
        assertResult(.function(name: "IF", arguments: [.boolean(true), .boolean(false)]), from: "IF(TRUE, FALSE)")
    }
    
    func testNestedFunctions() {
        assertResult(
            .function(
                name: "IF",
                arguments: [
                    .function(
                        name: "IF",
                        arguments: [
                            .boolean(true),
                            .boolean(false)
                        ]),
                    .boolean(true)
                ]
            ),
            from: "IF(IF(TRUE, FALSE), TRUE)")
    }
  
    func testSimpleReference() {
        assertResult(.ref("A1"), from: "A1")
    }
    
    func testRangeReference() {
        assertResult(.range(.ref("A1"), .ref("B3")), from: "A1:B3")
        assertResult(
            .range(
                .function(name: "OFFSET", arguments: [.ref("A1"), .number(1), .number(1)]),
                .function(name: "OFFSET", arguments: [.ref("A1"), .number(2), .number(3)])
            ),
            from: "OFFSET(A1,1,1):OFFSET(A1,2,3)")
    }
    
    func testSheetReference() {
        assertResult(.sheet(.ref("Sheet1"), .ref("B3")), from: "Sheet1!B3")
        assertResult(.sheet(.ref("Sheet1"), .ref("B3")), from: "'Sheet1'!B3")
        assertResult(.range(.sheet(.ref("Sheet1"), .ref("A1")), .ref("B3")), from: "Sheet1!A1:B3")
        assertResult(.range(.sheet(.ref("Sheet1"), .ref("A1")), .sheet(.ref("Sheet1"), .ref("B3"))), from: "Sheet1!A1:Sheet1!B3")
        
        // FIXME: Not sure about this one
        assertResult(.range(.range(.ref("Sheet1"), .sheet(.ref("Sheet2"), .ref("A1"))), .ref("B3")), from: "Sheet1:Sheet2!A1:B3")
    }
    
    func testSheetIntersection() {
        assertResult(
            .intersection(
                .range(.sheet(.ref("Sheet1"), .ref("A1")), .ref("B3")),
                .intersection(
                    .ref("A1"),
                    .range(.ref("A1"), .ref("B3"))
                )
        ),
        from: "Sheet1!A1:B3 A1 A1:B3")
    }
    
    func testLocalTableReference() {
        assertResult(
            .structured(.ref("Sales")),
            from: "[Sales]")
        assertResult(
            .structured(.range(.ref("Sales Person"), .ref("Region") )),
            from: "[[Sales Person]:[Region]]")
    }
    
    func testRemoteTableReference() {
        assertResult(
            .table("DeptSales", .structured(.ref("Sales"))),
            from: "DeptSales[Sales]")
        assertResult(
            .table("DeptSales", .structured(.range(.ref("Sales Person"), .ref("Region")))),
            from: "DeptSales[[Sales Person]:[Region]]")
    }

    func testComplexTableReference() {
        assertResult(
            .table("DeptSales", .structured(.union([.ref("#All"), .ref("Sales Amount")]))),
            from: "DeptSales[[#All],[Sales Amount]]")
        
        assertResult(
            .table("DeptSales", .structured(.union([.ref("#All"), .range(.ref("Sales Amount"), .ref("% Commission"))]))),
        from: "DeptSales[[#All],[Sales Amount]:[% Commission]]")
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
