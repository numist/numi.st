---
layout: page
title: Caches Make Predictions About the Future
excerpt: "How a paper about CPU caches changed the way I think about software caches too"
showtitle: false
image: header.png
---

It's funny how hardware and software are able to solve the same problems in dramatically different ways. Want to add a 2-bit counter to every slot in your cache, then find the first slot with a counter value of `3`—incrementing them all in parallel until a suitable slot is found—in sub-linear time? Sure, why not? It's just transistors! They excel at doing a bunch of stuff in parallel, it's just die space and power![^141]

This "2-bit counter per cache slot" thing isn't a random example—Intel _actually does this_[^bits] in their <abbr title="Last-Level Cache">LLC</abbr>. They even [published a paper about it](Jaleel - 2010 - High Performance Cache Replacement Using Re-Reference Interval Prediction (RRIP).pdf), and it offers a deep understanding of caching as a concept.

## What's a Cache?

You'll often find caches referred to by their eviction policy ("an <abbr title="Least Recently Used">LRU</abbr>"), but that confuses behaviour with purpose. A cache is a place to store things you've used in case you need them again later. It's too small to fit everything and can't tell the future, so it uses its eviction policy in an attempt to maximize the ratio of "hits" to "misses".

Eviction policies are bets on future access patterns, and historically they've been pretty simple. LRU is a bet on temporal locality and can be straightforwardly implemented with a doubly-linked list:

{% graphviz width="296pt" height="100pt" %}
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

On a "miss", a node is evicted from the <span style="font-family: 'Museo';">tail</span> of the list and the new value is inserted at the <span style="font-family: 'Museo';">head</span>. On a "hit", the reused value's node is moved to the <span style="font-family: 'Museo';">head</span>. Unused values drift toward the <span style="font-family: 'Museo';">tail</span>, "aged out" by the insertion (or movement) of newer (hotter) values to the <span style="font-family: 'Museo';">head</span>.

Conceptually, the two ends of this list represent _re-reference interval predictions_[^abbr]: values near the <span style="font-family: 'Museo';">head</span> are expected to be reused in the _near-immediate_[^parlance] future, while values at the <span style="font-family: 'Museo';">tail</span> will probably never be needed again.

## Supporting Better Predictions

With this background, the paper asks: what if caches supported more nuanced re-reference interval predictions? It conceptualizes intermediate predictions as inserting a value somewhere in the middle of the list, and those counters are how they implement it in hardware[^middle].

Building on this, they propose an eviction policy called <abbr title="Static RRIP">SRRIP</abbr> that bets values are not likely to be re-referenced unless they have been hit in the past, accomplishing this by inserting new values near (but not at!) the <span style="font-family: 'Museo';">tail</span> of the list and promoting them towards[^priority] the <span style="font-family: 'Museo';">head</span> when they're hit. Another policy, called <abbr title="Bimodal RRIP">BRRIP</abbr>[^bip], provides thrash resistance by assuming cold values will be reused in the _distant_ future, with an occasional _long_ prediction thrown in. Finally, <abbr title="Dynamic  RRIP">DRRIP</abbr> pits the two against each other using set dueling[^dueling].

## In Software

Of course caches are common in software, too—values can be costly to conjure, but the storage available for them is finite. Per-slot counters aren't practical to implement in code, but the same concept can be expressed by a ring buffer of doubly-linked lists: a value's index in the ring represents its <abbr title="Re-Reference Prediction Value">RRPV</abbr>, and is incremented by rotation when the eviction process finds an empty _distant_ list. A ring with four indexes provides the same cache insertion points as a hardware implementation using 2-bit counters[^short]:

{% graphviz width="280pt" height="234pt" %}
digraph RRIP {
  layout="neato"
  ringbuffer [pos="0,0!", shape=record, width=4, label="<f3> 3 | <f0> 0 | <f1> 1 | <f2> 2"]
  "D" [pos="-1.5,-1!", shape=circle, label="D"]
  "B" [pos="1.5,-1!", shape=circle, label="B"]
  "C" [pos="1.5,-2!", shape=circle, label="C"]
  "A" [pos="-.5,-1!", shape=circle, label="A"]
  ringbuffer:f3 -> "D"
  ringbuffer:f2 -> "B" -> "C"
  "C" -> "B" [style="dashed"]
  ringbuffer:f0 -> "A"

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

Using the above data structure, the following code implements a simplified SRRIP-HP cache:

``` swift
public func value(
  forKey key: Key, orInsert generator: (Key) throws -> Value
) rethrows -> Value {
  let value: Value
  if let node = self.node(forKey: key) {
    value = node.value
    // Hit Priority: update prediction of hits to "near-immediate" (0)
    node.remove()
    self.ring[0].append(node)
  } else {
    value = try generator(key)
    // SRRIP: initial prediction is "long" (2)
    self.ring[2].append(Node(key: key, value: value))
    self.count += 1
  }

  while self.count > self.capacity {
    // Evict a value with "distant" (3) RRPV, rotating the ring as needed
    if let node = self.ring[3].head {
      node.remove()
      self.count -= 1
    } else { self.ring.rotate(by: -1) }
  }

  return value
}
```

You'd want to integrate a <abbr title="Look-Up Table">LUT</abbr>[^lookup-time] to make the above code production-ready, but there's no need to stop here! RRIPs make it possible to build even more sophisticated caching systems.

## Domain-Specific Optimization

Most hardware is general purpose, but software tends to specialize, and being able to make more granular predictions about the future is a huge opportunity for programs with domain-specific knowledge. One example of this is a binary tree: _every_ operation uses the root node, but a random leaf's probability of participating in a search is ¹⁄ₙ—a perfect application for a RRIP!

Also note that a _distant_ re-reference prediction inserts entries into the drain, preventing the occasional rotation of the ring buffer that ages out cache entries with shorter RRPVs. Software that is aware of its scanning/thrashing operations can take advantage of this to apply a BRRIP-like policy to them, eliminating the need for set dueling.

## In Short

CPUs depend on the performance of their cache hierarchies, which have steadily improved as engineers have discovered increasingly accurate heuristics for predicting reuse. Advancements like set dueling are important for general purpose caches, but RRIPs are unique in that they offer flexibility that can also be exploited by tasks with domain-specific knowledge. I haven't seen many examples of people actually taking advantage of this, presumably because most such tasks exist in the realm of software. Luckily, it's fairly straightforward to implement a RRIP cache in code!


[^141]: I'm being glib here, there _are_ limits. In college two friends and I managed to design an application-specific CPU that included an instruction so complex that Xilinx reported the theoretical maximum clock speed would have been below 5MHz.
[^bits]: Well, they're probably using 3 or 4 bits.
[^abbr]: This is the "RRIP" acronym you'll be seeing later.
[^parlance]: In the parlance of the paper.
[^middle]: Specifically, an _m_-bit counter provides _2<sup>m</sup>_ distinct insertion points into the cache.
[^priority]: SRRIP has two distinct behaviours here, _Hit Priority_ (which promotes hits all the way to the <span style="font-family: 'Museo';">head</span>) and _Frequency Priority_ (which decrements the <abbr title="Re-Reference Prediction Value">RRPV</abbr>). These behaviours are analogous to LRU and <abbr title="Least Frequently Used">LFU</abbr>, respectively.
[^bip]: Intentionally analogous to <abbr title="Bimodal Insertion Policy">BIP</abbr>, for anyone familiar.
[^dueling]: Which Intel [_also_ had a hand in inventing](Qureshi - 2007 - Adaptive Insertion Policies for High Performance Caching.pdf)!
[^lookup-time]: So `node(forKey:)` can run in sub-linear time.
[^short]: _RRPV=1_ is not given a name by the paper, but _short_ seemed the obvious counterpart for _long_.
