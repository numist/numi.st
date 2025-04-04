Array.prototype.last = function () {
    return this[this.length - 1];
};

Array.prototype.contains = function ( needle ) {
    for (i in this) {
        if (this[i] == needle) return true;
    }
    return false;
 }

function escapeSelector(str) {
    return str.replace(/:/g, "\\:");
}

window.addEventListener("load", function () {
    // The following DOM reshuffling is the result of Jekyll rendering
    // footnotes in one way and my layout decisions wanting them another.

    // Move the ol tag within div.footnotes into aside.footnote-container
    $("aside.footnote-container").append($("div.footnotes ol"));
    // Delete the (now empty) div.footnotes
    $("div.footnotes").remove();
    // Hide the reversefootnote links
    $("a.reversefootnote").hide();

    // Hide popovers when clicking outside
    $(document).on("click", function (e) {
        if (!$(e.target).closest(".footnote").length) {
            $(".footnote").popover("hide");
            // Clear the hash if it matches a footnote
            if ($(".footnote").filter(function () {
                return window.location.hash === $(this).attr("href");
            }).length > 0) {
                history.replaceState(null, null, " ");
            }
        }
    });

    // Prevent the default behavior of footnote links,
    // update the address bar, and
    // dismiss any other popovers
    $("a.footnote").click(function (e) {
        e.preventDefault();
        $(".footnote").filter(function () {
            return $(this).attr("href") !== $(e.target).attr("href");
        }).popover("hide");
        history.replaceState(null, null, $(this).attr("href"));
    });

    // // When a popover is dismissed, update the address bar if necessary
    // $(".footnote").on("hidden.bs.popover", function () {
    //     if (window.location.hash === $(this).attr("href")) {
    //         history.replaceState(null, null, " ");
    //     }
    // });

    $(window).resize(function () {
        var hash = window.location.hash;
        configureFootnotes();
    });

    configureFootnotes();
});

var oldWidth = 992;
function configureFootnotes() {
    if ($(window).width() >= 992) {
        // Dismiss any open popovers
        $(".footnote").popover("dispose");

        // Position the footnotes in the sidebar
        alignFootnotes();
    } else if (oldWidth >= 992) {
        $(".footnote").each(function () {
            var footnoteID = $(this).attr("href");
            var escapedFootnoteID = escapeSelector(footnoteID);
            var footnoteContent = $(escapedFootnoteID).html();

            $(this).popover({
                content: footnoteContent,
                trigger: "click",
                placement: "auto",
                html: true,
                sanitize: false
            });
        });

        // Check if a footnote is linked in the URL and present it if so
        var hash = window.location.hash;
        if (hash) {
            var footnoteReference = $(`a.footnote[href="${escapeSelector(hash)}"]`);
            if (footnoteReference.length > 0) {
                console.log(`Footnote ${hash} is linked in the URL. Presenting it.`);
                footnoteReference.popover("show");
            }
        }
    }

    // Now that the footnotes are positioned, move the viewport to any footnote linked in the URL
    var hash = window.location.hash;
    if (hash) {
        var footnoteReference = $(`a.footnote[href="${escapeSelector(hash)}"]`);
        if (footnoteReference.length > 0) {
            console.log(`Footnote ${hash} is linked in the URL. Moving the viewport to it.`);
            $("html, body").animate({
                scrollTop: footnoteReference.offset().top - 20
            }, 5);
        }
    }
    oldWidth = $(window).width();
}


function alignFootnotes() {
    var previousFootnoteBottom = 0;
    // An empty hash to aggregate footnotes as they're processed
    var footnotes = [];

    // First pass: position all footnotes and let them reflow
    $(".footnote").each(function () {
        var footnoteID = $(this).attr("href");
        var escapedFootnoteID = escapeSelector(footnoteID);
        var footnote = $(escapedFootnoteID);
        if (footnotes.contains(escapedFootnoteID)) {
            console.log(`Footnote ${escapedFootnoteID} has already been processed. Skipping.`);
            return;
        }

        footnote.css("position", "absolute");
        footnotes.push(escapedFootnoteID);
    });

    if (footnotes.length === 0) { return; }

    // Second pass: position footnotes, adjusting for overlaps
    const container = $("article.post");
    const containerTop = container.offset().top;
    const containerBottom = containerTop + container.outerHeight(true);
    let hasOverlap;
    do {
        hasOverlap = false;
        previousFootnoteBottom = 0;

        footnotes.forEach(function(escapedFootnoteID) {
            var footnote = $(escapedFootnoteID);
            var reference = $(`a.footnote[href="${escapedFootnoteID}"]`);

            // Get reference position relative to container
            var referenceTop = reference.offset().top - containerTop;
            var referenceY = referenceTop + reference.outerHeight(true);
            // var referenceY = (referenceTop + referenceBottom) / 2;

            // Try to center the footnote relative to its reference
            var targetTop = referenceY - (footnote.outerHeight(true) / 2);

            // If this would overlap with previous footnote, position below it
            if (targetTop < previousFootnoteBottom) {
                targetTop = previousFootnoteBottom;
            }

            // If this would extend beyond container bottom, try shifting up
            var footnoteBottom = targetTop + footnote.outerHeight(true);
            if (footnoteBottom > containerBottom - containerTop) {
                var newTop = (containerBottom - containerTop) - footnote.outerHeight(true);
                if (newTop < previousFootnoteBottom) {
                    // Need to shift previous footnotes up to make room
                    hasOverlap = true;
                }
                targetTop = newTop;
            }

            console.log(`Positioning footnote ${escapedFootnoteID} at ${targetTop}px`);
            footnote.css("top", targetTop);
            previousFootnoteBottom = targetTop + footnote.outerHeight(true);
        });
    } while (hasOverlap);
}
