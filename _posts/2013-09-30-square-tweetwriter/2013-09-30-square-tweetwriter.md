---
layout: page
title:  "The Square Tweetwriter"
tags: [⌨️]
description: "The typewriter gets dusted off for hack week."
image: "/post/2013/square-tweetwriter/BSZHo-HCcAASmtw.jpeg"
---
In 2010 I [turned a typewriter into a serial teletype for fun](http://numist.net/post/2010/project-typewriter.html) but it has collected dust ever since, just one more thing to pack whenever I've moved. Each quarter, Square sets aside a full week for everyone in the company to build something self-directed and this time seemed like a good opportunity to dust it off and do something fun.

At Square our office is littered with [inforads, or "information radiators"](https://developer.squareup.com/blog/inside-a-square-inforad/). They're mostly column-mounted televisions displaying web pages that show things like a world map annotated with transactions as they happen, or <abbr title="Gross Payment Volume">GPV</abbr> graphs, or whatever. Omnipresent dispensaries of interesting business information. An automated typewriter seemed like a natural kind of inforad, but what would it print?

Well, tweets of course. Specifically, anything that mentioned the @Square account.

It worked great and [I wrote a blog post about it for The Corner](https://developer.squareup.com/blog/the-square-tweetwriter/). You should check that out because the rest of this post is more of a supplement than a reprise.

People had a lot of fun with it from the start, tweeting funny messages and then wandering over to the coffee bar to see their text clatter to life:

![Jerry Lin tweets: "@square all work and no play makes jack a dull boy. all work and no play makes jack a dull boy. all work and no play makes jack a dull boy."](IMG_0932.jpeg)

Once it went public, people out in the world seemed to enjoy sending their messages directly into the office:

![@Levertis_Menter tweets: "@square I'm only writing this so it prints out on that typewriter"](IMG_0935.jpeg)

Extra thanks to Ben Novakovic for the "best hack week project" nomination:

<!--<blockquote class="twitter-tweet"><p lang="en" dir="ltr">@thefriley @square @jack This is possibly the best hack week project I&#39;ve ever seen.</p>&mdash; Ben Novakovic (@bmn) <a href="https://twitter.com/bmn/status/371070320251125760">August 24, 2013</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>-->
![Tweet by Ben Novakovic (@bmn): "@thefriley @square @jack This is possibly the best hack week project I&#39;ve ever seen." in response to @thefriley: "@square @jack this could be big #hackweek" with a photo of the typewriter, loaded with continuous feed paper, printing out tweets mentioning @square with a Raspberry Pi perched on top and a sticker saying "Scott's Typewriter (Prints mentions of @Square, try it!)"](tweet-screenshot.png)

Like any idea with a week's worth of effort, it had a couple shortcomings. For example if the @Square account tweeted something popular, the typewriter would faithfully—and noisily—relay every single retweet:

![Printed half a dozen times before the paper curls over the horizon, various accounts tweeting "RT @Square: ?Don't count the days, make the days count.? - Muhammad Ali", which was only made funnier by the typewriter's inability to map smart quotes to a key (the question mark was used as a default when an unknown character came across the wire)](IMG_0931.jpeg)

But overall it was a fun project and it felt good to give the typewriter something to do with itself.

The [source code is available](https://github.com/numist/Tweetwriter) in case you also happen have an output device that speaks serial and desperately wants to create a physical record of the internet as it transpires. I hope you do.
