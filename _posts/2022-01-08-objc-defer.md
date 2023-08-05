---
layout: post
title: "`defer` for Objective-C"
tags: [💻]
description: Reducing code duplication and improving locality in Objective-C with macros.
---

{% callout info %}
<div class="date-right">August 19, 2022</div>
#### Update
Predictably, [Peter Steinberger and Matej Bukovinski beat me to this](https://pspdfkit.com/blog/2017/even-swiftier-objective-c/), and [Justin Spahr-Summers was ahead of them](https://github.com/jspahrsummers/libextobjc/blob/bdec77056a38a52bc8f30a19cec52d66a70e7bf6/extobjc/EXTScope.h#L12-L33).
{% endcallout %}

This all started because I was complaining about some uninitialized pointer value causing me grief[^mmap] and someone (explicitly trolling) said they always check pointers using:

``` c
int fds[2] = { -1, -1}; 
pipe(fds);
if (write(fds[0], pointer_to_check, sizeof(intptr_t)) == -1) {
    close(fds[0]);
    close(fds[1]);
    return not_valid;
} else {
    close(fds[0]);
    close(fds[1]);
    return valid;
}
```

In case it's not abundantly clear, you should never do this[^mincore], but of course the first thing I saw was the duplication of code responsible for managing resources, a reminder of how redundant and error-prone C can be.

A different formulation of this code might look like:

``` c
int rc, fds[2] = { -1, -1}; 
pipe(fds);
if (write(fds[0], pointer_to_check, sizeof(intptr_t)) == -1) {
    rc = not_valid;
} else {
    rc = valid;
}
close(fds[0]);
close(fds[1]);
return rc;
```

This reduces duplication, but has worse locality. I don't love it, but I feel like it's the safer style.

Really what I want is something like [Swift's `defer`](https://docs.swift.org/swift-book/ReferenceManual/Statements.html#ID532):

``` objective_c
int fds[2] = { -1, -1}; 
pipe(fds);
defer ^{
    close(fds[0]);
    close(fds[1]);
};

if (write(fds[0], pointer_to_check, sizeof(intptr_t)) == -1) {
    return not_valid;
} else {
    return valid;
}
```

Turned out it's not too heinous to hack together, and [it's even exception-safe](https://gist.github.com/numist/1cc7d4ee6355380cdb5e91585189247b)! Here it is:

``` objective_c
static void __defer_cleanup(void (^*pBlock)(void)) { (*pBlock)(); }
#define __defer_tokenpaste(prefix, suffix) prefix ## suffix
#define __defer_blockname(nonce) __defer_tokenpaste(__defer_, nonce)

/* Declare a local block variable that contains the cleanup code.
 * It has three attributes:
 *   unused: because you should NEVER touch this local yourself
 *   deprecated: because you should NEVER touch this local yourself
 *   cleanup: to get its pointer passed to __defer_cleanup (above)
 *                when the scope ends
 */
#define defer \
void (^ __defer_blockname(__LINE__))(void) \
__attribute__((unused, \
               deprecated("hands off!"), \
               cleanup(__defer_cleanup) \
)) = 
```

[^mmap]: as appealing as its promise is, `mmap` is bad and you should never use it unless you truly need garbage collected shared memory between processes, in which case your life already sucks and I'm sorry. `pread` and `pwrite` will set `errno` instead of crashing your process and are not nearly as slow as you think; you should stick with them until you can measure otherwise, at which point you should investigate doing your own paging because as I just said `mmap` is dangerous and bad.
[^mincore]: If you have a problem with wild pointers then you _also_ have much bigger problems that you should solve first. If you're just hacking away on code that will never run on someone else's computer (see: the [Bad Code License](/LICENSES/Bad%20Code.txt)) you should try [`mincore`](https://man7.org/linux/man-pages/man2/mincore.2.html) or [`mach_vm_read`](https://developer.apple.com/documentation/kernel/1402405-mach_vm_read).
