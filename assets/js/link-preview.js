// ABOUTME: Shows the build-time preview (favicon, page title, and any quote) of links as a popover:
// ABOUTME: on hover for mice, on first tap for touch, and on keyboard focus.

window.addEventListener("load", function () {
    var links = $("a.link-preview");
    var current = null;
    var shownByHover = false;
    var hideTimer = null;
    // The pointer type and preview state at the start of the latest press on a link
    var pressPointerType = null;
    var pressFoundPreviewShown = false;

    // Without animation, hiding finishes immediately, so showing a preview again can't race a fade-out.
    // Previews quote text fragments in a blockquote, which the sanitizer otherwise removes.
    links.popover({
        trigger: "manual",
        placement: "auto",
        html: true,
        animation: false,
        allowList: Object.assign({}, bootstrap.Popover.Default.allowList, { blockquote: [] })
    });

    // Records why the preview is showing, so a preview that keyboard focus took over from a hover
    // isn't hidden by the mouse moving away
    function show(link, byHover) {
        cancelHide();
        shownByHover = byHover;
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

    // Delay hiding so the mouse can travel from the link into the popover. A pending hide isn't
    // restarted, so a mouse that keeps moving elsewhere can't postpone it forever.
    function scheduleHide() {
        if (hideTimer === null) hideTimer = setTimeout(hide, 300);
    }

    function cancelHide() {
        clearTimeout(hideTimer);
        hideTimer = null;
    }

    function isInCurrentPopover(target) {
        var popover = document.getElementById($(current).attr("aria-describedby"));
        return popover !== null && popover.contains(target);
    }

    // Mouse hover is decided from wherever the mouse is on each move, never from enter/leave events:
    // those are missed when the mouse moves while another window covers the page, or when it warps,
    // and the next move corrects the state either way.
    $(document).on("pointermove", function (e) {
        if (e.pointerType !== "mouse") return;
        var link = $(e.target).closest("a.link-preview")[0];
        if (link && links.is(link)) {
            show(link, true);
        } else if (current && isInCurrentPopover(e.target)) {
            cancelHide();
        } else if (current && shownByHover) {
            scheduleHide();
        }
    });

    // A first tap (with a finger or pen) shows the preview; tapping the link again (or the title in the popover) navigates
    links.on("pointerdown", function (e) {
        pressPointerType = e.pointerType;
        pressFoundPreviewShown = current === this;
    });
    // A press that ends in a scroll or long-press never clicks
    links.on("pointercancel", function () {
        pressPointerType = null;
    });
    links.on("click", function (e) {
        var pointerType = pressPointerType;
        pressPointerType = null;
        // Keyboard activation clicks with a detail of 0 and has no pointer position
        var tapped = e.detail !== 0 && (pointerType === "touch" || pointerType === "pen");
        // Browsers can deliver a mouse click to a link the pointer isn't over (seen in Safari after
        // missed pointer events), so a mouse click only follows the link if the pointer is really on it.
        if (e.detail !== 0 && !tapped && !this.contains(document.elementFromPoint(e.clientX, e.clientY))) {
            e.preventDefault();
            hide();
            return;
        }
        if (tapped && !pressFoundPreviewShown) {
            e.preventDefault();
            show(this, false);
        }
    });

    links.on("focus", function () {
        if (this.matches(":focus-visible")) show(this, false);
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
