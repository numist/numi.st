// RingBuffer.swift
// Created April 4, 2023 at 23:22
//
// In loving memory of crazybob
//
struct RingBuffer<Element>: RandomAccessCollection {
  private(set) var buffer: [Element?]
  private(set) var head: Int

  init(repeating element: Element, count: Int) {
    buffer = [Element?](repeating: nil, count: count)
    head = 0
  }

  var count: Int { buffer.count }
  var startIndex: Int { 0 }
  var endIndex: Int { buffer.count }
  subscript(position: Int) -> Element {
    get {
      assert(position < buffer.count)
      let index = (head + position) % buffer.count
      return buffer[index]!
    }
    set {
      assert(position < buffer.count)
      let index = (head + position) % buffer.count
      buffer[index] = newValue
    }
  }

  mutating func rotate() {
    head = (head + 1) % buffer.count
  }

  func index(forAbsoluteIndex absoluteIndex: Int) -> Int {
    return (absoluteIndex - head + count) % count
  }

  func absoluteIndex(for index: Int) -> Int {
    return (head + index) % count
  }
}
