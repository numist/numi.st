---
layout: page
---

This website labels external links by executing some javascript at `window.onload`:

``` javascript
window.onload = function ()
{
  var re = /^(https?:\/\/[^\/]+).*$/;
  var currentHref = window.location.href.replace(re, '$1');
  var reLocal = new RegExp('^' + currentHref.replace(/\./, '\\.'));

  var links = document.getElementsByTagName("a");
  for (var i = 0; i < links.length; i++)
  {
    var href = links[i].href;
    if (href == '' || reLocal.test(href) || !/^http/.test(href))
      continue;
    if (links[i].getAttribute('target') == undefined) {
      links[i].setAttribute('target', '_blank');
    }
    if (links[i].className != undefined) {
      links[i].className += ' external';
    } else {
      links[i].className = 'external';
    }
    if (links[i].title != undefined && links[i].title != '') {
      links[i].title += ' (outside link)';
    } else {
      links[i].title = 'Outside link';
    }
  }
}
```

CSS adds some padding and specifies a background image to draw within that space.

``` css
a.external {
  background-image: url("/assets/img/icons8-external-link.svg");
  background-position-x: right;
  background-position-y: center;
  background-size: 0.9em;
  padding-right: 0.95em;
  background-repeat: no-repeat;
}
```

The image itself is licensed from icons8.com, but if you're not picky there's a lot of options out there. The icon scales with the text size, so it's worth finding an SVG.
