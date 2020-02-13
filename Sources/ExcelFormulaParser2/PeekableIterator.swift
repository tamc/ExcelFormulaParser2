import Foundation

/**
 Wraps an iterator, adding a method 'peek' that allows you to look ahead to the next value.
 */
struct PeekableIterator<Element>: IteratorProtocol {
    private var i: AnyIterator<Element>
    private var peeked = Queue<Element>()
    private var isFinished = false
    
    init<I: IteratorProtocol>(_ base: I) where I.Element == Element {
        self.i = AnyIterator(base)
    }
    
    mutating func next() -> Element? {
        if peeked.isEmpty == false {
            return peeked.next()
        }
        if isFinished {
            return nil
        }
        return i.next()
    }
    
    mutating func peek() -> Element? {
        if peeked.isEmpty, isFinished == false {
            if let n = i.next() {
                peeked.append(n)
            } else {
                isFinished = true
            }
        }
        return peeked.peekFirst()
    }
    
    mutating func peekFurther() -> Element? {
        if peeked.isEmpty {
            _ = peek()
        }
        if peeked.count == 1, isFinished == false {
            if let n = i.next() {
                peeked.append(n)
            } else {
                isFinished = true
            }
        }
        if peeked.count < 2 { return nil }
        return peeked.peekLast()
    }
}
