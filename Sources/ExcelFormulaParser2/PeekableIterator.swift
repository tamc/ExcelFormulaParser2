import Foundation

/**
 Wraps an iterator, adding a method 'peek' that allows you to look ahead to the next value.
 */
struct PeekableIterator<Element>: IteratorProtocol {
    private var i: AnyIterator<Element>
    private var peeked: Element? = nil
    private var isPeeked = false
    private var isFinished = false
    
    init<I: IteratorProtocol>(_ base: I) where I.Element == Element {
        self.i = AnyIterator(base)
    }
    
    mutating func next() -> Element? {
        if isPeeked {
            isPeeked = false
            return peeked
        }
        if isFinished {
            return nil
        }
        return i.next()
    }
    
    mutating func peek() -> Element? {
        if isPeeked == false {
            peeked = i.next()
            isPeeked = true
            isFinished = (peeked == nil)
        }
        return peeked
    }
}
