---
layout: post
title: Caches Make Predictions About the Future
excerpt: "How a paper about CPU caches changed the way I think about software caches too"
showtitle: false
image: header.png
---

It's funny how hardware and software are able to solve the same problems in dramatically different ways. Want to add a 2-bit counter to every slot in your cache, then find the first slot with a counter value of `3`—incrementing them all in parallel until a suitable slot is found—in sub-linear time? Sure, why not? It's just transistors! They excel at doing a bunch of stuff in parallel, it's just die space and power![^141]

This "2-bit counter per cache slot" thing isn't a random example—Intel _actually does this_[^bits] in their <abbr title="Last-Level Cache">LLC</abbr>. They even [published a paper about it](Jaleel - 2010 - High Performance Cache Replacement Using Re-Reference Interval Prediction (RRIP).pdf), and it offers a deep understanding of caching as a concept.

## What's a Cache?

You'll often find caches referred to by their eviction policy ("an LRU"), but that confuses behaviour with purpose. A cache is a place to store things you've used in case you need them again later. It's too small to fit everything and can't tell the future, so it uses its eviction policy in an attempt to maximize its ratio of "hits" to "misses".

Eviction policies are bets on future access patterns, and historically they've been pretty simple. LRU is a bet on temporal locality and can be straightforwardly implemented with a doubly-linked list:

<!--{% graphviz %}
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
{% endgraphviz %}-->
<svg class="graphviz" id="LRU" width="296pt" height="100pt" viewBox="0.00 0.00 260.00 88.25" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<g id="graph0" class="graph" transform="scale(1 1) rotate(0) translate(4 84.25)">
<title>LRU</title>
<polygon fill="white" stroke="none" points="-4,4 -4,-84.25 256,-84.25 256,4 -4,4"></polygon>
<g id="node1" class="node"><title>head</title><text text-anchor="middle" x="18" y="-66.95" font-family="Museo" font-size="14.00">head</text></g>
<g id="node2" class="node"><title>A</title><ellipse fill="none" stroke="black" cx="18" cy="-18" rx="18" ry="18"></ellipse><text text-anchor="middle" x="18" y="-12.95" font-family="Museo" font-size="14.00">A</text></g>
<g id="edge1" class="edge"><title>head-&gt;A</title><path fill="none" stroke="black" d="M18,-64.03C18,-59.37 18,-53.17 18,-46.83"></path><polygon fill="black" stroke="black" points="21.5,-47.29 18,-37.29 14.5,-47.29 21.5,-47.29"></polygon></g>
<g id="node5" class="node"><title>B</title><ellipse fill="none" stroke="black" cx="90" cy="-18" rx="18" ry="18"></ellipse><text text-anchor="middle" x="90" y="-12.95" font-family="Museo" font-size="14.00">B</text></g>
<g id="edge3" class="edge"><title>A-&gt;B</title><path fill="none" stroke="black" d="M35.43,-23.88C43.33,-24.69 52.87,-24.94 61.76,-24.61"></path><polygon fill="black" stroke="black" points="61.74,-28.05 71.48,-23.89 61.27,-21.07 61.74,-28.05"></polygon></g>
<g id="node3" class="node"><title>tail</title><text text-anchor="middle" x="234" y="-66.95" font-family="Museo" font-size="14.00">tail</text></g>
<g id="node4" class="node"><title>D</title><ellipse fill="none" stroke="black" cx="234" cy="-18" rx="18" ry="18"></ellipse><text text-anchor="middle" x="234" y="-12.95" font-family="Museo" font-size="14.00">D</text></g>
<g id="edge2" class="edge"><title>tail-&gt;D</title><path fill="none" stroke="black" d="M234,-64.03C234,-59.37 234,-53.17 234,-46.83"></path><polygon fill="black" stroke="black" points="237.5,-47.29 234,-37.29 230.5,-47.29 237.5,-47.29"></polygon></g>
<g id="node6" class="node"><title>C</title><ellipse fill="none" stroke="black" cx="162" cy="-18" rx="18" ry="18"></ellipse><text text-anchor="middle" x="162" y="-12.95" font-family="Museo" font-size="14.00">C</text></g>
<g id="edge8" class="edge"><title>D-&gt;C</title><path fill="none" stroke="black" stroke-dasharray="5,2" d="M216.57,-12.12C208.67,-11.31 199.13,-11.06 190.24,-11.39"></path><polygon fill="black" stroke="black" points="190.26,-7.95 180.52,-12.11 190.73,-14.93 190.26,-7.95"></polygon></g>
<g id="edge4" class="edge"><title>B-&gt;A</title><path fill="none" stroke="black" stroke-dasharray="5,2" d="M72.57,-12.12C64.67,-11.31 55.13,-11.06 46.24,-11.39"></path><polygon fill="black" stroke="black" points="46.26,-7.95 36.52,-12.11 46.73,-14.93 46.26,-7.95"></polygon></g>
<g id="edge5" class="edge"><title>B-&gt;C</title><path fill="none" stroke="black" d="M107.43,-23.88C115.33,-24.69 124.87,-24.94 133.76,-24.61"></path><polygon fill="black" stroke="black" points="133.74,-28.05 143.48,-23.89 133.27,-21.07 133.74,-28.05"></polygon></g>
<g id="edge7" class="edge"><title>C-&gt;D</title><path fill="none" stroke="black" d="M179.43,-23.88C187.33,-24.69 196.87,-24.94 205.76,-24.61"></path><polygon fill="black" stroke="black" points="205.74,-28.05 215.48,-23.89 205.27,-21.07 205.74,-28.05"></polygon></g>
<g id="edge6" class="edge"><title>C-&gt;B</title><path fill="none" stroke="black" stroke-dasharray="5,2" d="M144.57,-12.12C136.67,-11.31 127.13,-11.06 118.24,-11.39"></path><polygon fill="black" stroke="black" points="118.26,-7.95 108.52,-12.11 118.73,-14.93 118.26,-7.95"></polygon></g>
</g>
</svg>

On a "miss", a node is evicted from the <span style="font-family: 'Museo';">head</span> of the list and the new value is inserted at the <span style="font-family: 'Museo';">tail</span>. On a "hit", the reused value's node is moved to the <span style="font-family: 'Museo';">tail</span>. Unused values drift toward the <span style="font-family: 'Museo';">head</span>, "aged out" by the insertion (or movement) of newer (hotter) values to the <span style="font-family: 'Museo';">tail</span>.

Conceptually, the two ends of this list represent _re-reference predictions_: values near the <span style="font-family: 'Museo';">tail</span> are expected to be reused in the _near-immediate_[^parlance] future, while values near the <span style="font-family: 'Museo';">head</span> will be more _distant_.

## Supporting Better Predictions

With this background, the paper asks: what if caches supported re-reference interval predictions (RRIP) more nuanced than _near-immediate_ and _distant_? It conceptualizes intermediate predictions as inserting a value somewhere in the middle of the list, and those counters are how they implement it in hardware[^middle].

Building on this, they propose an eviction policy called <abbr title="Static RRIP">SRRIP</abbr> that bets values are not likely to be re-referenced unless they have been hit in the past, accomplishing this by inserting new values near (but not at!) the <span style="font-family: 'Museo';">head</span> of the list and promoting them towards[^priority] the <span style="font-family: 'Museo';">tail</span> when they're hit. Another policy, called <abbr title="Bimodal RRIP">BRRIP</abbr>[^bip], provides thrash resistance by assuming cold values will be reused in the _distant_ future, with an occasional _long_ prediction thrown in. Finally, <abbr title="Dynamic  RRIP">DRRIP</abbr> pits the two against each other using set dueling[^dueling].

## In Software

Of course caches are common in software, too—values can be costly to conjure, but the storage available for them is finite. Per-slot counters aren't practical to implement in code, but the same concept can be expressed by a ring buffer of doubly-linked lists: a value's index in the ring represents its <abbr title="Re-Reference Prediction Value">RRPV</abbr>, and is incremented by rotation. A ring with four indexes provides the same cache insertion points as a hardware implementation using 2-bit counters:

<!--{% graphviz %}
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
{% endgraphviz %}-->
<svg class="graphviz" id="RRIP" width="280pt" height="234pt" viewBox="0.00 0.00 296.00 246.65" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<g id="graph0" class="graph" transform="scale(1 1) rotate(0) translate(4 242.65)">
<title>RRIP</title>
<polygon fill="white" stroke="none" points="-4,4 -4,-242.65 292,-242.65 292,4 -4,4"></polygon>
<g id="node1" class="node"><title>ringbuffer</title><polygon fill="none" stroke="black" points="0,-144 0,-180 288,-180 288,-144 0,-144"></polygon><text text-anchor="middle" x="35.88" y="-156.95" font-family="Museo" font-size="14.00">3</text><polyline fill="none" stroke="black" points="71.75,-144 71.75,-180"></polyline><text text-anchor="middle" x="107.62" y="-156.95" font-family="Museo" font-size="14.00">0</text><polyline fill="none" stroke="black" points="143.5,-144 143.5,-180"></polyline><text text-anchor="middle" x="179.38" y="-156.95" font-family="Museo" font-size="14.00">1</text><polyline fill="none" stroke="black" points="215.25,-144 215.25,-180"></polyline><text text-anchor="middle" x="251.62" y="-156.95" font-family="Museo" font-size="14.00">2</text></g>
<g id="node2" class="node"><title>A</title><ellipse fill="none" stroke="black" cx="36" cy="-90" rx="18" ry="18"></ellipse><text text-anchor="middle" x="36" y="-84.95" font-family="Museo" font-size="14.00">A</text></g>
<g id="edge1" class="edge"><title>ringbuffer:f3-&gt;A</title><path fill="none" stroke="black" d="M36,-144C36,-144 36,-131.76 36,-118.94"></path><polygon fill="black" stroke="black" points="39.5,-119.28 36,-109.28 32.5,-119.28 39.5,-119.28"></polygon></g>
<g id="node3" class="node"><title>B</title><ellipse fill="none" stroke="black" cx="252" cy="-90" rx="18" ry="18"></ellipse><text text-anchor="middle" x="252" y="-84.95" font-family="Museo" font-size="14.00">B</text></g>
<g id="edge2" class="edge"><title>ringbuffer:f2-&gt;B</title><path fill="none" stroke="black" d="M252,-144C252,-144 252,-131.76 252,-118.94"></path><polygon fill="black" stroke="black" points="255.5,-119.28 252,-109.28 248.5,-119.28 255.5,-119.28"></polygon></g>
<g id="node4" class="node"><title>D</title><ellipse fill="none" stroke="black" cx="108" cy="-90" rx="18" ry="18"></ellipse><text text-anchor="middle" x="108" y="-84.95" font-family="Museo" font-size="14.00">D</text></g>
<g id="edge3" class="edge"><title>ringbuffer:f0-&gt;D</title><path fill="none" stroke="black" d="M108,-144C108,-144 108,-131.76 108,-118.94"></path><polygon fill="black" stroke="black" points="111.5,-119.28 108,-109.28 104.5,-119.28 111.5,-119.28"></polygon></g>
<g id="node5" class="node"><title>C</title><ellipse fill="none" stroke="black" cx="252" cy="-18" rx="18" ry="18"></ellipse><text text-anchor="middle" x="252" y="-12.95" font-family="Museo" font-size="14.00">C</text></g>
<g id="edge4" class="edge"><title>B-&gt;C</title><path fill="none" stroke="black" d="M257.88,-72.57C258.69,-64.67 258.94,-55.13 258.61,-46.24"></path><polygon fill="black" stroke="black" points="262.05,-46.26 257.89,-36.52 255.07,-46.73 262.05,-46.26"></polygon></g>
<g id="edge5" class="edge"><title>C-&gt;B</title><path fill="none" stroke="black" stroke-dasharray="5,2" d="M246.12,-35.43C245.31,-43.33 245.06,-52.87 245.39,-61.76"></path><polygon fill="black" stroke="black" points="241.95,-61.74 246.11,-71.48 248.93,-61.27 241.95,-61.74"></polygon></g>
<g id="node6" class="node"><title>head</title><text text-anchor="middle" x="36" y="-203.75" font-family="Museo" font-size="14.00">distant</text></g>
<g id="edge6" class="edge"><title>head-&gt;ringbuffer:f3</title><path fill="none" stroke="black" d="M36,-200.62C36,-197.56 36,-194.04 36,-190.78"></path><polygon fill="black" stroke="black" points="39.5,-191 36,-181 32.5,-191 39.5,-191"></polygon></g>
<g id="node7" class="node"><title>tail</title><text text-anchor="middle" x="108" y="-225.35" font-family="Museo" font-size="14.00">near-immediate</text></g>
<g id="edge7" class="edge"><title>tail-&gt;ringbuffer:f0</title><path fill="none" stroke="black" d="M108,-222.52C108,-214 108,-200.34 108,-190.81"></path><polygon fill="black" stroke="black" points="111.5,-191 108,-181 104.5,-191 111.5,-191"></polygon></g>
<g id="node8" class="node"><title>short</title><text text-anchor="middle" x="180" y="-203.75" font-family="Museo" font-size="14.00">short</text></g>
<g id="edge8" class="edge"><title>short-&gt;ringbuffer:f1</title><path fill="none" stroke="black" d="M179.72,-200.62C179.61,-197.56 179.49,-194.04 179.37,-190.78"></path><polygon fill="black" stroke="black" points="182.84,-190.87 179,-181 175.85,-191.12 182.84,-190.87"></polygon></g>
<g id="node9" class="node"><title>long</title><text text-anchor="middle" x="252" y="-203.75" font-family="Museo" font-size="14.00">long</text></g>
<g id="edge9" class="edge"><title>long-&gt;ringbuffer:f2</title><path fill="none" stroke="black" d="M252,-200.62C252,-197.56 252,-194.04 252,-190.78"></path><polygon fill="black" stroke="black" points="255.5,-191 252,-181 248.5,-191 255.5,-191"></polygon></g>
</g>
</svg>

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

A lot of modern CPU performance has come from improvements to hardware cache eviction policies, which is just a fancy way of saying they've gotten better at predicting the future. Advancements like set dueling are important for general purpose caches, but RRIPs are unique in that they offer flexibility that can also be exploited by tasks with domain-specific knowledge. I haven't seen many examples of people actually taking advantage of this, presumably because most such tasks exist in the realm of software. Luckily, it's fairly straightforward to implement a RRIP cache in code!


[^141]: I'm being glib here, _of course_ there's a limit. In college two friends and I managed to design an application-specific CPU that included an instruction so complex that Xilinx reported the theoretical maximum clock speed would have been below 5MHz.
[^bits]: Well, they're probably using 3 or 4 bits.
[^parlance]: In the parlance of the paper.
[^middle]: Specifically, an _m_-bit counter gives you _2<sup>m</sup>_ distinct insertion points into the cache—_m=1_ is just <abbr title="Not Recently Used">NRU</abbr>.
[^priority]: SRRIP has two distinct behaviours here, _Hit Priority_ (which promotes hits all the way to the <span style="font-family: 'Museo';">tail</span>) and _Frequency Priority_ (which decrements the <abbr title="Re-Reference Prediction Value">RRPV</abbr>). These behaviours are analogous to LRU and <abbr title="Least Frequently Used">LFU</abbr>, respectively.
[^bip]: Intentionally analogous to <abbr title="Bimodal Insertion Policy">BIP</abbr>, for anyone familiar.
[^dueling]: Which Intel [_also_ had a hand in inventing](Qureshi - 2007 - Adaptive Insertion Policies for High Performance Caching.pdf)!
[^lookup-time]: So `node(for:)` can run in sub-linear time.
