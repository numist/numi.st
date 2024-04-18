---
layout: page
title: Symbols
excerpt: And a little bit of fuzzy matching
published_at: Thu Apr 18 00:53:42 PDT 2024
---

I've added a [symbols page](/symbols) to the site for easy character picking on the go.

I'm constantly reaching for symbols like ⌘ and ⨉ from my phone, so this has been on my TODO list for a while. The combination of Sam Rose [publishing](https://hachyderm.io/@samwho/112288527423374593) his own [site](https://symbol.wtf/) for this and knowing I have the day off tomorrow led to a short hacking session tonight to onshore the concept where I can't forget the address. In the comments I learned that Neven Mrgan [did it previously](https://mrgan.com/gb/); between his page and [another suggestion](https://infosec.exchange/@lcamtuf/112289350026473979) pushing me deeper into the rabbit hole, I filled out a long enough set of symbols to warrant adding some filtering.

And filtering is actually why I'm writing this, because after adding a search bar and some fuzzy matching I realized that filtering alone sucks for this—both "broken circle with northwest arrow (escape key)" and "quarter note" contain the character string "note", but one of those is _obviously_ more correct than the other.

Scoring based on the gaps between matched characters felt like the right answer, and I figured summing their logarithms[^logs] would yield good results, and so far that seems to be correct? I'm sure people smarter than me have written whole papers about the right way to do fuzzy match scoring, but this approach was quick to implement and seems to be "fast enough" to run interactively in a browser on a list of ~hundreds of items. Should one need more performance they could probably ditch the greed-cancellation and logarithms for a nice win.

``` javascript
function fuzzyMatch(haystack, needle) {
    let haystackIndex = 0;
    let needleIndex = 0;
    let haystackIndexLastMatch = -1;
    let matchGaps = [];

    haystack = haystack.toLowerCase();
    needle = needle.toLowerCase();

    while (haystackIndex < haystack.length && needleIndex < needle.length) {
        if (haystack[haystackIndex] === needle[needleIndex]) {
            if (haystackIndexLastMatch >= 0) {
                // `haystackIndex - haystackIndexLastMatch - 1` may overrepresent
                // the gap between matches due to greedy matching, so we search
                // backwards to find the actual gap. This correction may be overly
                // charitable if the haystack has multiple instances of the same
                // character, but it's well worth the improvement in identifying
                // exact matches.
                //
                // For example, the needle "note" should match "beamed sixteenth
                // notes" with no gaps, but without this correction there would
                // be a gap of 4 ("th n").
                let gap = haystackIndex - haystackIndexLastMatch - 1;
                for (let i = haystackIndex - 1; i > haystackIndexLastMatch; i--) {
                    if (haystack[i] === needle[needleIndex - 1]) {
                        gap = haystackIndex - i - 1;
                        break;
                    }
                }
                if (gap > 0) {
                    matchGaps.push(gap);
                }
            }
            needleIndex++;
            haystackIndexLastMatch = haystackIndex;
        }
        haystackIndex++;
    }

    if (needleIndex !== needle.length) {
        // No match: not all needle characters were found in sequence
        return 0;
    }

    return 1 / matchGaps.map(gap => Math.log(gap + 1)).reduce((a, b) => a + b, 0);
}
```

[^logs]: I wanted one gap of four characters between matches to score better than four gaps of one character each.
