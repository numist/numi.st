---
layout: page
title: "`mmap` Considered Harmful"
description: "So why do people keep using it?"
published_at: Thu Oct 17 23:10:17 PDT 2024
---

[Richard](https://sqlite.org/forum/forumpost/3ce1ee76242cfb29), as [quoted by Simon Willison](https://simonwillison.net/2024/Oct/18/d-richard-hipp/):

> I'm of the opinion that you should never use mmap, because if you get an I/O error of some kind, the OS raises a signal, which SQLite is unable to catch, and so the process dies. When you are not using mmap, SQLite gets back an error code from an I/O error and is able to take remedial action, or at least compose an error message.

I have ranted about `mmap`[^files] on this site [before](/post/2022/objc-defer/#fn:mmap), and avoidable crashes _ought_ to be a compelling reason to avoid it, but people still use it! Perhaps it would help to ask _why_:

## Performance

This is the usual reason people give. "`mmap` is faster" is usually supported by two reasons: syscall overhead and buffer copying.

Syscalls were an uncommon bottleneck twenty years ago, but almost nobody today can honestly attribute their software's poor performance to syscall overhead, in part because overhead for common syscalls (like `pread`) has decreased significantly over the years.

Likewise, most people in userland whose performance still depends on zero copy techniques are _writing_ filesystems, not using them[^vmx]. Copy-on-write is good enough for the remaining people who can express their work units as some multiple of the VM's page size.

## Shared Memory

SQLite uses `mmap`[^wal] for manifesting garbage-collected interprocess shared memory regions by path, which is the only reasion I've found for which there is no other option. A POSIX shmem can't be reliably associated with a database when the process is `chroot`ed and will leak if the processes using it all die (or are killed), which is super common on platforms with tight memory constraints.

This is where I step back from the doomerism a bit. The combination of file monitoring via [`DISPATCH_SOURCE_TYPE_VNODE`](https://developer.apple.com/documentation/dispatch/dispatch_source_type_vnode?language=objc) and the strategic use of [`mach_vm_read_overwrite`](https://developer.apple.com/documentation/kernel/1402127-mach_vm_read_overwrite) when significant time has elapsed between accesses has, in practice, almost entirely eliminated `mmap`-related crashes in SQLite (the API will return `SQLITE_IOERR_VNODE` (6922) instead) with no measureable performance cost. But these mitigations are _so much more complicated_ than "an API that returns an error if it fails", which brings us finally to the _real_ reason people use `mmap`,

## Convenience

`mmap` is from a time before APIs expressed their own opinions[^opinions] and its ease of use makes it an extremely attractive nuisance. Nobody likes to admit to being lazy, but for files of arbitrary size (like databases), jumping around with pointer arithmetic is hard to beat: one bounds check and no memory management. Humans are creatures of incentive, and for the most part C provides no incentives for software to be any better than "good enough"<!--, which can be largely be defined in terms of the amount of load it bears. SQLite is probably the most load-bearing userland software in existence and [its qualification practices](https://www.sqlite.org/testing.html) reflect that. _Of course_ Richard will tell you not to use `mmap`-->.

The solution here is one of progress. CISA and the FBI [have asked vendors to provide memory-safety roadmaps by 2026](https://www.cisa.gov/resources-tools/resources/product-security-bad-practices); while [C code _can_ be made memory-safe](https://clang.llvm.org/docs/BoundsSafety.html), languages built with memory safety by default tend to be higher level and include standard libraries that provide more ergonomic (and opinionated) abstractions for things like file I/O.

[^files]: I am going to use `mmap` to refer specifically to the creation of file-backed memory maps. This is not strictly correct—there are map types other than `MAP_FILE`—but it is colloquial.
[^vmx]: Also virtual machines, at least circa 2010 when I helped get our hardware accelerated 3D graphics stack get down to zero copies within the scope of the vmx. It has been _very funny_ to watch Apple Silicon's Unified Memory Architecture do the same thing but in actual hardware.
[^wal]: For the [wal index](https://www.sqlite.org/walformat.html#the_wal_index_file_format).
[^opinions]: These days, languages and their libraries can conspire so "bad" code is more difficult to write than "good" code. This was never the case with POSIX interfaces and remains rare among syscalls in general.
