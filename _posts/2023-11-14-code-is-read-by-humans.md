---
layout: page
title: "Code is run by computers"
excerpt: "…but it is read by humans"
tags: [💻]
showtitle: false
---

Tony Mottaz, in [a delightful short post](https://www.tonymottaz.com/code-for-computers-and-humans/):
> Code is run by computers, but it is read by humans. In this post, I explore an example of code that is written with empathy for other programmers.

When I was at ᴠᴍware[^old], the engineering culture involved writing an _enormous_ number of assertions. Even the internal functions all exhaustively validated their parameters and the expected state of their systems. The immediate consequences of this practice were predictable enough—our debug builds were slow and our releases were solid—but it took me until working on SQLite[^paranoia] to understand assertions' usefulness for sharing the developer's thought process.

It's an old joke that code comments are out of date the moment they're written, but this doesn't have to be the case! When a longer explanation is helpful, its accuracy can be maintained by an assertion[^noassert]. Take for example[^magic] this excerpt [from SQLite](https://www.sqlite.org/src/info?name=0a33005e6426702c&ln=4969):

``` c
  /* Check that, if this to be a blocking lock, no locks that occur later
  ** in the following list than the lock being obtained are already held:
  **
  **   1. Checkpointer lock (ofst==1).
  **   2. Write lock (ofst==0).
  **   3. Read locks (ofst>=3 && ofst<SQLITE_SHM_NLOCK).
  **
  ** In other words, if this is a blocking lock, none of the locks that
  ** occur later in the above list than the lock being obtained may be
  ** held.
  **
  ** It is not permitted to block on the RECOVER lock.
  */
#ifdef SQLITE_ENABLE_SETLK_TIMEOUT
  {
    u16 lockMask = (p->exclMask|p->sharedMask);
    assert( (flags & SQLITE_SHM_UNLOCK) || pDbFd->iBusyTimeout==0 || (
          (ofst!=2)                                   /* not RECOVER */
       && (ofst!=1 || lockMask==0 || lockMask==2)
       && (ofst!=0 || lockMask<3)
       && (ofst<3  || lockMask<(1<<ofst))
    ));
  }
#endif
```

`Check that…no locks that occur later in the following list…are already held` _clearly_ expresses the assertion's purpose—detecting locking patterns that may result in deadlock—in a way that the code itself cannot. And if the assertion ever changes, the need to update its associated comment is pretty difficult[^impossible] to ignore.

[^old]: September 2007 - June 2011
[^paranoia]: Which exercises a [similar level of paranoia](https://www.sqlite.org/testing.html#assert)
[^noassert]: Conversely, if a comment can't be reasonably tied to an assertion, does it need to be said?
[^magic]: Before too many people send me email about the magic numbers, I gave that feedback to dan already and he pointed out that [the `WAL_*_LOCK` macros](https://www.sqlite.org/src/file?ci=84634bc268e5c801&name=src/wal.c&ln=294) are offsets, while `lockMask` is a bitfield—unmagicking this assertion risks making it even more confusing. One may argue with that conclusion, but the truth is that if this fails it will take the reader (me, a week ago) _far_ longer to diagnose their problem than to understand the assertion.
[^impossible]: Though not impossible, humans being what we are
