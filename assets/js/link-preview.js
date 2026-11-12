// ABOUTME: Shows the build-time preview (favicon and page title) of external links as a popover:
// ABOUTME: on hover for mice, on first tap for touch, and on keyboard focus.

window.addEventListener("load", function () {
    var links = $("a.link-preview");
    var current = null;
    var hideTimer = null;
    // The pointer type and preview state at the start of the latest press on a link
    var pressPointerType = null;
    var pressFoundPreviewShown = false;

    // Without animation, hiding finishes immediately, so showing a preview again can't race a fade-out
    links.popover({
        trigger: "manual",
        placement: "auto",
        html: true,
        animation: false
    });

    function show(link) {
        cancelHide();
        if (current === link) return;
        hide();
        current = link;
        $(link).popover("show");
    }

    function hide() {
        cancelHide();
        if (current) $(current).popover("hide");
        current = null;
    }

    // Delay hiding so the mouse can travel from the link into the popover
    function scheduleHide() {
        clearTimeout(hideTimer);
        hideTimer = setTimeout(hide, 300);
    }

    function cancelHide() {
        clearTimeout(hideTimer);
    }

    links.on("pointerenter", function (e) {
        if (e.pointerType === "mouse") show(this);
    });
    links.on("pointerleave", function (e) {
        if (e.pointerType === "mouse") scheduleHide();
    });
    links.on("inserted.bs.popover", function () {
        $("#" + $(this).attr("aria-describedby"))
            .on("pointerenter", function (e) {
                if (e.pointerType === "mouse") cancelHide();
            })
            .on("pointerleave", function (e) {
                if (e.pointerType === "mouse") scheduleHide();
            });
    });

    // A first tap shows the preview; tapping the link again (or the title in the popover) navigates
    links.on("pointerdown", function (e) {
        pressPointerType = e.pointerType;
        pressFoundPreviewShown = current === this;
    });
    links.on("click", function (e) {
        var tapped = pressPointerType === "touch";
        pressPointerType = null;
        if (tapped && !pressFoundPreviewShown) {
            e.preventDefault();
            show(this);
        }
    });

    links.on("focus", function () {
        if (this.matches(":focus-visible")) show(this);
    });
    links.on("blur", function (e) {
        if (current === this && !$(e.relatedTarget).closest(".popover").length) hide();
    });
    $(document).on("keydown", function (e) {
        if (e.key === "Escape") hide();
    });

    // Hide the preview when tapping or clicking outside it and its link
    $(document).on("click", function (e) {
        if (!$(e.target).closest("a.link-preview, .popover").length) hide();
    });
});
