---
layout: post
title: Caches Make Predictions About the Future
excerpt: "How a paper about CPU caches changed the way I think about software caches too"
showtitle: false
---

It's funny how hardware and software are able to solve the same problems in dramatically different ways. Want to add a 2-bit counter to every slot in your cache, then find the first slot with a counter value of `3`—incrementing them all in parallel until a suitable slot is found—in bounded time? Sure, why not! It's just transistors! They excel at doing a bunch of stuff in parallel, it's just die space and power![^141]

Of course the "2-bit counter per cache slot" thing isn't a random example, Intel _actually does this_[^bits] in their <abbr title="Last-Level Cache">LLC</abbr>. They even [published a paper about it](Jaleel - 2010 - High Performance Cache Replacement Using Re-Reference Interval Prediction (RRIP).pdf) and the benchmark results are pretty solid: a hit rate 6-10% better than <abbr title="Least Recently Used">LRU</abbr>. But the paper also offers a deeper understanding of caching as a concept.

## What's a Cache?

A cache is a place to store things you've used in case you need them again. It's always too small, and can't tell the future, so it uses an eviction policy—like "least recently used" or "least frequently used"—to decide what stays in the cache and what doesn't in the hope of maximizing cache performance, which is measured by the ratio of "hits" to "misses". Each of these policies is a bet on future access patterns, and historically they've been pretty simple.

The most common is LRU, which bets on temporal locality. It can be implemented with a doubly-linked list:

{% graphviz %}
digraph LRU {
  layout="neato"
  "head" [shape="plain", pos="0,0.75!"]
  "tail" [shape="plain", pos="3,0.75!"]
  "A" [pos="0,0!", shape="circle"]
  "B" [pos="1,0!", shape="circle"]
  "C" [pos="2,0!", shape="circle"]
  "D" [pos="3,0!", shape="circle"]
  "head" -> "A" -> "B" -> "C" -> "D"
  "tail" -> "D"
  "D" -> "C" -> "B" -> "A" [style="dashed"]
}
{% endgraphviz %}

On a "miss" a node is evicted from the <span style="font-family: 'Museo';">head</span> of the list and the new value is inserted at the <span style="font-family: 'Museo';">tail</span>. On a "hit" the value's node is moved to the <span style="font-family: 'Museo';">tail</span>. This way the unused contents of the list always drift toward the <span style="font-family: 'Museo';">head</span>, "aged out" by the insertion (or movement) of newer (hotter) values to the <span style="font-family: 'Museo';">tail</span>.

The two ends of the list represent _re-reference predictions_: values near the <span style="font-family: 'Museo';">tail</span> are expected to be reused in the _near-immediate_ time frame while values near the <span style="font-family: 'Museo';">head</span> are more _distant_.

## Supporting Better Predictions

The <abbr title="Re-Reference Interval Prediction">RRIP</abbr> paper asks: what if caches supported re-reference predictions more nuanced than _near-immediate_ and _distant_? It conceptualizes intermediate predictions as inserting a value somewhere in the middle[^middle] of the list, and those 2-bit counters are how they implement it in hardware.

Building on this, they propose an eviction policy called <abbr title="Static RRIP">SRRIP</abbr> that bets values are not actually likely to be re-referenced unless they have been hit in the past, accomplishing this by inserting new values near (but not at!) the <span style="font-family: 'Museo';">head</span> of the list and promoting them towards the <span style="font-family: 'Museo';">tail</span>[^priority] when they're hit. Another variation—<abbr title="Bimodal  RRIP">BRRIP</abbr>—assumes values will never be reused, occasionally assuming a _long_ re-reference interval to provide thrash resistance. Finally, <abbr title="Dynamic  RRIP">DRRIP</abbr> ties the two together using set dueling.

## In Software

Of course caches are common in software, too: values can be costly to generate, but the system's memory is finite. Managing per-slot counters in software would be pretty heinous, but the same idea can be expressed by a ring buffer of doubly-linked lists—the value's ring index represents its RRPV and is incremented by rotation:

{% graphviz %}
digraph RRIP {
  layout="neato"
  ringbuffer [pos="0,0!", shape=record, fontsize=14, width=4, fixedsize=true, label="<f3> 3 | <f0> 0 | <f1> 1 | <f2> 2"]
  "A" [pos="-1.5,-1!", shape=circle, label="A"]
  "B" [pos="1.5,-1!", shape=circle, label="B"]
  "C" [pos="1.5,-2!", shape=circle, label="C"]
  "D" [pos="-.5,-1!", shape=circle, label="D"]
  ringbuffer:f3 -> "A"
  ringbuffer:f2 -> "B" -> "C"
  "C" -> "B" [style="dashed"]
  ringbuffer:f0 -> "D"
}
{% endgraphviz %}

In use:

``` swift
public func fetch(
  _ key: Key,
  orInsert generator: @autoclosure () -> Value
) -> Value {
  let value: Value
  if let node = self.node(for: key) {
    value = node.value
    // Hit Priority: update prediction of hits to "near-immediate"
    node.remove()
    self.ring[0].append(node)
  } else {
    value = generator()
    // SRRIP: initial prediction is "long"
    self.ring[2].append(.init(key: key, value: value))
    self.count += 1
  }

  while self.count > self.capacity {
    // Evict a value with an RRPV of "distant", aging the ring as needed
    if let e = self.ring[3].head {
      e.remove()
      self.count -= 1
    } else { self.ring.rotate(by: -1) }
  }

  return value
}
```

The above is simplified for purpose of illustration, though incorporating a hash table[^lookup-time] would make it production-ready. But RRIPs in software have potential beyond naïve cache performance improvements—computer hardware is general purpose, but software specializes.

## Domain-Specific Optimization

More granular re-reference intervals are a huge opportunity for software with domain-specific knowledge. One example of this is a tree: _every_ operation uses the root node but a random leaf's probability of participating in a random search is ¹⁄ₙ, a perfect application for RRIP!

Also note that a _distant_ re-reference prediction inserts new entries _directly into the drain_, preventing the occasional rotation of the ring buffer that ages out cache entries with shorter RRPVs[^drain-insertion]. This behaviour seems like a pitfall at first glance, but it can be useful for operations that knowingly scan or thrash—to reuse the tree example, code implementing a <abbr title="Depth-First Search">DFS</abbr> _knows_ that it will be accessing every node in the tree and can use a _distant_ re-reference prediction on cache misses (and abstain from modifying RRPVs on cache hits) to preserve pre-existing entries[^nodrain]. This lets scanning operations warm the cache without destroying any existing predictions.

<!--
## Bringing it to the Real World

I wrote a working cache implementation while writing this post, and it's pretty clear that it is capable of standing alone. You can find as a Swift package, and I've proposed integrating it into Foundation.
-->

[^141]: I'm being glib here, _of course_ there's a limit. In college two friends and I managed to design an application-specific CPU with an instruction so complex the theoretical maximum clock speed would have been just north of 4MHz.
[^bits]: Except they're probably using 3-bit counters.
[^middle]: Specifically, an _m_-bit counter gives you _2<sup>m</sup>_ distinct insertion points into the cache.
[^priority]: SRRIP has two distinct behaviours here: _hit priority_ (which is analogous to LRU) and _frequency priority_ (LFU)
[^drain-insertion]: The behaviour of inserting directly into the drain differs significantly between the hardware and software implementations; each linked list is a mini-LRU but Intel's LLC will "search for first ‘3’ from left", overwriting the same slot repeatedly even when the cache has empty slots. Hence, "RRIP always inserts new blocks with a _long_ re-reference interval".
[^nodrain]: Everything with an age-adjusted RRPV sooner than _distant_, anyway.
[^lookup-time]: So `node(for:)` can run in sub-linear time.