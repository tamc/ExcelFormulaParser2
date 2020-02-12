import Foundation

enum ExcelExpression: Hashable {
    case empty
    case string(String)
    case error(ExcelError)
    case number(Decimal)
    case boolean(Bool)
    indirect case function(name: String, arguments: ExcelExpression = .list([]))
    indirect case list([ExcelExpression])
    indirect case maths(ExcelExpression, [MathsOperation])
}

enum MathsOperation: Hashable {
    case add(ExcelExpression)
    case subtract(ExcelExpression)
    case multiply(ExcelExpression)
    case divide(ExcelExpression)
    case power(ExcelExpression)
}

struct Parser {
    private var tokens: PeekableIterator<ExcelToken>
    
    init<S: IteratorProtocol>(_ tokens: S) where S.Element == ExcelToken {
        self.tokens = PeekableIterator(tokens)
    }
    
    mutating func result(ignoring: [ExcelToken] = []) -> ExcelExpression? {
        guard let parsed = parseNextToken() else { return nil }
        guard let next = tokens.peek() else { return parsed }
        if ignoring.contains(next) { return parsed }
        if next == .symbol(.maths(.add)) {
            return parseOperator(parsed, [.add, .subtract])
        }
        if next == .symbol(.maths(.subtract)) {
            return parseOperator(parsed, [.add, .subtract])
        }
        if next == .symbol(.maths(.multiply)) {
            return parseOperator(parsed, [.multiply, .divide])
        }
        if next == .symbol(.maths(.divide)) {
            return parseOperator(parsed, [.multiply, .divide])
        }
        return parsed
    }
    
    mutating func parseNextToken() -> ExcelExpression? {
        guard let token = tokens.next() else { return nil }
        switch token {
        case .literal(let s, let e):
            if s == "TRUE" { return .boolean(true) }
            if s == "FALSE" { return .boolean(false) }
            if case .symbol(.open(.bracket)) = tokens.peek() {
                _ = tokens.next()
                let arguments = parseList(separator: .symbol(.comma), close: .symbol(.close(.bracket)))
                let name = removeEscapes(string: s, containsEscapeSequence: e, escapeSequence: "''", escapeReplacement: "'")
    
                return .function(name: name, arguments: arguments)
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
                fatalError("Unexpected close")
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
    
    mutating func parseList(separator: ExcelToken, close: ExcelToken) -> ExcelExpression {
        var parsedExpression = false
        var list = [ExcelExpression]()
        while true {
            guard let token = tokens.peek() else { return .list(list) }
            if token == separator {
                // e.g., (1,,3) == [1, .empty, 3]
                if parsedExpression == false {
                    list.append(.empty)
                }
                _ = tokens.next()
                parsedExpression = false
                continue
            }
            if token == close {
                _ = tokens.next()
                // e.g., () == []
                if list.isEmpty {
                    return .list(list)
                }
                // e.g, (,) == [.empty, .empty]
                if parsedExpression == false {
                    list.append(.empty)
                }
                return .list(list)
            }
            
            if let subExpression = result() {
                list.append(subExpression)
                parsedExpression = true
            }
        }
    }
    
    mutating func parseOperator(_ first: ExcelExpression, _ symbols: [ExcelMathOperator]) -> ExcelExpression {
        let okSymbols = symbols.map({ExcelToken.symbol(.maths($0))})
        var list = [MathsOperation]()
        while true {
            guard let peek = tokens.peek() else {
                return .maths(first, list)
            }
            if okSymbols.contains(peek) {
                let t = tokens.next()
                if let e = result(ignoring: okSymbols) {
                    switch t {
                    case .symbol(.maths(.add)):
                        list.append(.add(e))
                    case .symbol(.maths(.subtract)):
                        list.append(.subtract(e))
                    case .symbol(.maths(.multiply)):
                        list.append(.multiply(e))
                    case .symbol(.maths(.divide)):
                        list.append(.divide(e))
                    default:
                        fatalError("Not implemented")
                    }
                }
                continue
            }
            return .maths(first, list)
        }
    }
}


func removeEscapes(string: Substring, containsEscapeSequence: Bool, escapeSequence: String, escapeReplacement: String) -> String {
    guard containsEscapeSequence else { return String(string) }
    return string.replacingOccurrences(of: escapeSequence, with: escapeReplacement)
    
}


