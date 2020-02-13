import Foundation

struct Queue<T>: Sequence, IteratorProtocol {
    var first: QueuedItem<T>?
    var last: QueuedItem<T>?
    
    var count: Int = 0
    var isEmpty: Bool { return count == 0 }
    
    func peekFirst() -> T? {
        guard let f = first else { return nil }
        return f.item
    }
    
    func peekLast() -> T? {
        guard let l = last else { return nil }
        return l.item
    }
    
    mutating func next() -> T? {
        guard let f = first else { return nil }
        count -= 1
        if count == 0 {
            first = nil
            last = nil
        } else {
            first = f.next
        }
        return f.item
    }
    
    mutating func append(_ item: T) {
        count += 1
        let q = QueuedItem(item)
        if let l = last {
            l.next = q
        } else {
            first = q
        }
        last = q
    }
}

class QueuedItem<T> {
    let item: T
    var next: QueuedItem<T>?
    
    init(_ item: T) {
        self.item = item
    }
}
