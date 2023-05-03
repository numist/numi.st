function escapeSelector(str) {
    return str.replace(/:/g, '\\:');
}

$(document).ready(function () {
    // Move the ol tag within div.footnotes into aside.footnote-container
    $('aside.footnote-container').append($('div.footnotes ol'));
    // And delete the now empty div.footnotes
    $('div.footnotes').remove();
    // Hide the reversefootnote links
    $('a.reversefootnote').hide();

    configureFootnotes();
    $(window).resize(function () {
        configureFootnotes();
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
                trigger: 'hover',
                placement: 'auto',
                html: true
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
        var referenceTop = $(this).offset().top - $('.container').offset().top;
        var footnoteID = $(this).attr('href');
        var escapedFootnoteID = escapeSelector(footnoteID);
        var footnote = $(escapedFootnoteID);

        if (referenceTop < previousFootnoteBottom) {
            referenceTop = previousFootnoteBottom;
        }
        footnote.css('position', 'absolute');
        footnote.css('top', referenceTop);
        previousFootnoteBottom = referenceTop + footnote.outerHeight(true);
    });
}