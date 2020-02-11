import Foundation

/**
 Wraps an iterator, adding a method 'peek' that allows you to look ahead to the next value.
 */
struct PeekableIterator<Element>: IteratorProtocol {
    private var i: AnyIterator<Element>
    private var peeked = Queue<Element>()
    private var finished: Bool = false
    
    init<I: IteratorProtocol>(_ base: I) where I.Element == Element {
        self.i = AnyIterator(base)
    }
    
    mutating func next() -> Element? {
        if let p = peeked.next() { return p }
        if finished { return nil }
        return i.next()
    }
    
    mutating func peek() -> Element? {
        guard let n = i.next() else {
            finished = true
            return nil
        }
        peeked.append(n)
        return n
    }
}
