---
layout: page
---

Hi! I'm [Scott Perry](about), and this is my [website](colophon).

It needs a few more things before I push it out:

* [ ] pages need backlinks (design for this might make for good webmention integration as well)

There is a [blog](blog) component[^feed] (the latest post is: <a  target="_self" href="{{ site.posts.first.link | default: site.posts.first.url | relative_url }}">{{ site.posts.first.title | markdownify | remove: '<p>' | remove: '</p>' | strip }}</a>), and one might charitably call the rest a _digital garden_, but it's really just an evolution of my `~/ideas` folder. Markup allows media to live inline with styled text, documents can refer to one another, and web hosting gets it off my computer and in front of your eyes, but at the end of the day it's a working repository of my larks.

[^feed]: Which has a [feed](/feed.xml)!
