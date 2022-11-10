---
layout: page
---

Hi! I'm [Scott Perry](about), and this is my [website](colophon).

It includes a [blog](blog)[^latest]—which has a [feed](/feed.xml)—and one might charitably call the rest a _digital garden_, but it's all really just an evolution of my home folder. Markup allows media to live inline with styled text, documents can refer to one another, and web hosting gets it off my computer and in front of your eyes, but at the end of the day it's a working repository of my larks and snarks.

I like [motorcycles](/moto), and enjoy making stuff.

[^latest]: the latest post is: <a href="{{ site.posts.first.link | default: site.posts.first.url | relative_url }}">{{ site.posts.first.title | markdownify | remove: '<p>' | remove: '</p>' | strip }}</a>
