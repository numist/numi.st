---
layout: page
title: Re-Reference Interval Prediction
excerpt: "How a paper about CPU caches changed the way I think about software caches too"
---

It's funny how hardware and software are able to solve the same problems in dramatically different ways. Want to add a 2-bit counter to every slot in your cache, then find the first slot with a counter value of `3`—incrementing them all at once until a suitable slot is found—in bounded time? Sure, why not! It's just transistors! They excel at doing a bunch of stuff in parallel, it's all just die space and power![^141]

The "2-bit counter per cache slot" thing isn't a random example, Intel _actually does this_ in their <abbr title="Last-Level Cache">LLC</abbr>. They even [published a paper about it](Jaleel - 2010 - High Performance Cache Replacement Using Re-Reference Interval Prediction (RRIP).pdf) and the benchmark results are pretty solid: a hit rate 6-10% better than <abbr title="Least Recently Used">LRU</abbr>. But the paper also offers a deeper understanding of caching.

## What's a Cache?

Backing up for a moment, a cache is a place to store things you've used in case you need them again, but it's always too small and can't tell the future so it uses an eviction policy like "least recently used" or "least frequently used" to decide what stays in the cache and what doesn't in the hope of maximizing cache performance, which is measured by its "hit rate". Each of these eviction policies has some bias that tends to be obvious from its name.

An LRU, with its bias toward recency of use, can be implemented as a linked list of slots. On a "miss" a slot is evicted from the front of the list to make space for the new value's slot, which is appended to the end. On a cache "hit" the existing value's slot is moved to the end of the list. This way the overall contents of the list always gradually move toward the front, pushed in that direction by hot values being moved (or inserted) at the end.

```
TODO: some graphviz stuff here that people can interact with
```

## Making Better Predictions

The <abbr title="Re-Reference Interval Prediction">RRIP</abbr> paper asks: what if caches made reuse predictions more nuanced than "immediately" and "never"? It conceptualizes intermediate predictions as inserting a value somewhere in the middle[^middle] of the list, and those 2-bit counters are how they do it.

Based on this concept, they propose an eviction policy called <abbr title="Static RRIP">SRRIP</abbr> that predicts entries are not very likely to be re-referenced _unless they have been reused in the past_, accomplishing this by inserting new values near the front of the list and promoting them towards the end when they're hit. Another variation adds some randomization to the insertion position of new values in an effort to provide thrash resistance.

## In Software

Of course caches are commonly found in software, too. Some things are costly to compute on demand, but the system's memory can't store the result of every computation. As a twist, sometimes software has domain-specific knowledge that helps it make better-informed re-reference interval predictions. One example of this is a tree: _every_ operation uses the root node, but a random leaf's probability of participating in a search is ¹⁄ₙ—a perfect application for an RRIP cache!

Managing a counter per slot in software would be pretty heinous, but the same concept can be expressed by using a ring buffer of linked lists:

``` swift
class RRIP<Key: Hashable, Value> {
  enum RRP {
    case immediate, long, never, p(Double)

    func quantized(to count: Int) -> Int {
      switch self {
      // The Re-Reference Prediction Values are inverted from the paper
      // for ease of implementation. Larger values are expected to be
      // re-referenced sooner.
      case .immediate: return count - 1
      case .long: return 1
      case .never: return 0
      // Probabilities are rounded up so only `0.0` will map to `.never`
      case .p(let p):
        precondition(0.0 <= p && p <= 1.0)
        return Int((p * Double(count - 1)).rounded(.up))
      }
    }
  }

  typealias KeyValue = (key: Key, value: Value)
  private var ring: RingBuffer<LinkedList<KeyValue>>
  private var dict = [Key: LinkedList<KeyValue>.Node]()
  private let capacity: Int
  var count: Int { dict.count }

  init(capacity: Int, predictionIntervals: Int = 4) {
    precondition(predictionIntervals >= 4)
    precondition(capacity > 0)
    self.capacity = capacity
    self.ring = RingBuffer(repeating: .init(), count: predictionIntervals)
  }

  func fetch(
    _ key: Key,
    default defaultValue: @autoclosure () -> Value,
    onMiss: RRP = .long, onHit: RRP? = .immediate
  ) -> Value {
    let value: Value
    let rrp: RRP
    if let node = dict[key] {
      guard let onHit else { return node.payload.value }
      value = node.list!.remove(node).value
      rrp = onHit
    } else {
      value = defaultValue()
      rrp = onMiss
    }

    dict[key] = ring[rrp.quantized(to: ring.count)].enqueue((key, value))

    while count > capacity {
      if let evicted = ring[0].dequeue() {
        dict.removeValue(forKey: evicted.key)
      } else { ring.rotate() }
    }

    return value
  }
}
```

TODO: References to custom types in the code above link to their implementation.

Note that `.never` inserts entries _directly into the drain_, preventing the occasional rotation of the ring buffer that "ages out" cache entries with shorter RRPVs. This behaviour can be useful when the cache is being used by an operation known to scan or thrash: using `fetch(key, default: foo(), onMiss: .never, onHit: nil)` causes the cache to maintain pre-existent entries[^nodrain] and their RRPVs.

[^141]: I'm being glib here, _of course_ there's a limit. In college two friends and I managed to design an application-specific CPU with an instruction so complex the theoretical maximum clock speed would have been just north of 4MHz.
[^middle]: In the paper, an _m_-bit counter gives you _2<sup>m</sup>_ distinct insertion points into the cache.
[^nodrain]: Everything with an RRPV sooner than `.never`.