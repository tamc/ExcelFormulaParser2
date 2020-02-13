import Foundation

enum ExcelToken: Hashable {
    case literal(Substring)
    case string(Substring)
    case error(ExcelError)
    case number(Decimal)
    case symbol(ExcelSymbol)
}

enum ExcelError: String, Hashable {
    case ref = "#REF!"
    case name = "#NAME?"
    case value = "#VALUE!"
    case div0 = "#DIV/0!"
    case na = "#N/A"
    case num = "#NUM!"
}

enum ExcelSymbol: Hashable {
    case maths(ExcelMathOperator)
    case open(ExcelOpenClosable)
    case close(ExcelOpenClosable)
    case ampersand
    case comma
    case bang
    case colon
    case percent
}

enum ExcelMathOperator: Hashable {
    case add
    case subtract
    case multiply
    case divide
    case power
}

enum ExcelOpenClosable: Hashable {
    case bracket
    case squareBracket
}

struct Tokenizer: Sequence, IteratorProtocol {
    typealias Element = ExcelToken
    
    private let s: String
    /// Current token start
    private var ts: String.Index
    /// Current token end
    private var te: String.Index
    /// Current token range
    private var tr: Range<String.Index> { ts..<te }
    /// Current token substring
    private var token: Substring { s[tr] }
    /// Next character (warning, will fatal error if te >= s.endIndex
    private var nextCharacter: Character { s[te] }
    /// Different escaping rules inside square brackets...
    private var outsideSquareBrackets = true
        
    init(_ s: String) {
        self.s = s
        self.ts = s.startIndex
        self.te = s.startIndex
    }
        
    mutating func next() -> ExcelToken? {
        while isAnotherToken() {
            if isWhitespace() {
                skipWhitespace()
                continue
            }
            
            if outsideSquareBrackets {
                return nextOutsideSquareBrackets()
            } else {
                return nextInsideSquareBrackets()
            }
        }
        return nil
    }
    
    private func isWhitespace() -> Bool {
        return CharacterSet
            .whitespacesAndNewlines
            .containsUnicodeScalars(of: nextCharacter)
    }
    
    mutating private func nextOutsideSquareBrackets() -> ExcelToken? {
        switch nextCharacter {
        case "#": return excelError()
        case "\"": return excelString()
        case "'": return excelEscapedLiteral()
        case CharacterSet.decimalDigits: return number()
        case CharacterSet.excelSymbols: return symbol()
        case CharacterSet.excelLiteralFirstCharacter: return literal()
        default:
            fail("Could not identify first character of the token")
        }
    }
    
    mutating private func nextInsideSquareBrackets() -> ExcelToken? {
        // Different escaping rules inside structured table references
        switch nextCharacter {
        case "[": return excelEscapedStructuredLiteral()
        case CharacterSet.unescapedStructuredFirstChars: return excelStructuredLiteral()
        case CharacterSet.excelSymbols: return symbol()
        default:
            fail("Could not identify first character of the token")
        }

    }
    
    mutating private func number() -> ExcelToken? {
        extendToken(while: .decimalDigits)
        if extendToken(if: .decimalPoint) {
            extendToken(while: .decimalDigits)
        }
        if extendToken(if: .decimalExponent) {
            extendToken(if: .decimalPlusMinus)
            extendToken(while: .decimalDigits)
        }
        guard let n = Decimal(string: String(token)) else {
            fail("Could not convert \(token) into a Decimal")
        }
        startNextToken()
        return .number(n)
    }
    
    mutating private func symbol() -> ExcelToken? {
        extendToken(if: .excelSymbols)

        var result: ExcelSymbol
        switch token {
            
        case "+": result = .maths(.add)
        case "-": result = .maths(.subtract)
        case "*": result = .maths(.multiply)
        case "/": result = .maths(.divide)
        case "^": result = .maths(.power)
            
        case "(": result = .open(.bracket)
        case ")": result = .close(.bracket)
        case "[":
            outsideSquareBrackets = false
            result = .open(.squareBracket)
        case "]":
            outsideSquareBrackets = true
            result = .close(.squareBracket)
            
        case "!": result = .bang
        case ":": result = .colon
        case ",": result = .comma
        case "&": result = .ampersand
        case "%": result = .percent

        default:
            fail("Could not convert \(token) into an ExcelSymbol")
        }
        startNextToken()
        return .symbol(result)
    }
    
    mutating private func literal() -> ExcelToken? {
        extendToken(while: .excelLiteral)
        let string = token
        startNextToken()
        return .literal(string)
    }
    
    mutating private func excelError() -> ExcelToken? {
        extendToken(while: .excelError)
        guard let e = ExcelError.init(rawValue: String(token)) else {
            fail("Could not convert \(token) into an ExcelError")
        }
        startNextToken()
        return .error(e)
    }
    
    mutating private func excelEscapedLiteral() -> ExcelToken? {
        let result =  escapedString(marker: "'")
        guard let s = result else { return nil }
        return .literal(s)
    }
    
    mutating private func excelStructuredLiteral() -> ExcelToken? {
        let c = CharacterSet.unescapedStructuredSubsequentChars
        var escapeCharacters = [String.Index]()
        outerloop: while canAdvanceEnd() {
            switch nextCharacter {
            case c:
                advanceEnd()
            case "'":
                escapeCharacters.append(te)
                advanceEnd(by: 2)
            default:
                break outerloop
            }
        }
        let string = token.havingRemoved(baseIndexes: escapeCharacters)
        startNextToken()
        return .literal(string)
    }
    
    mutating private func excelEscapedStructuredLiteral() -> ExcelToken? {
        advanceEnd() // Skip first [
        advanceStart()  // Skip first [
        
        extendToken(while: .escapedStructuredChars)
        let string = token
        if canAdvanceEnd() {
            advanceEnd() // Skip closing ]
        }
        startNextToken()
        return .literal(string)
    }
    
    mutating private func excelString() -> ExcelToken? {
        let result = escapedString(marker: "\"")
        guard let s = result else { return nil }
        return .string(s)
    }
    
    mutating private func escapedString(marker: Character) -> Substring? {
        advanceEnd() // Skip first "
        advanceStart() // Skip first "
        
        var escapeCharacters = [String.Index]()
        while canAdvanceEnd() {
            while canAdvanceEnd(), nextCharacter != marker {
                advanceEnd()
            }
            // Check if we have hit a double marker (like "") in which case is an escaped marker in Excel.
            if peekNextCharacter() == marker {
                escapeCharacters.append(te)
                advanceEnd(by: 2) // Skip both " in ""
                continue
            } 
            break
        }
        let string = token.havingRemoved(baseIndexes: escapeCharacters)
        if canAdvanceEnd() {
            advanceEnd() // Skip closing "
        }
        startNextToken()
        return string
    }
    
    mutating private func skipWhitespace() {
        extendToken(while: .whitespacesAndNewlines)
        /// Note:  we do not return the whitespace
        startNextToken()
    }
    
    mutating private func startNextToken() {
        ts = te
    }
    
    /// Extends the token to cover any subsequent characters that are in the characterset
    mutating private func extendToken(while characterset: CharacterSet) {
        while canAdvanceEnd(), characterset.containsUnicodeScalars(of: nextCharacter) {
            advanceEnd()
        }
    }
    
    /// If the next character is in the characterset, extends the token to cover that character and returns true
    /// Otherwise leaves the token as is and returns false
    @discardableResult
    mutating private func extendToken(if characterset: CharacterSet) -> Bool {
        if canAdvanceEnd(), characterset.containsUnicodeScalars(of: nextCharacter) {
            advanceEnd()
            return true
        }
        return false
    }

    private func fail(_ message: String, file: StaticString = #file,
    line: UInt = #line) -> Never {
        mark(range: tr, in: s)
        fatalError(message, file: file, line: line)
    }
    
    private mutating func advanceStart() {
        ts = s.index(ts, offsetBy: 1)
    }
    
    private mutating func advanceEnd(by offset: Int = 1) {
        te = s.index(te, offsetBy: offset)
    }
    
    private func isAnotherToken() -> Bool {
        return canAdvanceStart() && canAdvanceEnd()
    }
    
    private func canAdvanceStart() -> Bool {
        return ts < s.endIndex
    }
    
    private func canAdvanceEnd() -> Bool {
        return te < s.endIndex
    }
    
    private func peekNextCharacter() -> Character? {
        guard canAdvanceEnd() else { return nil }
        let peekIndex = s.index(te, offsetBy: 1)
        guard peekIndex < s.endIndex else { return nil }
        return s[peekIndex]
    }

}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}

private func ~= (pattern: CharacterSet, value: Character) -> Bool {
    return pattern.containsUnicodeScalars(of: value)
}

extension CharacterSet {
    static let excelError = CharacterSet(charactersIn: "#REF!#NAME?#VALUE!#DIV/0!#N/A#NUM!")
    static let excelSymbols = CharacterSet(charactersIn: "+-*/^()[]!:,&%")
    static let excelLiteralFirstCharacter = alphanumerics.union(CharacterSet(charactersIn: "_$"))
    static let excelLiteral = alphanumerics.union(CharacterSet(charactersIn: "_.$"))
    static let decimalPoint = CharacterSet(charactersIn: ".")
    static let decimalExponent = CharacterSet(charactersIn: "eE")
    static let decimalPlusMinus = CharacterSet(charactersIn: "+-")
    
    static let unescapedStructuredFirstChars = alphanumerics.union(CharacterSet(charactersIn: "'"))
    static let unescapedStructuredSubsequentChars = alphanumerics.union(CharacterSet(charactersIn: " "))
    
    static let escapedStructuredChars = alphanumerics.union(CharacterSet(charactersIn: " #,:.\"{}$^&*+=-<>/"))
}

func mark(range: Range<String.Index>, in string: String) {
    print(string)
    let marker = String(repeating: " ", count: string.count)
    let f = range.lowerBound.samePosition(in: marker) ?? marker.startIndex
    let t = range.upperBound.samePosition(in: marker) ?? marker.endIndex
    let c = marker.distance(from: f, to: t)
    let result = marker.replacingCharacters(in: f..<t, with: String(repeating: "^", count: c))
    print(result)
}

extension Substring {
    func havingRemoved(baseIndexes: [String.Index]) -> Substring {
        guard baseIndexes.isEmpty == false else { return self }
        var e = self
        for i in baseIndexes.reversed() {
            let sd = base.distance(from: startIndex, to: i)
            let si = e.index(e.startIndex, offsetBy: sd)
            e.remove(at: si)
        }
        return Substring(e)
    }
}
