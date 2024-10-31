---
layout: page
title: "`git diff` Support for SQLite Databases"
description: "In case there's literally anyone else in the world other than me that needs it."
published_at: Fri Jan 12 23:02:36 PDT 2024
---

<!-- Code diffing depends on a couple of implicit premises to function well[^thoughts]:

1. One of the inputs is derived from the other
2. Both inputs can be usefully tokenized by splitting on newlines
3. The order of those tokens always changes the meaning

This basically matches how people write source code in most languages, which is why we still use `difftools`, but it quickly falls apart on structured formats, and forget about anything binary. SQLite databases are both, with a paginated format that makes it very easy to construct multiple different files that all represent the exact same contents.

Luckily, databases can also be represented by the series of SQL statements required to make a copy[^vacuum], and `.dump` will produce them with a stable order (based on rowid) one line at a time. -->

The following teaches git how to convert an SQLite database into text that can be usefully diffed:

``` ini
# .gitconfig / .git/config
[diff "sqlite3"]
    binary = true
    textconv = echo .dump | sqlite3
```

All that's left is teaching git how to recognize SQLite files. I'm not aware of any way to teach it about [magic bytes](https://www.sqlite.org/fileformat.html#magic_header_string) or the `file` command[^comment] so I've resorted to pattern matching:

``` shell
# .gitattributes
*.db diff=sqlite3
```

([originally](https://xoxo.zone/@numist/111747357265896352))

[^thoughts]: I have a lot of [thoughts](https://xoxo.zone/@numist/111744563374270750) about this from a year doing novel diffing research, but nothing has crystallized into a blog post yet.
[^vacuum]: `VACUUM`'s operation is _almost_ "pipe the output of `.dump` into a brand new database connection and then replace the old database with it", and the database file it produces is exactly the same.
[^comment]: Please write in if you do!