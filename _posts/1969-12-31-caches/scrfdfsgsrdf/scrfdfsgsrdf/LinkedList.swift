struct LinkedList<T> {
  class Node {
    let value: T
    fileprivate var next: Node?
    fileprivate weak var prev: Node?
    init(value: T) { self.value = value }
  }
  private var head: Node?
  private var tail: Node?

  @discardableResult mutating func enqueue(_ element: T) -> Node {
    let newNode = Node(value: element)
    enqueue(newNode)
    return newNode
  }

  mutating func enqueue(_ newNode: Node) {
    if tail != nil {
      tail?.next = newNode
      newNode.prev = tail
    } else {
      head = newNode
    }
    tail = newNode
  }

  @discardableResult mutating func remove(_ node: Node) -> Node {
    if head === node && tail === node {
      assert(node.next == nil && node.prev == nil)
      head = nil
      tail = nil
      return node
    } else if head === node {
      assert(node.prev == nil && node.next != nil)
      head = node.next
      node.next?.prev = nil
      node.next = nil
      return node
    } else if tail === node {
      assert(node.next == nil && node.prev != nil)
      tail = node.prev
      node.prev?.next = nil
      node.prev = nil
      return node
    } else {
      assert(node.next != nil && node.prev != nil)
      node.prev?.next = node.next
      node.next?.prev = node.prev
      node.next = nil
      node.prev = nil
      return node
    }
  }

  mutating func dequeue() -> T? {
    guard let currentHead = head else {
      return nil
    }
    return remove(currentHead).value
  }
}
