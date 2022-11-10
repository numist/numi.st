---
layout: page
---

# Past

My previous website used a publishing engine that I wrote myself, driven by a dissatisfaction with the state of the art at the time[^wordpress]. On the server it was mostly static, the exception being pagination on the main and series indexes. I wrote in HTML fragments—posts included _all_ the markup that would be published within the `<article>`. I liked the control, but ultimately the friction won and when life changed in 2014 I couldn't find the activation energy required to write for the web anymore. I was tired of typing `<p>`.

Which is too bad, because by then the web had changed dramatically without me noticing. See, I'm not a "web person". I work on system frameworks, languages, and firmwares; my most-trafficked [website](https://thismight.be) started life in the 90s and still uses tables for layout. Writing my own engine felt necessary in the mid-oughts, but a decade later I was finding it exhausting. I just wanted to write in Markdown.

# Present

Which is what I'm doing now. This site is generated by Jekyll, it's hosted on Netlify, the content lives on [GitHub](https://github.com/numist/numi.st), and it depends on dozens of packages with contributions from hundreds of people. The website is about as far from "my own shell scripts and PHP code hosted on my own debian server" as you can get. I still miss the pagination on my old site—only because I thought it philosophically important[^pagination]—but the experience of writing (and probably reading) is categorically better.

Discrete things I've written (or at least adapted) in the making of this site include:

* Footnote popovers powered by [newsfoot](https://gist.github.com/brehaut/567947031a477c89a7f89d96e38a908c)[^newsfoot]
* Labels on [external links](external-links)
* A [repository of CSS files for syntax highlighting](https://github.com/numist/highlight-css)

<!-- In this new world of dependencies, I want to stay on top of updates without adopting any changes that break the site horribly. A combination of deploy previews with an auto-merge GitHub action strikes a reasonable compromise until such a time as accelerationism wins the day[^accelerationism].-->

# Future

* [x] Card-based blog index
  * [ ] Paginate years in the LHS margin
* [ ] I'd like the footnotes to live next to the text when the viewport is big enough—Tanya says I can probably do this using [`<div class="d-none d-lg-block">`](https://getbootstrap.com/docs/5.2/utilities/display/)
* [ ] I'd like to publish some pages that use [Tangle](http://worrydream.com/Tangle/). I'll probably start by onshoring some online "calculators" that I find myself visiting often, like Sheldon Brown's [gear calculator](https://www.sheldonbrown.com/gear-calc.html)
* [ ] [Webmentions](https://webmention.io)? Apparently [one](https://keithjgrant.com/posts/2019/02/adding-webmention-support-to-a-static-site/) can get them working on static sites?
* [ ] adopt Fira Sans sitewide? https://github.com/mozilla/Fira
* [ ] adopt Fira Code as well? https://github.com/tonsky/FiraCode
* [ ] clicking on title from index should browse to about (which should exist)
* [x] delete social.html
* [ ] [jekyll-email-protect](https://github.com/vwochnik/jekyll-email-protect)
* [ ] [jekyll-timeago](https://github.com/markets/jekyll-timeago)
* [ ] [jekyll-toc](https://github.com/toshimaru/jekyll-toc)
* [ ] [mathjax](http://webdocs.cs.ualberta.ca/~zichen2/blog/coding/setup/2019/02/17/how-to-add-mathjax-support-to-jekyll.html)
* [ ] Collections (and [collection indexes](https://jekyllrb.com/docs/plugins/generators/))?
* [x] Make `show_excerpts: true` redundant


[^wordpress]: This was before Markdown had become ubiquitous, most blogs (including my _next oldest_) were Wordpress, and "smart" interactive editors were starting to take over.
[^pagination]: Basically, pages infinite-scrolled by <abbr title="XMLHttpRequest">XHR</abbr>ing the next page and appending its `<article>`s to the current page. More importantly, it _updated the browser's address bar_ so reloading the page would cause all the currently visible content to be part of the first request, preserving the reader's scroll location.
[^newsfoot]: Under the assumption that it's available under the MIT license, based on its inclusion in [NetNewsWire's source code](https://github.com/Ranchero-Software/NetNewsWire/blob/57815f04960f08a78b0fe9972b6a9d8993103e61/Shared/Article%20Rendering/newsfoot.js).