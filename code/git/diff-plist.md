---
layout: page
title: "`git diff` Support for Property Lists"
description: "Teaching git how to convert plists into text that can be usefully diffed."
published_at: Fri Jan 12 23:49:36 PDT 2024
---

The following teaches git how to convert a plist into text that can be usefully diffed:

``` ini
# .gitconfig / .git/config
[diff "plist"]
    textconv = /usr/libexec/PlistBuddy -x -c print
```

All that's left is teaching git how to recognize plist files:

``` shell
# .gitattributes
*.plist diff=plist
```

([originally](https://xoxo.zone/@numist/111747541251099631))

[^thoughts]: I have a lot of [thoughts](https://xoxo.zone/@numist/111744563374270750) about this from a year doing novel diffing research, but nothing has crystallized into a blog post yet.
[^vacuum]: `VACUUM`'s operation is _almost_ "pipe the output of `.dump` into a brand new database connection and then replace the old database with it", and the database file it produces is exactly the same.
[^comment]: Please write in if you do!