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

The <abbr title="Re-Reference Interval Prediction">RRIP</abbr> paper posits: what if caches made reuse predictions more nuanced than "immediately" and "probably never"? It conceptualizes intermediate predictions as inserting a value somewhere in the middle[^middle] of the list, and those 2-bit counters are how they do it.

Based on this concept, their new eviction policy predicts values are not likely to be reused again _unless they have been reused in the past_, accomplishing this by inserting new values near the front of the list and promoting them towards the end when they're hit. Another variation adds some randomization to new entries' insertion position in an effort to provide scan resistance.

## In Software

Of course caches are commonly found in software, too. Some things are costly to compute on demand, but the system's memory can't store the result of every computation. As a twist, sometimes software has domain-specific knowledge that helps it make better-informed re-reference interval predictions. A great example of this is binary trees—_every_ operation uses the root node, but a random leaf's probability of participating in a search is ¹⁄ₙ—a perfect application for an RRIP cache!

Managing a counter per slot in software would be pretty heinous, but the concept can be expressed pretty directly by using a ring buffer:

<div class="language-swift highlighter-rouge"><div class="highlight"><pre class="highlight"><code><span class="kd">class</span> <span class="kt">RRIP</span><span class="o">&lt;</span><span class="kt">Key</span><span class="p">:</span> <span class="kt">Hashable</span><span class="p">,</span> <span class="kt">Value</span><span class="o">&gt;</span> <span class="p">{</span>
  <span class="c1">// Note: The Re-Reference Prediction Values are inverted from the paper for</span>
  <span class="c1">// ease of implementation. The larger the value, the more likely the item</span>
  <span class="c1">// is expected to be reused.</span>
  <span class="kd">enum</span> <span class="kt">RRPV</span> <span class="p">{</span>
    <span class="k">case</span> <span class="nv">unspecified</span><span class="p">,</span> <span class="nv">nearImmediate</span><span class="p">,</span> <span class="nv">long</span><span class="p">,</span> <span class="nv">distant</span><span class="p">,</span> <span class="nv">raw</span><span class="p">(</span><span class="nv">cold</span><span class="p">:</span> <span class="kt">Int</span><span class="p">,</span> <span class="nv">hot</span><span class="p">:</span> <span class="kt">Int</span><span class="p">)</span>

    <span class="kd">func</span> <span class="nf">rawValue</span><span class="p">(</span><span class="n">_</span> <span class="nv">hit</span><span class="p">:</span> <span class="kt">Bool</span> <span class="o">=</span> <span class="kc">false</span><span class="p">)</span> <span class="o">-&gt;</span> <span class="kt">Int</span> <span class="p">{</span>
      <span class="k">switch</span> <span class="k">self</span> <span class="p">{</span>
        <span class="k">case</span> <span class="o">.</span><span class="n">nearImmediate</span><span class="p">:</span> <span class="k">return</span> <span class="o">-</span><span class="mi">1</span> <span class="c1">// RingBuffer allows negative indexing</span>
        <span class="k">case</span> <span class="o">.</span><span class="n">long</span><span class="p">:</span> <span class="k">return</span> <span class="mi">2</span>
        <span class="k">case</span> <span class="o">.</span><span class="n">distant</span><span class="p">:</span> <span class="k">return</span> <span class="mi">1</span>
        <span class="c1">// Default behaviour is Hit Priority (RRIP-HP)</span>
        <span class="k">case</span> <span class="o">.</span><span class="n">unspecified</span><span class="p">:</span> <span class="k">return</span> <span class="n">hit</span> <span class="p">?</span> <span class="o">-</span><span class="mi">1</span> <span class="p">:</span> <span class="mi">1</span>
        <span class="c1">// Note: Index 0 should not be used; inserting into the drain prevents</span>
        <span class="c1">// aging of elements with nearer RRPVs</span>
        <span class="k">case</span> <span class="o">.</span><span class="nf">raw</span><span class="p">(</span><span class="k">let</span> <span class="nv">cold</span><span class="p">,</span> <span class="k">let</span> <span class="nv">hot</span><span class="p">):</span> <span class="k">return</span> <span class="n">hit</span> <span class="p">?</span> <span class="n">hot</span> <span class="p">:</span> <span class="n">cold</span>
      <span class="p">}</span>
    <span class="p">}</span>
  <span class="p">}</span>

  <span class="kd">typealias</span> <span class="kt">KeyValue</span> <span class="o">=</span> <span class="p">(</span><span class="nv">key</span><span class="p">:</span> <span class="kt">Key</span><span class="p">,</span> <span class="nv">value</span><span class="p">:</span> <span class="kt">Value</span><span class="p">)</span>
  <span class="kd">private</span> <span class="k">var</span> <span class="nv">ring</span><span class="p">:</span> <span class="kt"><a href="RingBuffer">RingBuffer</a></span><span class="o">&lt;</span><span class="kt"><a href="LinkedList">LinkedList</a></span><span class="o">&lt;</span><span class="kt">KeyValue</span><span class="o">&gt;&gt;</span>
  <span class="kd">private</span> <span class="k">var</span> <span class="nv">dict</span> <span class="o">=</span> <span class="p">[</span><span class="kt">Key</span><span class="p">:</span> <span class="kt"><a href="LinkedList">LinkedList</a></span><span class="o">&lt;</span><span class="kt">KeyValue</span><span class="o">&gt;.</span><span class="kt">Node</span><span class="p">]()</span>
  <span class="kd">private</span> <span class="k">let</span> <span class="nv">capacity</span><span class="p">:</span> <span class="kt">Int</span>
  <span class="k">var</span> <span class="nv">count</span><span class="p">:</span> <span class="kt">Int</span> <span class="p">{</span> <span class="n">dict</span><span class="o">.</span><span class="n">count</span> <span class="p">}</span>

  <span class="nf">init</span><span class="p">(</span><span class="nv">capacity</span><span class="p">:</span> <span class="kt">Int</span><span class="p">,</span> <span class="nv">predictionIntervals</span><span class="p">:</span> <span class="kt">Int</span> <span class="o">=</span> <span class="mi">4</span><span class="p">)</span> <span class="p">{</span>
    <span class="nf">precondition</span><span class="p">(</span><span class="nv">predictionIntervals</span> <span class="o">&gt;=</span> <span class="mi">4</span><span class="p">)</span>
    <span class="nf">precondition</span><span class="p">(</span><span class="nv">capacity</span> <span class="o">&gt;</span> <span class="mi">0</span><span class="p">)</span>
    <span class="k">self</span><span class="o">.</span><span class="n">capacity</span> <span class="o">=</span> <span class="nv">capacity</span>
    <span class="k">self</span><span class="o">.</span><span class="n">ring</span> <span class="o">=</span> <span class="kt"><a href="RingBuffer">RingBuffer</a></span><span class="p">(</span><span class="nv">repeating</span><span class="p">:</span> <span class="o">.</span><span class="nf">init</span><span class="p">(),</span> <span class="nv">count</span><span class="p">:</span> <span class="n">predictionIntervals</span><span class="p">)</span>
  <span class="p">}</span>

  <span class="kd">func</span> <span class="nf">fetch</span><span class="p">(</span>
    <span class="nv">key</span><span class="p">:</span> <span class="kt">Key</span><span class="p">,</span>
    <span class="k">default</span> <span class="n">defaultValue</span><span class="p">:</span> <span class="kd">@autoclosure</span> <span class="p">()</span> <span class="o">-&gt;</span> <span class="kt">Value</span><span class="p">,</span>
    <span class="nv">rrpv</span><span class="p">:</span> <span class="kt">RRPV</span> <span class="o">=</span> <span class="o">.</span><span class="n">unspecified</span>
  <span class="p">)</span> <span class="o">-&gt;</span> <span class="kt">Value</span> <span class="p">{</span>
    <span class="k">let</span> <span class="nv">value</span><span class="p">:</span> <span class="kt">Value</span>
    <span class="k">let</span> <span class="nv">hit</span><span class="p">:</span> <span class="kt">Bool</span>
    <span class="k">if</span> <span class="k">let</span> <span class="nv">node</span> <span class="o">=</span> <span class="n">dict</span><span class="p">[</span><span class="n">key</span><span class="p">]</span> <span class="p">{</span>
      <span class="n">value</span> <span class="o">=</span> <span class="n">node</span><span class="o">.</span><span class="n">list</span><span class="o">!.</span><span class="nf">remove</span><span class="p">(</span><span class="n">node</span><span class="p">)</span><span class="o">.</span><span class="n">value</span>
      <span class="n">hit</span> <span class="o">=</span> <span class="kc">true</span>
    <span class="p">}</span> <span class="k">else</span> <span class="p">{</span>
      <span class="n">value</span> <span class="o">=</span> <span class="nf">defaultValue</span><span class="p">()</span>
      <span class="n">hit</span> <span class="o">=</span> <span class="kc">false</span>
    <span class="p">}</span>

    <span class="n">dict</span><span class="p">[</span><span class="n">key</span><span class="p">]</span> <span class="o">=</span> <span class="n">ring</span><span class="p">[</span><span class="n">rrpv</span><span class="o">.</span><span class="nf">rawValue</span><span class="p">(</span><span class="n">hit</span><span class="p">)]</span><span class="o">.</span><span class="nf">enqueue</span><span class="p">((</span><span class="n">key</span><span class="p">,</span> <span class="n">value</span><span class="p">))</span>

    <span class="k">while</span> <span class="n">count</span> <span class="o">&gt;</span> <span class="n">capacity</span> <span class="p">{</span>
      <span class="k">if</span> <span class="k">let</span> <span class="nv">evicted</span> <span class="o">=</span> <span class="n">ring</span><span class="p">[</span><span class="mi">0</span><span class="p">]</span><span class="o">.</span><span class="nf">dequeue</span><span class="p">()</span> <span class="p">{</span>
        <span class="n">dict</span><span class="o">.</span><span class="nf">removeValue</span><span class="p">(</span><span class="nv">forKey</span><span class="p">:</span> <span class="n">evicted</span><span class="o">.</span><span class="n">key</span><span class="p">)</span>
      <span class="p">}</span> <span class="k">else</span> <span class="p">{</span> <span class="n">ring</span><span class="o">.</span><span class="nf">rotate</span><span class="p">()</span> <span class="p">}</span>
    <span class="p">}</span>

    <span class="k">return</span> <span class="n">value</span>
  <span class="p">}</span>
<span class="p">}</span>
</code></pre></div></div>

Note that references to custom types in the code above link to their implementation.

[^141]: I'm being glib here, _of course_ there's a limit. In college two friends and I managed to design an application-specific CPU with an instruction so complex the theoretical maximum clock speed would have been just north of 4MHz.
[^middle]: In the paper, an _m_-bit counter gives you _2<sup>m</sup>_ distinct insertion points into the cache<!--. They may not be evenly spaced, but all entries are guaranteed to make progress towards eviction as long as you don't insert into the 2<sup>m</sup>-1º (where the evictions happen)-->