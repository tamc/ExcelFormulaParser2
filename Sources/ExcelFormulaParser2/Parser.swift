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
    indirect case intersection([ExcelExpression])
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
    
    mutating func result() -> ExcelExpression? {
        guard var parsed = parseNextToken() else { return nil }
        while let next = parseJoin(left: parsed) {
            parsed = next
        }
        return parsed
    }
    
    
    mutating func parseJoin(left: ExcelExpression) -> ExcelExpression? {
        guard let next = tokens.peek() else { return nil }
        if next.isExcelMathOperator {
            return parseOperator(left)
        }
        return nil
    }
    
    mutating func parseNextToken() -> ExcelExpression? {
        guard let token = tokens.peek() else { return nil }
        switch token {
        case .literal(let s, let e):
            _ = tokens.next()
            if s == "TRUE" {
                return .boolean(true)
            }
            if s == "FALSE" {
                return .boolean(false)
            }
            if case .symbol(.open(.bracket)) = tokens.peek() {
                _ = tokens.next()
                let arguments = parseList(separator: .symbol(.comma), close: .symbol(.close(.bracket)))
                let name = removeEscapes(string: s, containsEscapeSequence: e, escapeSequence: "''", escapeReplacement: "'")
    
                return .function(name: name, arguments: arguments)
            }
            fatalError("Not implemented yet")
        case .string(let s, let e):
            _ = tokens.next()
            return .string(removeEscapes(string: s, containsEscapeSequence: e, escapeSequence: "\"\"", escapeReplacement: "\""))
            
        case .error(let e):
            _ = tokens.next()
            return .error(e)
            
        case .number(let n):
            _ = tokens.next()
            return .number(n)
            
        case .symbol(let s):
            switch s {
            case .close:
                fatalError("Unexpected close")
            case .maths(.subtract):
                _ = tokens.next()
                if case let .number(n) = tokens.peek() {
                    _ = tokens.next()
                    return .number(-n)
                }
                return nil
                
            default:
                return nil

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
    
    mutating func parseOperator(_ left: ExcelExpression) -> ExcelExpression {
        var list = [MathsOperation]()
        
        guard var firstOp = tokens.next()?.excelMathOperator else {
            fatalError("Missing the first operator")
        }
        
        let precedence = firstOp.precedence
        
        while true {
            guard var right = parseNextToken() else {
                fatalError("Missing the right hand side")
            }
            
            if let secondOp = tokens.peek()?.excelMathOperator {
                if secondOp.precedence > precedence {
                    right = parseOperator(right)
                }
            }
            
            list.append(firstOp.toMathOperator(right))
            
            // Start on the next round
            guard let nextOp = tokens.peek()?.excelMathOperator else {
                break
            }
            
            if nextOp.precedence != precedence {
                break
            }
            
            _ = tokens.next()
            
            firstOp = nextOp
        }
        return .maths(left, list)
    }
}


func removeEscapes(string: Substring, containsEscapeSequence: Bool, escapeSequence: String, escapeReplacement: String) -> String {
    guard containsEscapeSequence else { return String(string) }
    return string.replacingOccurrences(of: escapeSequence, with: escapeReplacement)
}


private extension ExcelToken {
    var excelMathOperator: ExcelMathOperator? {
        guard case let .symbol(.maths(result)) = self else { return nil }
        return result
    }
        
    var isExcelMathOperator: Bool {
        return (excelMathOperator != nil)
    }
}

private extension ExcelMathOperator {
    func toMathOperator(_ e: ExcelExpression) -> MathsOperation {
        switch self {
        case .add: return .add(e)
        case .subtract: return .subtract(e)
        case .multiply: return .multiply(e)
        case .divide: return .divide(e)
        case .power: return .power(e)
        }
    }
    
    var precedence: Int {
        switch self {
        case .add: return 1
        case .subtract: return 1
        case .divide: return 2
        case .multiply: return 2
        case .power: return 3
        }
    }
}
