import Foundation

enum ExcelExpression: Hashable {
    case empty
    case string(String)
    case error(ExcelError)
    case number(Decimal)
    case boolean(Bool)
    indirect case function(name: String, arguments: ExcelExpression? = nil)
}

struct Parser {
    private var tokens: PeekableIterator<ExcelToken>
    
    init<S: IteratorProtocol>(_ tokens: S) where S.Element == ExcelToken {
        self.tokens = PeekableIterator(tokens)
    }
    
    mutating func result() -> ExcelExpression? {
        guard let token = tokens.next() else { return nil }
        switch token {
        case .literal(let s, let e):
            if s == "TRUE" { return .boolean(true) }
            if s == "FALSE" { return .boolean(false) }
            if case .symbol(.open(.bracket)) = tokens.peek() {
                _ = tokens.next()
                var arguments = Parser(tokens)
                let name = removeEscapes(string: s, containsEscapeSequence: e, escapeSequence: "''", escapeReplacement: "'")
    
                return .function(name: name, arguments: arguments.result())
            }
            return .empty
        case .string(let s, let e):
            return .string(removeEscapes(string: s, containsEscapeSequence: e, escapeSequence: "\"\"", escapeReplacement: "\""))
        case .error(let e):
            return .error(e)
        case .number(let n):
            return .number(n)
        case .symbol(let s):
            switch s {
            case .close:
                return nil
            case .maths(.subtract):
                if case let .number(n) = tokens.peek() {
                    _ = tokens.next()
                    return .number(-n)
                }
                return .empty
                
            default:
                return .empty

            }
        }
    }
}


func removeEscapes(string: Substring, containsEscapeSequence: Bool, escapeSequence: String, escapeReplacement: String) -> String {
    guard containsEscapeSequence else { return String(string) }
    return string.replacingOccurrences(of: escapeSequence, with: escapeReplacement)
    
}


