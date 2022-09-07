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