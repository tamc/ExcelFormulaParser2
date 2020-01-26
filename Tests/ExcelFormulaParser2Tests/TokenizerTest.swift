import XCTest
@testable import ExcelFormulaParser2

final class TokenizerTest: XCTestCase {
    func testBasicTypes() {
        /// Empty
        assertTokens([], from: "")
        
        /// Literals
        assertTokens(["TRUE"], from: "TRUE")
        assertTokens(["FALSE"], from: "FALSE")
        assertTokens(["IF"], from: "IF")
        assertTokens(["_IF"], from: "_IF")
        assertTokens(["IF2"], from: "IF2")
        assertTokens(["IF2"], from: "IF2")
        assertTokens(["IF2.3"], from: "IF2.3")
        assertTokens(["IF_2.3"], from: "IF_2.3")
        
        /// Escaped literals
        assertTokens(["Sheet 1"], from: "'Sheet 1'")
        
        /// Errors
        assertTokens(["#REF!"], from: "#REF!")
        assertTokens(["#NAME?"], from: "#NAME?")
        assertTokens(["#VALUE!"], from: "#VALUE!")
        assertTokens(["#DIV/0!"], from: "#DIV/0!")
        assertTokens(["#N/A"], from: "#N/A")
        assertTokens(["#NUM!"], from: "#NUM!")
        
        /// Numbers
        assertTokens(["1"], from: "1")
        assertTokens(["1.1"], from: "1.1")
        assertTokens(["1.1E1"], from: "1.1E1")
        assertTokens(["1.1E1"], from: "1.1E1")
        assertTokens(["1.1E-1"], from: "1.1E-1")
        assertTokens(["1E-1"], from: "1E-1")
        assertTokens(["1E10"], from: "1E10")
        
        /// Symbols
        assertTokens(["+"], from: "+")
        assertTokens(["-"], from: "-")
        assertTokens(["*"], from: "*")
        assertTokens(["/"], from: "/")
        assertTokens(["^"], from: "^")
        assertTokens(["("], from: "(")
        assertTokens([")"], from: ")")
        assertTokens(["["], from: "[")
        assertTokens(["]"], from: "]")
        assertTokens(["!"], from: "!")
        assertTokens([":"], from: ":")
        assertTokens([","], from: ",")
        assertTokens(["&"], from: "&")
        
        /// Strings
        assertTokens(["Hello world"], from: "\"Hello world\"")
        assertTokens(["Hello \"\"world"], from: "\"Hello \"\"world\"")
    }
    
    func testBasicSequence() {
        assertTokens(["1", "+", "1"], from: "1+1")
    }
    
    func testErrorInSequence() {
        assertTokens(["#DIV/0!", "+", "1"], from: "#DIV/0!+1")
    }
    
    func testWhitespace() {
        assertTokens(["A", "B"], from: "A B")
    }

    func testWhitespaceInMaths() {
        assertTokens(["3.145e12", "*", "14e-6"], from: " 3.145e12 * 14e-6 ")
    }
    
    func testWhitespaceInStringJoin() {
        assertTokens(["A sheet''", "!", "A1", "&", " a string\n\"\"Yes\"\"\n"], from: "'A sheet'''!A1&\" a string\n\"\"Yes\"\"\n")
    }
    
    private func assertTokens(_ expected: [String], from: String, file: StaticString = #file,
                              line: UInt = #line) {
        let result = Array(Tokenizer(from).map({String($0)}))
        XCTAssertEqual(expected, result, "Parsing \(from)", file: file, line: line)
    }
}
