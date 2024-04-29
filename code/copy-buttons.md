---
layout: page
title: Copy Buttons
excerpt: "A good yak shave."
published_at: Sat Apr 27 23:43:55 PDT 2024
---

The [Link to Text Fragment Generator](/tool/link-to-text-fragment/#:~:text=take%20you%20directly%20to%20that%20text)'s output needed a copy button, which was [something I already wanted](https://github.com/numist/numi.st/issues/51) for the site's code blocks. The guides I found for doing this mostly had the copyable text duplicated in an attribute or used a weird input selection dance. Seeing an opportunity to generalize, I figured I'd write my own. The adoption goal: anything that wants a button need only don the `copyable` class.

One limiting factor is that I don't really own the server side stack; this site is built using Jekyll and I'm not inclined to change its Markdown renderer or anything like that[^rss]. So, second goal: it should run client-side. Ultimately the solution is pretty portable, depending only on jQuery.

## The Code

When the DOM is loaded, code blocks are made copyable and then each copyable element has a child button added to it:

``` javascript
document.addEventListener("DOMContentLoaded", function() {
    $("div.highlight").each(function() {
        this.classList.add("copyable");
    });
    $(".copyable").each(function() {
        let copyButton = document.createElement("button");
        copyButton.textContent = "Copy";
        copyButton.classList.add("copy-button");
        copyButton.onclick = copyAction;
        this.appendChild(copyButton);
    });
});
```

The button's action reaches back up to the parent, clones it (recursively), removes the copy button and all invisible elements[^viz], harvests the plain text representation, and stuffs it into the pasteboard:

``` javascript
function copyAction(event) {
    event.preventDefault();

    const clone = event.target.parentElement.cloneNode(true);
    clone.querySelector(".copy-button").remove();

    document.body.appendChild(clone);
    Array.from(clone.querySelectorAll("*")).forEach(function(element) {
        const style = window.getComputedStyle(element);
        if (
            style.display === "none" ||
            style.visibility === "hidden" ||
            style.opacity === "0"
        ) {
            element.remove();
        }
    });
    document.body.removeChild(clone);

    navigator.clipboard.writeText(clone.textContent.trim())
        .then(() => {
            event.target.textContent = "Copied!";
            setTimeout(() => {
                event.target.textContent = "Copy";
            }, 2000);
        })
        .catch(err => console.error(`Failed to copy content: ${err}`));
}
```

All that's left is styling to suit your application. To get started, the following will float the button at the top right of its parent:

``` css
.copyable {
    position: relative;
}
.copy-button {
    position: absolute;
    top: 0;
    right: 0;
}
```

[^rss]: In fact, one unexpected point in favour of doing this in the client, which I learned from implementing the [site's footnotes](https://numi.st/colophon/#:~:text=Sidebar%2Fpopover%20footnotes,-3), is that it saves the RSS feed from totally avoidable brokenness.
[^viz]: Elements are not styled by the browser unless they are part of the document, hence the need for `document.body.appendChild(clone)` before `getComputedStyle()`. Removing it synchronously should avoid the clone getting picked up by the browser's rendering cycle.
