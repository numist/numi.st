---
layout: page
title: Link to Text Fragment Generator
---

Paste a URL and some text from the page into the fields below to generate a link[^ref] that will take you directly to that text when you click it.

<div class="card">
    <div class="card-header">
        <ul class="nav nav-tabs card-header-tabs" id="generatorTabs" role="tablist">
            <li class="nav-item">
                <a class="nav-link active" id="simple-tab" data-toggle="tab" href="#" role="tab" aria-controls="home" aria-selected="true">Simple</a>
            </li>
            <li class="nav-item">
                <a class="nav-link" id="start-end-tab" data-toggle="tab" href="#" role="tab" aria-controls="profile" aria-selected="false">Start…End</a>
            </li>
            <li class="nav-item">
                <a class="nav-link" id="advanced-tab" data-toggle="tab" href="#" role="tab" aria-controls="contact" aria-selected="false">Advanced</a>
            </li>
        </ul>
    </div>
    <div class="card-body">
        <div id="generator-help" class="card-text post-content"></div>
        <form>
            <div class="row">
                <div class="form-group mb-3">
                    <input type="text" id="url" name="url" placeholder="URL (Optional)" oninput="updateLink()" class="form-control" />
                </div>
            </div>
            <div id="text-inputs" class="row">
                <div id="prefix-container">
                    <input type="text" id="prefix" name="text" placeholder="Prefix (Optional)" oninput="updateLink()" class="form-control" />
                </div>
                <div id="start-container">
                    <input type="text" id="start" name="text" placeholder="" oninput="updateLink()" class="form-control" required />
                </div>
                <div id="end-container">
                    <input type="text" id="end" name="text" placeholder="End (Optional)" oninput="updateLink()" class="form-control" />
                </div>
                <div id="suffix-container">
                    <input type="text" id="suffix" name="text" placeholder="Suffix (Optional)" oninput="updateLink()" class="form-control" />
                </div>
            </div>
            <div class="row">
                <div id="link-container" class="form-group copyable">
                    <a id="link" href="#" class="form-control" target="_blank"></a>
                    <div id="link-placeholder" class="form-control placeholder-text"></div>
                </div>
            </div>
        </form>
    </div>
</div>

<script>
    function updateLink() {
        const url = document.getElementById("url").value;

        const prefix = document.getElementById("prefix").value;
        const start = document.getElementById("start").value;
        const end = document.getElementById("end").value;
        const suffix = document.getElementById("suffix").value;

        const selectedTab = $('#generatorTabs a.active').attr("id");

        const linkElement = document.getElementById('link');
        const placeholderElement = document.getElementById('link-placeholder');
        const copyButton = document.querySelector('.copyable button');
        if (start) {
            const encodedStart = encodeURIComponent(start);
            let link = `${encodedStart}`;
            if (end && selectedTab !== "simple-tab") {
                const encodedEnd = encodeURIComponent(end);
                link = `${link},${encodedEnd}`;
            }
            if (prefix && selectedTab === "advanced-tab") {
                const encodedPrefix = encodeURIComponent(prefix);
                link = `${encodedPrefix}-,${link}`;
            }
            if (suffix && selectedTab === "advanced-tab") {
                const encodedSuffix = encodeURIComponent(suffix);
                link = `${link},-${encodedSuffix}`;
            }
            link = `#:~:text=${link}`;

            if (url) {
                link = `${url.split("#")[0]}${link}`;
            }

            placeholderElement.style.display = "none";
            linkElement.style.display = "block";
            linkElement.href = link;
            linkElement.textContent = link;
            copyButton.disabled = false;
        } else {
            let missingFields = start ? "" : $('#start').attr("placeholder");
            linkElement.style.display = "none";
            copyButton.disabled = true;
            placeholderElement.style.display = "block";
            placeholderElement.textContent = "Fill required fields to generate link (missing: "+missingFields+")";
        }
    }

    document.addEventListener("DOMContentLoaded", function() {
        $('#generatorTabs a').on('click', function (e) {
            e.preventDefault()
            var tabElement = e.target;

            let textInputs = $('#text-inputs div');
            if (tabElement.id === "simple-tab") {
                $('#generator-help').html('Links to the first match of <code class="language-plaintext highlighter-rouge">Text</code> at the given URL.');
                textInputs.each(function() {
                    if (this.id === "start-container") {
                        this.style.display = "block";
                        this.classList = "form-group mb-3";
                        $('#start').attr("placeholder", "Text");
                    } else {
                        this.style.display = "none";
                    }
                });
            } else if (tabElement.id === "start-end-tab") {
                $('#generator-help').html('Links to the first block of text that starts with <code class="language-plaintext highlighter-rouge">Start</code> and ends with <code class="language-plaintext highlighter-rouge">End</code> at the given URL.');
                textInputs.each(function() {
                    if (this.id === "start-container") {
                        $('#start').attr("placeholder", "Start");
                        this.classList = "form-group mb-3 col-md-6";
                    } else if (this.id === "end-container") {
                        this.style.display = "block";
                        this.classList = "form-group mb-3 col-md-6";
                    } else {
                        this.style.display = "none";
                    }
                });
            } else if (tabElement.id === "advanced-tab") {
                $('#generator-help').html('Links to the first block of text that is preceded by <code class="language-plaintext highlighter-rouge">Prefix</code>, starts with <code class="language-plaintext highlighter-rouge">Start</code>, ends with <code class="language-plaintext highlighter-rouge">End</code>, and is followed by <code class="language-plaintext highlighter-rouge">Suffix</code> at the given URL.');
                textInputs.each(function() {
                    this.style.display = "block";
                    this.classList = "form-group mb-3 col-md-6 col-xl-3";
                    if (this.id === "start-container") {
                        $('#start').attr("placeholder", "Start");
                    }
                });
            } else {
                console.error("Unknown tab id: " + tabElement.id);
                return;
            }

            $('#generatorTabs a').each(function() {
                this.classList.remove("active");
                this.setAttribute("aria-selected", "false");
            });
            tabElement.classList.add("active");
            tabElement.setAttribute("aria-selected", "true");
            updateLink();
        });

        // Set up the initial state
        $('#generatorTabs a.active').click();
        updateLink();
    });
</script>

## Tips and Tricks

* There are browser extensions that will do this for you from right clicking a text selection on a page! That said, the reason I wrote this was because the ones I tried didn't work for me.

* Each of `Prefix`, `Start` (`Text`), `End`, and `Suffix` will only match text within a single block-level element, but `Start`...`End` ranges can span multiple blocks.

* You can specify multiple text fragments in a single URL by joining `text=…` parameters with `&`, like this: [`#:~:text=generate%20a%20link,-1&text=that-,text`](#:~:text=generate%20a%20link,-1&text=that-,text).

[^ref]: [_URL Fragment Text Directives_](https://wicg.github.io/scroll-to-text-fragment/). Draft Community Group Report, 13 December 2023
