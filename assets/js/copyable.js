function copyAction(event) {
    event.preventDefault();

    const clone = event.target.parentElement.cloneNode(true);
    clone.querySelector('.copy-button').remove();

    // The clone and its elements are not styled by the browser
    // unless they are part of the document. Adding and removing
    // them synchronously should avoid them getting picked up by
    // the browser's rendering cycle.
    document.body.appendChild(clone);
    Array.from(clone.querySelectorAll('*')).forEach(function(element) {
        const style = window.getComputedStyle(element);
        if (
            style.display === 'none' ||
            style.visibility === 'hidden' ||
            style.opacity === '0'
        ) {
            element.remove();
        }
    });
    document.body.removeChild(clone);

    navigator.clipboard.writeText(clone.textContent.trim())
        .catch(err => console.error('Failed to copy content: ', err));

    $(event.target).popover('show');
    setTimeout(() => $(event.target).popover('hide'), 800);
}

document.addEventListener("DOMContentLoaded", function() {
    $('div.highlight').each(function() {
        this.classList.add("copyable");
    });
    $('.copyable').each(function() {
        let copyButton = document.createElement("button");
        copyButton.textContent = "Copy";
        copyButton.classList.add("btn", "btn-secondary", "btn-sm", "copy-button");
        copyButton.onclick = copyAction;
        $(copyButton).popover({
            content: "Copied",
            boundary: "viewport",
            trigger: "manual"
        });
        this.appendChild(copyButton);
    });
});
