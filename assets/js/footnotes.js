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
    return str.replace(/:/g, '\\:');
}

window.addEventListener('load', function () {
    // The following DOM reshuffling is the result of Jekyll rendering
    // footnotes in one way and my layout decisions wanting them another.

    // Move the ol tag within div.footnotes into aside.footnote-container
    $('aside.footnote-container').append($('div.footnotes ol'));
    // Delete the (now empty) div.footnotes
    $('div.footnotes').remove();
    // Hide the reversefootnote links
    $('a.reversefootnote').hide();

    // Hide popovers when clicking outside
    $(document).on('click', function (e) {
        if (!$(e.target).closest('.footnote').length) {
            $('.footnote').popover('hide');
            // Clear the hash if it matches a footnote
            if ($('.footnote').filter(function () {
                return window.location.hash === $(this).attr('href');
            }).length > 0) {
                history.replaceState(null, null, ' ');
            }
        }
    });

    // Prevent the default behavior of footnote links,
    // update the address bar, and
    // dismiss any other popovers
    $('a.footnote').click(function (e) {
        e.preventDefault();
        $('.footnote').filter(function () {
            return $(this).attr('href') !== $(e.target).attr('href');
        }).popover('hide');
        history.replaceState(null, null, $(this).attr('href'));
    });

    // // When a popover is dismissed, update the address bar if necessary
    // $('.footnote').on('hidden.bs.popover', function () {
    //     if (window.location.hash === $(this).attr('href')) {
    //         history.replaceState(null, null, ' ');
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
        $('.footnote').popover('dispose');

        // Position the footnotes in the sidebar
        alignFootnotes();
    } else if (oldWidth >= 992) {
        $('.footnote').each(function () {
            var footnoteID = $(this).attr('href');
            var escapedFootnoteID = escapeSelector(footnoteID);
            var footnoteContent = $(escapedFootnoteID).html();

            $(this).popover({
                content: footnoteContent,
                trigger: 'click',
                placement: 'auto',
                html: true,
                sanitize: false
            });
        });

        // Check if a footnote is linked in the URL and present it if so
        var hash = window.location.hash;
        if (hash) {
            var footnoteReference = $('a.footnote[href="' + escapeSelector(hash) + '"]');
            if (footnoteReference.length > 0) {
                console.log('Footnote ' + hash + ' is linked in the URL. Presenting it.');
                footnoteReference.popover('show');
            }
        }
    }

    // Now that the footnotes are positioned, move the viewport to any footnote linked in the URL
    var hash = window.location.hash;
    if (hash) {
        var footnoteReference = $('a.footnote[href="' + escapeSelector(hash) + '"]');
        if (footnoteReference.length > 0) {
            console.log('Footnote ' + hash + ' is linked in the URL. Moving the viewport to it.');
            $('html, body').animate({
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

    $('.footnote').each(function () {
        var footnoteID = $(this).attr('href');
        var escapedFootnoteID = escapeSelector(footnoteID);
        var footnote = $(escapedFootnoteID);
        if (footnotes.contains(escapedFootnoteID)) {
            console.log('Footnote ' + escapedFootnoteID + ' has already been processed. Skipping.');
            return;
        }

        var referenceTop = $(this).offset().top - $('.container').offset().top;
        if (referenceTop < previousFootnoteBottom) {
            referenceTop = previousFootnoteBottom;
        }
        console.log('Positioning footnote ' + escapedFootnoteID + ' at ' + referenceTop + 'px');
        footnote.css('position', 'absolute');
        footnote.css('top', referenceTop);
        previousFootnoteBottom = referenceTop + footnote.outerHeight(true);
        footnotes.push(escapedFootnoteID);
    });

    if (footnotes.length === 0) { return; }

    if ($(footnotes.last()).offset().top + $(footnotes.last()).outerHeight(true) > $('footer').offset().top) {
        // Calculate the distance between the bottom of the last footnote and the top of the footer
        var distance = $('footer').offset().top - ($('.container').offset().top + $(footnotes.last()).offset().top + $(footnotes.last()).outerHeight(true));
        console.log('Footnote ' + footnotes.last() + ' needs to be shifted ' + distance + 'px to clear the footer.');

        for (var index = footnotes.length - 1; index >= 1 && distance < 0; index--) {
            var footnote = $(footnotes[index]);
            console.log('Repositioning footnote ' + footnotes[index] + ' ' + distance + 'px');
            footnote.css('top', footnote.offset().top + distance);

            // Recalculate the distance for repositioning the previous footnote
            distance = footnote.offset().top - ($('.container').offset().top + $(footnotes[index - 1]).offset().top + $(footnotes[index - 1]).outerHeight(true));
            if (distance < 0) {
                console.log('Footnote ' + footnotes[index - 1] + ' needs to be shifted ' + distance + 'px to clear the previous footnote.');
            }
        }
    }
}
