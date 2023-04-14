class RRIP<Key: Hashable, Value> {
  typealias Slot = (key: Key, value: Value, absoluteRingIndex: Int)
  private var ring: RingBuffer<LinkedList<Slot>>
  private var dict = [Key: LinkedList<Slot>.Node]()
  private let capacity: Int

  init(capacity: Int, predictionIntervals: Int = 4) {
    precondition(predictionIntervals > 0)
    precondition(capacity > 0)
    self.capacity = capacity
    self.ring = RingBuffer(repeating: .init(), count: predictionIntervals)
  }

  func fetch(
    key: Key,
    default defaultValue: @autoclosure () -> Value,
    reuseProbability: Double = 0.1
  ) -> Value {
    if let node = dict[key] {
      let index = ring.index(forAbsoluteIndex: node.value.absoluteRingIndex)

      // Change the re-reference prediction interval when a key is hit
      if index < ring.count - 1 {
        ring[index].remove(node)

        ring[index + 1].enqueue(node) // frequency priority
        // ring[ring.count - 1].enqueue(node) // hit priority
      }
      
      return node.value.value
    }

    precondition((0.0...1.0).contains(reuseProbability))
    let index = Int((reuseProbability * Double(ring.count - 1)).rounded()) + 1
    let value = defaultValue()
    dict[key] = ring[index].enqueue((key, value, ring.absoluteIndex(for: index)))

    while dict.count > capacity {
      if let evicted = ring[0].dequeue() {
        dict.removeValue(forKey: evicted.key)
      } else { ring.rotate() }
    }

    return value
  }
}
