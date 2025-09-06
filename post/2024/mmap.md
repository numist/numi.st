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

Syscalls were an uncommon bottleneck twenty years ago, and overhead for common syscalls (like `pread`) have decreased significantly since then. These days their overhead is a rounding error compared to the work they perform.

Likewise, the people in userland whose performance depends on zero-copy techniques are _writing_ filesystems, not _using_ them[^vmx]. <abbr title="Virtual Memory">VM</abbr> <abbr title="Copy on Write">CoW</abbr> is good enough for the remaining people who can express their work units as some multiple of the VM's page size.

## Shared Memory

SQLite uses `mmap`[^wal] for manifesting path-addressible garbage-collected interprocess shared memory regions, which is the only reason I've found for which there is no other option. A POSIX shmem can't be reliably associated with a database when the process is `chroot`ed and will leak if the last process using it dies without releasing its claim first, which is super common on platforms with aggressive oom behaviour (like iOS).

So this is where I step back from the doomerism a bit. Practically speaking, the combination of file monitoring via [`DISPATCH_SOURCE_TYPE_VNODE`](https://developer.apple.com/documentation/dispatch/dispatch_source_type_vnode?language=objc) and the strategic use of [`mach_vm_read_overwrite`](https://developer.apple.com/documentation/kernel/1402127-mach_vm_read_overwrite) when significant time has elapsed since the last access has, in practice, almost entirely eliminated `mmap`-related crashes in SQLite (the API will return `SQLITE_IOERR_VNODE` (6922) instead) with no measureable performance cost. But these mitigations are _so much more complicated_ than "an API that returns an error if it fails", which brings us finally to the _real_ reason people use `mmap`,

## Convenience

`mmap` is from a time before APIs expressed their own opinions intentionally[^opinions] and its ease of use makes it an extremely attractive nuisance. Nobody likes to admit to being lazy, but for files of arbitrary size (like databases), jumping around with pointer arithmetic is hard to beat: one bounds check[^oob] and no memory management. Humans follow incentives, and C provides an environment where it's way easier to ignore errors than to handle them. Consider what SQLite does instead, roughly 8,000 lines of code [implementing](https://www.sqlite.org/src/file?udc=1&ln=on&ci=trunk&name=src%2Fpager.c) a [pager]()https://www.sqlite.org/src/file?udc=1&ln=on&ci=trunk&name=src%2Fpager.h and [another](https://www.sqlite.org/src/file?udc=1&ln=on&ci=trunk&name=src%2Fpcache.c) 2,000 [implementing](https://www.sqlite.org/src/file?udc=1&ln=on&ci=trunk&name=src%2Fpcache1.c) a [page cache](https://www.sqlite.org/src/file?udc=1&ln=on&ci=trunk&name=src%2Fpcache.h). It's hard to blame people for making one call to `mmap` when the alternative is maintaining an additional 10k<abbr title="Lines of Code">LoC</abbr> to do it properly!  <!--, which can be largely be defined in terms of the amount of load it bears. SQLite is probably the most load-bearing userland software in existence and [its qualification practices](https://www.sqlite.org/testing.html) reflect that. _Of course_ Richard will tell you not to use `mmap`-->.

The solution here is basically one of progress. CISA and the FBI [have asked vendors to provide memory-safety roadmaps by 2026](https://www.cisa.gov/resources-tools/resources/product-security-bad-practices); while it's possible to [improve the memory safety of C code](https://clang.llvm.org/docs/BoundsSafety.html), these solutions are not complete[^lifetime]. Languages built with memory safety by default tend to include syntax that make errors harder to ignore than to handle and include standard libraries with more ergonomic (and opinionated) abstractions for things like file I/O.

[^files]: I am going to use `mmap` to refer specifically to the creation of file-backed memory maps. This is not strictly correct—there are map types other than `MAP_FILE`—but it is colloquial.
[^vmx]: Also virtual machines, at least circa 2010 when I helped get our hardware accelerated 3D graphics stack down to zero copies within the scope of the vmx. It has been _very funny_ to watch Apple Silicon's <abbr title="Unified Memory Architecture">UMA</abbr> do the same thing in hardware.
[^wal]: For the [wal index](https://www.sqlite.org/walformat.html#the_wal_index_file_format).
[^opinions]: These days, languages and their libraries can conspire so "bad" code is more difficult to write than "good" code. This was never the case with POSIX interfaces and remains rare among syscalls in general.
[^oob]: Hopefully. At least.
[^lifetime]: `-fbounds-safety` does not help with lifetime issues, for example.