// Add a popover to every abbr element that has a title attribute

window.addEventListener('load', function () {
    $('abbr[title]').each(function () {
        // Set the data-content attribute to the value of the title attribute
        $(this).attr('data-content', $(this).attr('title'));
        // Remove the title attribute
        $(this).removeAttr('title');
    });
    $('abbr[data-content]').each(function () {
        $(this).popover({
            content: $(this).attr('data-content'),
            trigger: 'click',
            placement: 'auto',
            html: true
        });
    });

    // Hide popovers when clicking outside
    $(document).on('click', function (e) {
        if (!$(e.target).closest('abbr[data-content]').length) {
            $('abbr[data-content]').popover('hide');
        }
    });
});
