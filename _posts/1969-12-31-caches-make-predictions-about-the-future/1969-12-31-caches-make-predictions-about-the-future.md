---
layout: post
title: Caches Make Predictions About the Future
excerpt: "How a paper about CPU caches changed the way I think about software caches too"
showtitle: false
---

It's funny how hardware and software are able to solve the same problems in dramatically different ways. Want to add a 2-bit counter to every slot in your cache, then find the first slot with a counter value of `3`—incrementing them all in parallel until a suitable slot is found—in sub-linear cycle time? Sure, why not? It's just transistors! They excel at doing a bunch of stuff in parallel, it's just die space and power![^141]

Of course the "2-bit counter per cache slot" thing isn't a random example, Intel _actually does this_[^bits] in their <abbr title="Last-Level Cache">LLC</abbr>. They even [published a paper about it](Jaleel - 2010 - High Performance Cache Replacement Using Re-Reference Interval Prediction (RRIP).pdf), and the benchmark results are pretty solid: a fairly consistent hit rate improvement of 6-10% over <abbr title="Least Recently Used">LRU</abbr>. But the paper also offers a deeper understanding of caching as a concept.

## What's a Cache?

A cache is a place to store things you've used in case you need them again later. It's too small to fit everything and can't tell the future, so it uses an eviction policy—like "least recently used" or "least frequently used"—to decide what stays in the cache and what doesn't in the hope of maximizing cache performance, which is measured by the ratio of "hits" to "misses". These policies are bets on future access patterns, and historically they've been pretty simple.

One of the oldest policies is LRU, which bets on temporal locality. It can be implemented with a doubly-linked list:

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

On a "miss", a node is evicted from the <span style="font-family: 'Museo';">head</span> of the list and the new value is inserted at the <span style="font-family: 'Museo';">tail</span>. On a "hit", the value's node is moved to the <span style="font-family: 'Museo';">tail</span>. Unused values drift toward the <span style="font-family: 'Museo';">head</span>, "aged out" by the insertion (or movement) of newer (hotter) values to the <span style="font-family: 'Museo';">tail</span>.

Conceptually, the two ends of this list represent _re-reference predictions_: values near the <span style="font-family: 'Museo';">tail</span> are expected to be reused in the _near-immediate_[^parlance] future, while values near the <span style="font-family: 'Museo';">head</span> will be more _distant_.

## Supporting Better Predictions

The <abbr title="Re-Reference Interval Prediction">RRIP</abbr> paper asks: what if caches supported re-reference interval predictions more nuanced than _near-immediate_ and _distant_? It conceptualizes intermediate predictions as inserting a value somewhere in the middle[^middle] of the list, and those counters are how they implement it in hardware.

Building on this, they propose an eviction policy called <abbr title="Static RRIP">SRRIP</abbr> that bets values are not actually likely to be re-referenced unless they have been hit in the past, accomplishing this by inserting new values near (but not at!) the <span style="font-family: 'Museo';">head</span> of the list and promoting them towards[^priority] the <span style="font-family: 'Museo';">tail</span> when they're hit. Another variation—<abbr title="Bimodal  RRIP">BRRIP</abbr>—provides thrash resistance by assuming cold values will be reused in the _distant_ future, with the occasional random _long_ re-reference interval prediction thrown in. Finally, <abbr title="Dynamic  RRIP">DRRIP</abbr> pits the two against each other using set dueling[^dueling].

## In Software

Of course caches are common in software, too—values can be costly to generate, but the system's memory is finite. Per-slot counters aren't practical to implement in code, but the same concept can be expressed by a ring buffer of doubly-linked lists: a value's index in the ring represents its <abbr title="Re-Reference Prediction Value">RRPV</abbr>, and is incremented by rotation. A ring with four indexes provides the same cache insertion points as a hardware implementation using 2-bit counters:

{% graphviz %}
digraph RRIP {
  layout="neato"
  ringbuffer [pos="0,0!", shape=record, width=4, label="<f3> 3 | <f0> 0 | <f1> 1 | <f2> 2"]
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
public func value(
  forKey key: Key, orInsert generator: () throws -> Value
) rethrows -> Value {
  let value: Value
  if let node = self.node(forKey: key) {
    value = node.value
    // Hit Priority: update prediction of hits to "near-immediate"
    node.remove()
    self.ring[0].append(node)
  } else {
    value = try generator()
    // SRRIP: initial prediction is "long"
    self.ring[2].append(Node(key: key, value: value))
    self.count += 1
  }

  while self.count > self.capacity {
    // Evict a value with "distant" RRPV, aging as needed by rotating the ring
    if let node = self.ring[3].head {
      node.remove()
      self.count -= 1
    } else { self.ring.rotate(by: -1) }
  }

  return value
}
```

You'd want to integrate a <abbr title="Look-up Table">LUT</abbr>[^lookup-time] to make the above code production-ready, but there's no need to stop there! Computer hardware is general purpose, but software specializes—and RRIPs make even more sophisticated cache policies possible.

## Domain-Specific Optimization

Being able to make more granular predictions about the future is a huge opportunity for software with domain-specific knowledge. One example of this is a tree: _every_ operation uses the root node, but a random leaf's probability of participating in a random search is ¹⁄ₙ—a perfect application for RRIP!

Also note that a _distant_ re-reference prediction inserts entries _directly into the drain_, preventing the occasional rotation of the ring buffer that ages out cache entries with shorter RRPVs. Software that includes thrashing operations can take advantage of this knowledge to apply a _BRRIP_-style policy to them, allowing for even better performance than set dueling.

[^141]: I'm being glib here, _of course_ there's a limit. In college two friends and I managed to design an application-specific CPU that included an instruction so complex that Xilinx reported the theoretical maximum clock speed would have been below 5MHz.
[^bits]: Well, they're probably using at least 3 bits per counter.
[^parlance]: In the parlance of the paper.
[^middle]: Specifically, an _m_-bit counter gives you _2<sup>m</sup>_ distinct insertion points into the cache—_m=1_ is just LRU again.
[^priority]: SRRIP has two distinct behaviours here, _Hit Priority_ (which is analogous to LRU) and _Frequency Priority_ (LFU).
[^dueling]: Which Intel [_also_ had a hand in inventing](Qureshi - 2007 - Adaptive Insertion Policies for High Performance Caching.pdf)!
[^lookup-time]: So `node(for:)` can run in sub-linear time.
