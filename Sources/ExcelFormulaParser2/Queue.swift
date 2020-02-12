import Foundation

struct Queue<T>: Sequence, IteratorProtocol {
    private var first: QueuedItem<T>?
    private var last: QueuedItem<T>?
    
    mutating func next() -> T? {
        guard let f = first else { return nil }
        first = f.next
        return f.item
    }
    
    mutating func append(_ item: T) {
        let q = QueuedItem(item)
        if let l = last {
            l.next = q
        } else {
            first = q
        }
        last = q
    }
}

private class QueuedItem<T> {
    let item: T
    var next: QueuedItem<T>?
    
    init(_ item: T) {
        self.item = item
    }
}
