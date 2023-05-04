---
layout: post
title: Caches Make Predictions About the Future
excerpt: "How a paper about CPU caches changed the way I think about software caches too"
showtitle: false
---

It's funny how hardware and software are able to solve the same problems in dramatically different ways. Want to add a 2-bit counter to every slot in your cache, then find the first slot with a counter value of `3`—incrementing them all in parallel until a suitable slot is found—in sub-linear cycle time? Sure, why not? It's just transistors! They excel at doing a bunch of stuff in parallel, it's just die space and power![^141]

Of course the "2-bit counter per cache slot" thing isn't a random example, Intel _actually does this_[^bits] in their <abbr title="Last-Level Cache">LLC</abbr>. They even [published a paper about it](Jaleel - 2010 - High Performance Cache Replacement Using Re-Reference Interval Prediction (RRIP).pdf) and the benchmark results are pretty solid: a hit rate 6-10% better than <abbr title="Least Recently Used">LRU</abbr>. But the paper also offers a deeper understanding of caching as a concept.

## What's a Cache?

A cache is a place to store things you've used in case you need them again later. It's too small to fit everything, and can't tell the future, so it uses an eviction policy—like "least recently used" or "least frequently used"—to decide what stays in the cache and what doesn't in the hope of maximizing cache performance, which is measured by the ratio of "hits" to "misses". These policies are bets on future access patterns, and historically they've been pretty simple.

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

On a "miss", a node is evicted from the <span style="font-family: 'Museo';">head</span> of the list and the new value is inserted at the <span style="font-family: 'Museo';">tail</span>. On a "hit", the value's node is moved to the <span style="font-family: 'Museo';">tail</span>. This way the unused contents of the list always drift toward the <span style="font-family: 'Museo';">head</span>, "aged out" by the insertion (or movement) of newer (hotter) values to the <span style="font-family: 'Museo';">tail</span>.

Conceptually, the two ends of the list represent _re-reference predictions_: values near the <span style="font-family: 'Museo';">tail</span> are expected to be reused in the _near-immediate_ future, while values near the <span style="font-family: 'Museo';">head</span> are more _distant_.

## Supporting Better Predictions

The <abbr title="Re-Reference Interval Prediction">RRIP</abbr> paper asks: what if caches supported re-reference prediction intervals more nuanced than _near-immediate_ and _distant_? It conceptualizes intermediate predictions as inserting a value somewhere in the middle[^middle] of the list, and those 2-bit counters are how they implement it in hardware.

Building on this, they propose an eviction policy called <abbr title="Static RRIP">SRRIP</abbr> that bets values are not actually likely to be re-referenced unless they have been hit in the past, accomplishing this by inserting new values near (but not at!) the <span style="font-family: 'Museo';">head</span> of the list and promoting them towards[^priority] the <span style="font-family: 'Museo';">tail</span> when they're hit. Another variation—<abbr title="Bimodal  RRIP">BRRIP</abbr>—assumes most values will _never_ be reused, occasionally inserting values with a _long_ re-reference interval to provide thrash resistance. Finally, <abbr title="Dynamic  RRIP">DRRIP</abbr> pits the two against each other using set dueling[^dueling].

## In Software

Of course caches are common in software, too—values can be costly to generate, but the system's memory is finite. Per-slot counters aren't practical to implement in code, but the same concept can be expressed by a ring buffer of doubly-linked lists: a value's index in the ring represents its <abbr title="Re-Reference Prediction Value">RRPV</abbr>, and is incremented by rotation. A ring with four indexes provides the same cache insertion points provided by a hardware implementation with 2-bit counters:

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

  "head" [shape="plain", pos="-1.5,0.65!", label="distant"]
  "tail" [shape="plain", pos="-.5,0.95!", label="near-immediate"]
  "head" -> ringbuffer:f3
  "tail" -> ringbuffer:f0

  "short" [shape="plain", pos=".5,0.65!", label="short"]
  "long" [shape="plain", pos="1.5,0.65!", label="long"]
  "short" -> ringbuffer:f1
  "long" -> ringbuffer:f2
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

You'd want to integrate a <abbr title="Look-up Table">LUT</abbr>[^lookup-time] to make the above code production-ready, but there's no need to stop there! Computer hardware is general purpose, but software specializes—and RRIPs make even more sophisticated cache policies possible.

## Domain-Specific Optimization

More granular re-reference intervals are a huge opportunity for software with domain-specific knowledge. One example of this is a tree: _every_ operation uses the root node but a random leaf's probability of participating in a random search is ¹⁄ₙ, a perfect application for RRIP!

Also note that a _distant_ re-reference prediction inserts new entries _directly into the drain_, preventing the occasional rotation of the ring buffer that ages out cache entries with shorter RRPVs[^drain-insertion]. This behaviour can be useful for scanning or thrashing workloads, as recognized by the BRRIP policy, and software can take advantage of it in unique ways—to reuse the tree example, code implementing a <abbr title="Depth-First Search">DFS</abbr> _knows_ that it will be accessing every node in the tree. By using a _distant_ re-reference prediction for misses and abstaining from modifying non-<em>distant</em> RRPVs on hits, the traversal can preserve pre-existing entries[^nodrain] for the next operation while also warming the cache if it's not already at capacity.

## Bringing it to the Real World

While writing this post I also wrote a working cache implementation in Swift that supports custom RRIP policies and custom reuse probabilities. I've published it as a [Swift package](https://github.com/numist/swift-cache/), and [proposed bringing it into Foundation]().

[^141]: I'm being glib here, _of course_ there's a limit. In college two friends and I managed to design an application-specific CPU that included an instruction so complex that Xilinx reported the theoretical maximum clock speed would have been below 5MHz.
[^bits]: Well, they're probably using at least 3 bits per counter.
[^middle]: Specifically, an _m_-bit counter gives you _2<sup>m</sup>_ distinct insertion points into the cache—_m=1_ is just LRU again.
[^priority]: SRRIP has two distinct behaviours here, _Hit Priority_ (which is analogous to LRU) and _Frequency Priority_ (LFU).
[^dueling]: Which Intel [_also_ had a hand in inventing](Qureshi - 2007 - Adaptive Insertion Policies for High Performance Caching.pdf).
[^drain-insertion]: The behaviour of inserting directly into the drain differs significantly between the hardware and software implementations; each linked list is a mini-LRU but Intel's LLC will "search for first ‘3’ from left", overwriting the same slot repeatedly even when the cache has empty slots. Hence, "RRIP always inserts new blocks with a _long_ re-reference interval".
[^nodrain]: Everything that wasn't _distant_, anyway.
[^lookup-time]: So `node(for:)` can run in sub-linear time.