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
        .then(() => {
            event.target.textContent = "Copied!";
            event.target.classList.remove("btn-outline-secondary");
            event.target.classList.add("btn-success");
            setTimeout(() => {
                event.target.textContent = "Copy";
                event.target.classList.remove("btn-success");
                event.target.classList.add("btn-outline-secondary");
            }, 2000);
        })
        .catch(err => console.error('Failed to copy content: ', err));
}

document.addEventListener("DOMContentLoaded", function() {
    // Make code blocks copyable
    $('div.highlight').each(function() {
        this.classList.add("copyable");
    });
    // Add copy buttons to copyable elements
    $('.copyable').each(function() {
        let copyButton = document.createElement("button");
        copyButton.textContent = "Copy";
        copyButton.classList.add("btn", "btn-outline-secondary", "btn-sm", "copy-button");
        copyButton.onclick = copyAction;
        this.appendChild(copyButton);
    });
});
