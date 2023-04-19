---
layout: page
date: April 4, 2023 at 22:39
---
``` swift
//
// LinkedList.swift
// Created by numist on April 4, 2023 at 22:39
//

class LinkedList<T> {
  class Node {
    let payload: T
    fileprivate(set) var next: Node?
    fileprivate(set) weak var prev: Node?
    fileprivate(set) weak var list: LinkedList<T>?
    init(_ value: T) { self.payload = value }
  }
  private(set) var head: Node?
  private(set) var tail: Node?

  @discardableResult func enqueue(_ element: T) -> Node {
    let newNode = Node(element)
    if tail != nil {
      tail?.next = newNode
      newNode.prev = tail
    } else {
      head = newNode
    }
    tail = newNode
    newNode.list = self
    return newNode
  }

  @discardableResult func remove(_ node: Node) -> T {
    assert(node.list === self)
    node.list = nil
    if head === node && tail === node {
      assert(node.next == nil && node.prev == nil)
      head = nil
      tail = nil
      return node.payload
    } else if head === node {
      assert(node.prev == nil && node.next != nil)
      head = node.next
      node.next?.prev = nil
      node.next = nil
      return node.payload
    } else if tail === node {
      assert(node.next == nil && node.prev != nil)
      tail = node.prev
      node.prev?.next = nil
      node.prev = nil
      return node.payload
    } else {
      assert(node.next != nil && node.prev != nil)
      node.prev?.next = node.next
      node.next?.prev = node.prev
      node.next = nil
      node.prev = nil
      return node.payload
    }
  }

  func dequeue() -> T? {
    guard let currentHead = head else {
      return nil
    }
    return remove(currentHead)
  }
}
```
