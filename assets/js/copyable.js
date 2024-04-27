function copyAction(event) {
    event.preventDefault();

    const clone = event.target.parentElement.cloneNode(true);
    clone.querySelector('.copy-button').remove();
    clone.querySelectorAll('[style*="display: none"]').forEach(function(element) {
        element.remove();
    });

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
