import Foundation

struct Tokenizer: Sequence, IteratorProtocol {
    typealias Element = Substring
    
    private let s: String
    /// Token start
    private var ts: String.Index
    /// Token end
    private var te: String.Index
        
    init(_ s: String) {
        self.s = s
        self.ts = s.startIndex
        self.te = s.startIndex
    }
        
    mutating func next() -> Substring? {
        while ts < s.endIndex && te < s.endIndex {
            switch s[te] {
            case "#": return excelError()
            case "\"": return excelString()
            case "'": return excelEscapedLiteral()
            case CharacterSet.decimalDigits: return number()
            case CharacterSet.excelSymbols: return symbol()
            case CharacterSet.whitespacesAndNewlines: skipWhitespace()
            case CharacterSet.excelLiteralFirstCharacter: return literal()
            default: return nil
            }
        }
        return nil
    }
    
    mutating private func number() -> Substring? {
        while te < s.endIndex, CharacterSet.decimalDigits.containsUnicodeScalars(of: s[te]) {
            te = s.index(te, offsetBy: 1)
        }
        if te < s.endIndex, s[te] == "." {
            te = s.index(te, offsetBy: 1)
        }
        while te < s.endIndex, CharacterSet.decimalDigits.containsUnicodeScalars(of: s[te]) {
            te = s.index(te, offsetBy: 1)
        }
        if te < s.endIndex, (s[te] == "E" || s[te] == "e") {
            te = s.index(te, offsetBy: 1)
            if te < s.endIndex, s[te] == "-" {
                te = s.index(te, offsetBy: 1)
            }
            if te < s.endIndex, s[te] == "+" {
                te = s.index(te, offsetBy: 1)
            }
        }
        while te < s.endIndex, CharacterSet.decimalDigits.containsUnicodeScalars(of: s[te]) {
            te = s.index(te, offsetBy: 1)
        }
        let result = s[ts..<te]
        ts = te
        return result
    }
    
    mutating private func symbol() -> Substring? {
        if te < s.endIndex, CharacterSet.excelSymbols.containsUnicodeScalars(of: s[te]) {
            te = s.index(te, offsetBy: 1)
        }
        let result = s[ts..<te]
        ts = te
        return result
    }
    
    mutating private func literal() -> Substring? {
        while te < s.endIndex, CharacterSet.excelLiteral.containsUnicodeScalars(of: s[te]) {
            te = s.index(te, offsetBy: 1)
        }
        let result = s[ts..<te]
        ts = te
        return result
    }
    
    mutating private func excelError() -> Substring? {
        while te < s.endIndex, CharacterSet.excelError.containsUnicodeScalars(of: s[te]) {
            te = s.index(te, offsetBy: 1)
        }
        let result = s[ts..<te]
        ts = te
        return result
    }
    
    mutating private func excelEscapedLiteral() -> Substring? {
        return escapedString(marker: "'")
    }
    
    mutating private func excelString() -> Substring? {
        return escapedString(marker: "\"")
    }
    
    mutating private func escapedString(marker: Character) -> Substring? {
        te = s.index(te, offsetBy: 1) // First "
        ts = s.index(ts, offsetBy: 1) // First "
        while te < s.endIndex {
            while te < s.endIndex, s[te] != marker {
                te = s.index(te, offsetBy: 1) // First "
            }
            if te < s.endIndex {
                let peek = s.index(te, offsetBy: 1)
                if peek < s.endIndex, s[peek] == marker { // A "", which means an escaped string
                    te = s.index(te, offsetBy: 2) // Skip both " in ""
                    continue
                }
            }
            break
        }
        let result = s[ts..<te]
        if te < s.endIndex {
            te = s.index(te, offsetBy: 1) // Last "
        }
        ts = te
        return result
    }
    
    mutating private func skipWhitespace() {
        while te < s.endIndex, CharacterSet.whitespacesAndNewlines.containsUnicodeScalars(of: s[te]) {
            te = s.index(te, offsetBy: 1)
        }
        ts = te
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
    static let excelSymbols = CharacterSet(charactersIn: "+-*/^()[]!:,&")
    static let excelLiteralFirstCharacter = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    static let excelLiteral = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.$"))
}
