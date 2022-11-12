---
layout: page
---

Hi! I'm [Scott Perry](about), and this is my [website](colophon).

It includes a [blog](blog)[^latest]—which has a [feed](/feed.xml)—and one might charitably call the rest a digital garden[^garden]. I like [motorcycles](/moto), and enjoy making stuff<!-- TODO: make a page that links to stuff—start using collections for this? tags? -->.


[^latest]: the latest post is: <a href="{{ site.posts.first.link | default: site.posts.first.url | relative_url }}">{{ site.posts.first.title | markdownify | remove: '<p>' | remove: '</p>' | strip }}</a>
[^garden]: It's really just an evolution of my home folder. Markup allows media to live inline with styled text, documents can refer to one another, and web hosting gets it off my computer and in front of your eyes, but at the end of the day it's a working repository of my larks and snarks