import XCTest
@testable import ExcelFormulaParser2

final class TokenizerTest: XCTestCase {
    func testBasicTypes() {
        /// Empty
        assertTokens([], from: "")
        
        /// Literals
        assertTokens([.literal("TRUE")], from: "TRUE")
        assertTokens([.literal("FALSE")], from: "FALSE")
        assertTokens([.literal("IF")], from: "IF")
        assertTokens([.literal("_IF")], from: "_IF")
        assertTokens([.literal("IF2")], from: "IF2")
        assertTokens([.literal("IF2")], from: "IF2")
        assertTokens([.literal("IF2.3")], from: "IF2.3")
        assertTokens([.literal("IF_2.3")], from: "IF_2.3")
        
        /// Escaped literals
        assertTokens([.literal("Sheet 1")], from: "'Sheet 1'")
        assertTokens([.literal("Sheet '1'")], from: "'Sheet ''1'''")
        
        /// Errors
        assertTokens([.error(.ref)], from: "#REF!")
        assertTokens([.error(.name)], from: "#NAME?")
        assertTokens([.error(.value)], from: "#VALUE!")
        assertTokens([.error(.div0)], from: "#DIV/0!")
        assertTokens([.error(.na)], from: "#N/A")
        assertTokens([.error(.num)], from: "#NUM!")
        
        /// Numbers
        assertTokens([.number(1)], from: "1")
        assertTokens([.number(1.1)], from: "1.1")
        assertTokens([.number(1.1e1)], from: "1.1E1")
        assertTokens([.number(1.1e-1)], from: "1.1E-1")
        assertTokens([.number(1e-1)], from: "1E-1")
        assertTokens([.number(1e10)], from: "1E10")
    
        /// Symbols
        assertTokens([.symbol(.maths(.add))], from: "+")
        assertTokens([.symbol(.maths(.subtract))], from: "-")
        assertTokens([.symbol(.maths(.multiply))], from: "*")
        assertTokens([.symbol(.maths(.divide))], from: "/")
        assertTokens([.symbol(.maths(.power))], from: "^")
        
        assertTokens([.symbol(.open(.bracket))], from: "(")
        assertTokens([.symbol(.close(.bracket))], from: ")")
        assertTokens([.symbol(.open(.squareBracket))], from: "[")
        assertTokens([.symbol(.close(.squareBracket))], from: "]")
        
        assertTokens([.symbol(.bang)], from: "!")
        assertTokens([.symbol(.colon)], from: ":")
        assertTokens([.symbol(.comma)], from: ",")
        assertTokens([.symbol(.ampersand)], from: "&")
        assertTokens([.symbol(.percent)], from: "%")
        
        assertTokens([.symbol(.comparison(.equal))], from: "=")
        assertTokens([.symbol(.comparison(.lessThan))], from: "<")
        assertTokens([.symbol(.comparison(.greaterThan))], from: ">")
        
        /// Strings
        assertTokens([.string("Hello world")], from: "\"Hello world\"")
        assertTokens([.string("Hello \"world")], from: "\"Hello \"\"world\"")
    }
    
    func testTwoCharacterComparisons() {
        assertTokens([.symbol(.comparison(.notEqual))], from: "<>")
        assertTokens([.symbol(.comparison(.lessThanOrEqual))], from: "<=")
        assertTokens([.symbol(.comparison(.greaterThanOrEqual))], from: ">=")
    }
    
    func testBasicSequence() {
        assertTokens([.number(1), .symbol(.maths(.add)), .number(1)], from: "1+1")
    }
    
    func testErrorInSequence() {
        assertTokens([.error(.div0), .symbol(.maths(.add)), .number(1)], from: "#DIV/0!+1")
    }
    
    func testWhitespace() {
        assertTokens([.literal("A"), .literal("B")], from: "A B")
    }

    func testWhitespaceInMaths() {
        assertTokens([.number(3.145e12), .symbol(.maths(.multiply)), .number(14e-6)], from: " 3.145e12 * 14e-6 ")
    }
    
    func testWhitespaceInStringJoin() {
        assertTokens([.literal("A sheet'"), .symbol(.bang), .literal("$A$1"), .symbol(.ampersand), .string(" a string\n\"Yes\"\n")], from: "'A sheet'''!$A$1&\" a string\n\"\"Yes\"\"\n")
    }
    
    func testStructuredTableReferenceEscaping() {
        assertTokens([
            .literal("Table1"),
            .symbol(.open(.squareBracket)),
            .literal("#All"),
            .symbol(.comma),
            .literal("Column 1"),
            .symbol(.close(.squareBracket)),
        ], from: "Table1[[#All], [Column 1]]")
    }
    
    func testEscapingInStructuredTableReferences() {
        assertTokens([
            .symbol(.open(.squareBracket)),
            .literal("[#OfItems']"),
            .symbol(.close(.squareBracket)),
        ], from: "['['#OfItems''']]")
    }
    
    func testEscapingInEscapedStructuredTableReferences() {
        assertTokens([
            .symbol(.open(.squareBracket)),
            .literal("[ #! :OfItems']"),
            .symbol(.close(.squareBracket)),
        ], from: "[['[ #! :OfItems''']]]")
    }
    
    private func assertTokens(_ expected: [ExcelToken], from: String, file: StaticString = #file,
                              line: UInt = #line) {
        let result = Array(Tokenizer(from))
        XCTAssertEqual(expected, result, "Parsing \(from)", file: file, line: line)
    }
}
