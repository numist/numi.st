// ABOUTME: Shows the build-time preview (favicon and page title) of external links as a popover,
// ABOUTME: on hover for pointer devices and on first tap for touch devices.

window.addEventListener("load", function () {
    var links = $("a.link-preview");
    var current = null;

    links.popover({
        trigger: "manual",
        placement: "auto",
        html: true
    });

    function show(link) {
        if (current === link) return;
        hide();
        current = link;
        $(link).popover("show");
    }

    function hide() {
        if (current) $(current).popover("hide");
        current = null;
    }

    if (window.matchMedia("(hover: hover)").matches) {
        // Delay hiding so the pointer can travel from the link into the popover
        var hideTimer = null;
        function scheduleHide() {
            clearTimeout(hideTimer);
            hideTimer = setTimeout(hide, 300);
        }
        function cancelHide() {
            clearTimeout(hideTimer);
        }

        links.on("mouseenter", function () {
            cancelHide();
            show(this);
        });
        links.on("mouseleave", scheduleHide);
        links.on("inserted.bs.popover", function () {
            $("#" + $(this).attr("aria-describedby"))
                .on("mouseenter", cancelHide)
                .on("mouseleave", scheduleHide);
        });
    } else {
        // First tap shows the preview; tapping the link again (or the title in the popover) navigates
        links.on("click", function (e) {
            if (current === this) return;
            e.preventDefault();
            show(this);
        });

        // Hide popovers when tapping outside
        $(document).on("click", function (e) {
            if (!$(e.target).closest("a.link-preview, .popover").length) {
                hide();
            }
        });
    }
});
