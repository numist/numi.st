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

    configureFootnotes();

    $(window).resize(function () {
        configureFootnotes();
    });

    // Hide popovers when clicking outside
    $(document).on('click', function (e) {
        if (!$(e.target).closest('.footnote').length) {
            $('.footnote').popover('hide');
        }
    });
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
        $('.footnote').popover('dispose');
        alignFootnotes();
    }
}


function alignFootnotes() {
    var previousFootnoteBottom = 0;

    $('.footnote').each(function () {
        var footnoteID = $(this).attr('href');
        var escapedFootnoteID = escapeSelector(footnoteID);
        var footnote = $(escapedFootnoteID);

        var referenceTop = $(this).offset().top - ($('.container').offset().top + (footnote.outerHeight() / 2) - $(this).outerHeight);
        if (referenceTop < previousFootnoteBottom) {
            referenceTop = previousFootnoteBottom;
        }
        footnote.css('position', 'absolute');
        footnote.css('top', referenceTop);
        previousFootnoteBottom = referenceTop + footnote.outerHeight(true);
    });
}
