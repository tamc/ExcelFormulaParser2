import Foundation

public enum ExcelExpression: Hashable {
    case empty
    case string(String)
    case error(ExcelError)
    case number(Decimal)
    case boolean(Bool)
    indirect case brackets(ExcelExpression)
    indirect case function(name: String, arguments: [ExcelExpression] = [])
    indirect case comparison(ExcelComparison, ExcelExpression, ExcelExpression)
    indirect case maths([MathsOperation])
    indirect case intersection(ExcelExpression, ExcelExpression)
    /// Union in Excel terminology is NOT the same as a Set union, because dulicates are _not_ eliminated
    indirect case union([ExcelExpression])
    indirect case textJoin(ExcelExpression, ExcelExpression)
    case ref(String)
    indirect case range(ExcelExpression, ExcelExpression)
    indirect case sheet(ExcelExpression, ExcelExpression)
    indirect case structured(ExcelExpression)
    indirect case table(String, ExcelExpression)

}

public enum MathsOperation: Hashable {
    case start(ExcelExpression)
    case add(ExcelExpression)
    case subtract(ExcelExpression)
    case multiply(ExcelExpression)
    case divide(ExcelExpression)
    case power(ExcelExpression)
    case percent(ExcelExpression)
}

public struct Parser {
    private var tokens: PeekableIterator<ExcelToken>
    
    init<S: IteratorProtocol>(_ tokens: S) where S.Element == ExcelToken {
        self.tokens = PeekableIterator(tokens)
    }
    
    mutating func result() -> ExcelExpression? {
        var firstExpression = parseNextToken()
        if firstExpression == nil {
            guard tokens.peek() == .symbol(.maths(.subtract)) else { return nil }
            _ = tokens.next()
            guard let e = parseNextToken() else { return nil }
            firstExpression = .maths([.subtract(e)])
        }
        guard var parsed = firstExpression else {
            return nil
        }
        while let next = parseJoin(left: parsed) {
            parsed = next
        }
        return parsed
    }
    
    
    mutating private func parseJoin(left: ExcelExpression) -> ExcelExpression? {
        guard let next = tokens.peek() else { return nil }
        if next == .symbol(.colon) {
            return parseRange(left)
        }
        if next.isExcelMathOperator {
            return parseOperator(left)
        }
        if next == .symbol(.ampersand) {
            return parseTextJoin(left)
        }
        if next == .symbol(.percent) {
            _ = tokens.next()
            return .maths([.percent(left)])
        }
        if next.isExcelComparison {
            return parseComparison(left)
        }
        return parseIntersection(left)
    }
    
    mutating private func parseNextToken() -> ExcelExpression? {
        guard let token = tokens.peek() else { return nil }
        switch token {
        case .literal(let s):
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
    
                return .function(name: String(s), arguments: arguments)
            }
            
            if case .symbol(.bang) = tokens.peek() {
                _ = tokens.next()
                guard let ref = parseNextToken() else {
                    fatalError("! with nothing after")
                }
                return .sheet(.ref(String(s)), ref)
            }
            
            if case .symbol(.open(.squareBracket)) = tokens.peek() {
                guard let ref = parseNextToken() else {
                    fatalError("Non parsable structured table ref?")
                }
                return .table(String(s), ref)
            }

            return .ref(String(s))

        case .string(let s):
            _ = tokens.next()
            return .string(String(s))
            
        case .error(let e):
            _ = tokens.next()
            return .error(e)
            
        case .number(let n):
            _ = tokens.next()
            return .number(n)
            
        case .symbol(let s):
            switch s {
            case .close:
                return nil
                
            case .maths(.subtract):
                if case let .number(n) = tokens.peekFurther() {
                    _ = tokens.next()
                    _ = tokens.next()
                    return .number(-n)
                }
                return nil
                
            case .open(.bracket):
                _ = tokens.next()
                let e = result() ?? .empty
                if tokens.next() != .symbol(.close(.bracket)) {
                    fatalError("Brackets not closed")
                }
                return .brackets(e)
                
            case .open(.squareBracket):
                _ = tokens.next()
                let list = parseList(separator: .symbol(.comma), close: .symbol(.close(.squareBracket)))
                if list.count == 1 {
                    return .structured(list.first!)
                }
                return .structured(.union(list))
                
                
            default:
                return nil

            }
        }
    }
    
    mutating private func parseList(separator: ExcelToken, close: ExcelToken) -> [ExcelExpression] {
        var parsedExpression = false
        var list = [ExcelExpression]()
        while true {
            guard let token = tokens.peek() else { return list }
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
                    return list
                }
                // e.g, (,) == [.empty, .empty]
                if parsedExpression == false {
                    list.append(.empty)
                }
                return list
            }
            
            if let subExpression = result() {
                list.append(subExpression)
                parsedExpression = true
            }
        }
    }
    
    mutating private func parseOperator(_ left: ExcelExpression) -> ExcelExpression {
        var list: [MathsOperation] = [.start(left)]
        
        let precedence = tokens.peek()!.precedence
        
        guard var firstOp = tokens.next()?.excelMathOperator else {
            fatalError("Missing the first operator")
        }
        
        while true {
            guard var right = parseNextToken() else {
                fatalError("Missing the right hand side")
            }
            
            if let nextPrecedence = tokens.peek()?.precedence {
                if nextPrecedence > precedence {
                    right = parseJoin(left: right) ?? right
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
        return .maths(list)
    }
    
    mutating private func parseComparison(_ left: ExcelExpression) -> ExcelExpression {
        
        let precedence = tokens.peek()!.precedence
        
        guard let comp = tokens.next()?.excelComparison else {
            fatalError("Missing the comparison operator")
        }
    
        guard var right = parseNextToken() else {
            fatalError("Missing the right hand side")
        }
            
        if let nextPrecedence = tokens.peek()?.precedence {
            if nextPrecedence > precedence {
                right = parseJoin(left: right) ?? right
            }
        }
        
        return .comparison(comp, left, right)
    }
    
    mutating private func parseRange(_ left: ExcelExpression) -> ExcelExpression {
        _ = tokens.next()
        guard let right = parseNextToken() else {
            fatalError("No right hand side to colon")
        }
        return .range(left, right)
    }
    
    mutating private func parseIntersection(_ left: ExcelExpression) -> ExcelExpression? {
        guard let right = result() else { return nil }
        return .intersection(left, right)
    }
    
    mutating private func parseTextJoin(_ left: ExcelExpression) -> ExcelExpression {
        _ = tokens.next()
        guard let right = result() else {
            fatalError("No right hand side to ampersand for text join")
        }
        return .textJoin(left, right)
    }
}

private extension ExcelToken {
    var precedence: Int {
        switch self {
        case .symbol(let s):
            return s.precedence
        default:
            return 0
        }
    }
}

private extension ExcelSymbol {
    var precedence: Int {
        switch self {
        case .bang:
            return 2000
        case .open:
            return 1000
        case .close:
            return 1000
        case .comma:
            return 500
        case .colon:
            return 400
        case .percent:
            return 100
        case .maths(let m):
            return m.precedence
        case .ampersand:
            return 1
        case .comparison:
            return 0
        }
    }
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

private extension ExcelToken {
    var excelComparison: ExcelComparison? {
        guard case let .symbol(.comparison(result)) = self else { return nil }
        return result
    }
        
    var isExcelComparison: Bool {
        return (excelComparison != nil)
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
        case .add: return 10
        case .subtract: return 10
        case .divide: return 20
        case .multiply: return 20
        case .power: return 30
        }
    }
}
