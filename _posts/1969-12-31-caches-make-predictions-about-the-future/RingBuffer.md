---
layout: page
date: April 4, 2023 at 22:35
---

``` swift
//
// RingBuffer.swift
// Created by numist on April 4, 2023 at 22:35
//
// In loving memory of crazybob
//

struct RingBuffer<Element>: RandomAccessCollection {
  private(set) var buffer: [Element]
  private(set) var head: Int

  init(repeating element: @autoclosure () -> Element, count: Int) {
    buffer = [Any?](repeating: nil, count: count).map({ _ in element() })
    head = 0
  }

  var count: Int { buffer.count }
  var startIndex: Int { 0 }
  var endIndex: Int { buffer.count }
  subscript(position: Int) -> Element {
    get {
      assert(position >= -buffer.count && position < buffer.count)
      let index = (head + position + buffer.count) % buffer.count
      return buffer[index]
    }
    set {
      assert(position >= -buffer.count && position < buffer.count)
      let index = (head + position + buffer.count) % buffer.count
      buffer[index] = newValue
    }
  }

  mutating func rotate() {
    head = (head + 1) % buffer.count
  }
}
```
