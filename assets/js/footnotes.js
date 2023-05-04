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

    // Check if a footnote is linked in the URL and present it if so
    var hash = window.location.hash;
    if (hash) {
        var footnoteReference = $('a.footnote[href="' + escapeSelector(hash) + '"]');
        if (footnoteReference.length > 0) {
            footnoteReference.popover('show');
        }
    }

    // Hide popovers when clicking outside
    $(document).on('click', function (e) {
        if (!$(e.target).closest('.footnote').length) {
            $('.footnote').popover('hide');
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

    // When a popover is dismissed, update the address bar if necessary
    $('.footnote').on('hidden.bs.popover', function () {
        if (window.location.hash === $(this).attr('href')) {
            history.replaceState(null, null, ' ');
        }
    });

    $(window).resize(function () {
        configureFootnotes();
    });

    configureFootnotes();
});

function configureFootnotes() {
    if ($(window).width() < 992) {
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
    } else {
        // Dismiss any open popovers
        $('.footnote').popover('dispose');

        // Clear the hash if it matches a footnote
        if ($('.footnote').filter(function () {
            return window.location.hash === $(this).attr('href');
        }).length > 0) {
            history.replaceState(null, null, ' ');
        }

        // Position the footnotes in the sidebar
        alignFootnotes();
    }
}


function alignFootnotes() {
    var previousFootnoteBottom = 0;

    $('.footnote').each(function () {
        var footnoteID = $(this).attr('href');
        var escapedFootnoteID = escapeSelector(footnoteID);
        var footnote = $(escapedFootnoteID);

        var referenceTop = $(this).offset().top - ($('.container').offset().top + (footnote.outerHeight() / 2) - $(this).outerHeight());
        if (referenceTop < previousFootnoteBottom) {
            referenceTop = previousFootnoteBottom;
        }
        footnote.css('position', 'absolute');
        footnote.css('top', referenceTop);
        previousFootnoteBottom = referenceTop + footnote.outerHeight(true);
    });
}
