---
title: "`defer` for Objective-C"
timestamp: 2022-01-08 09:07:30 -0800
tags: [💻]
---

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

This reduces duplication while sacrificing code locality. I still don't love it, but I feel like it's a safer style.

Really what I want is something like [Swift's `defer`](https://docs.swift.org/swift-book/ReferenceManual/Statements.html#ID532):

``` c
int fds[2] = { -1, -1}; 
pipe(fds);
defer {
    close(fds[0]);
    close(fds[1]);
};

if (write(fds[0], pointer_to_check, sizeof(intptr_t)) == -1) {
    return not_valid;
} else {
    return valid;
}
```

Turned out it's not too heinous to hack together. Here it is:

``` c
#ifndef TOKENPASTE2
# define TOKENPASTE(x, y) x ## y
# define TOKENPASTE2(x, y) TOKENPASTE(x, y)
#endif

/* This function takes a pointer to a block, dereferences it, and invokes
 * it. It's this way because __attribute__((__cleanup__(…))) always passes
 * a _pointer_ to the thing as the cleanup functions' parameter.
 */
static void __BA7F1207D89C2F82(void (^ *pBlock)(void)) {
    void (^block)(void) = *pBlock;
    block();
}

/* Declare a local block variable that contains the cleanup code.
 * It has three attributes:
 *   __unused__: because you should NEVER touch this local yourself
 *   __deprecated__: because you should NEVER touch this local yourself
 *   __cleanup__: to get its pointer passed to __BA7F1207D89C2F82 (above)
 *                when the scope ends
 */
#define defer \
void (^ TOKENPASTE2(__defer_, __LINE__))(void) \
__attribute__((__unused__, \
               deprecated("hands off!"), \
               __cleanup__(__BA7F1207D89C2F82))) = ^
```

[^mmap]: as appealing as its promise is, `mmap` is bad and you should never use it unless you truly need garbage collected shared memory between processes, in which case your life already sucks and I'm sorry. `pread` and `pwrite` will set `errno` instead of crashing your process and are not nearly as slow as you think; you should stick with them until you can measure otherwise, at which point you should investigate doing your own paging because as I just said `mmap` is dangerous and bad.
[^mincore]: If you have a problem with wild pointers then you _also_ have much bigger problems that you should solve first. If you're just hacking away on code that will never run on someone else's computer you should try [`mincore`](https://man7.org/linux/man-pages/man2/mincore.2.html) or [`mach_vm_read`](https://developer.apple.com/documentation/kernel/1402405-mach_vm_read).
