---
layout: page
title: Unicode Fraction Generator
excerpt_only: true
description: "I made a little tool to generate Unicode fractions"
published_at: Fri Mar 21 14:49:09 PDT 2025
---

Input a fraction in the format "numerator/denominator" to generate a Unicode fraction. [Vulgar fractions and fraction numerators](/symbols/?q=Fraction) are used when available.

<div class="card">
    <div class="card-body">
        <form>
            <div class="row">
                <div class="col">
                    <input type="text" id="fraction" name="text" placeholder="1/2" oninput="updateFract()" class="form-control" required />
                </div>
                <div id="result-container" class="form-group copyable col">
                    <input type="text" id="result" name="text" class="form-control" placeholder="½" readonly />
                </div>
            </div>
        </form>
    </div>
</div>

<script>
    function isInteger(num) { return parseInt(num) == num }
    function superscript(num) {
        const superscriptDigits = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹'];
        return String(num).split('').map(digit => superscriptDigits[parseInt(digit)]).join('')
    }
    function subscript(num) {
        const subscriptDigits = ['₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉'];
        return String(num).split('').map(digit => subscriptDigits[parseInt(digit)]).join('')
    }
    function getQueryParam(name) {
        const params = new URLSearchParams(window.location.search);
        return params.get(name) || '';
    }
    function setQueryParam(name, value) {
        const params = new URLSearchParams(window.location.search);
        if (value) {
            params.set(name, value);
        } else {
            params.delete(name);
        }
        const newUrl = window.location.pathname + (params.toString() ? '?' + params.toString() : '') + window.location.hash;
        window.history.replaceState({}, '', newUrl);
    }
    function updateFract() {
        const input = document.getElementById("fraction").value;
        const parts = input.split('/');

        const resultElement = document.getElementById('result');
        const copyButton = document.querySelector('.copyable button');

        var result;
        var copyable = false;

        if (!input) {
            // Empty case
            result = "";
        }
        else if (
            parts.length > 2 || parts.length <= 0 ||
            (parts.length >= 1 && !isInteger(parts[0]) && parts[0] != "") ||
            (parts.length >= 2 && !isInteger(parts[1]) && parts[1] != "")
        ) {
            // Error case
            result = "(invalid)";
        }
        else if (
            isInteger(parts[0]) &&
            (parts.length == 1 || parts[1] == "")
        ) {
            // Incomplete case (numerator only)
            const numerator = parts[0];
            if (numerator == 1 && parts.length == 2) {
                result = "⅟";
            } else {
                result = superscript(numerator);
                if (parts.length == 2) {
                    result = `${result}⁄`;
                }
            }
        }
        else {
            // Complete fraction
            const numerator = parts[0];
            const denominator = parts[1];

            if (numerator == 0 && denominator == 3) { result = "↉"; }
            else if (numerator == 1 && denominator == 2) { result = "½"; }
            else if (numerator == 1 && denominator == 3) { result = "⅓"; }
            else if (numerator == 2 && denominator == 3) { result = "⅔"; }
            else if (numerator == 1 && denominator == 4) { result = "¼"; }
            else if (numerator == 3 && denominator == 4) { result = "¾"; }
            else if (numerator == 1 && denominator == 5) { result = "⅕"; }
            else if (numerator == 2 && denominator == 5) { result = "⅖"; }
            else if (numerator == 3 && denominator == 5) { result = "⅗"; }
            else if (numerator == 4 && denominator == 5) { result = "⅘"; }
            else if (numerator == 1 && denominator == 6) { result = "⅙"; }
            else if (numerator == 5 && denominator == 6) { result = "⅚"; }
            else if (numerator == 1 && denominator == 7) { result = "⅐"; }
            else if (numerator == 1 && denominator == 8) { result = "⅛"; }
            else if (numerator == 3 && denominator == 8) { result = "⅜"; }
            else if (numerator == 5 && denominator == 8) { result = "⅝"; }
            else if (numerator == 7 && denominator == 8) { result = "⅞"; }
            else if (numerator == 1 && denominator == 9) { result = "⅑"; }
            else if (numerator == 1 && denominator == 10) { result = "⅒"; }
            else {
                if (numerator == 1) { result = "⅟"; }
                else { result = `${superscript(numerator)}⁄`; }
                result = `${result}${subscript(denominator)}`;
            }
            copyable = true;
        }

        resultElement.value = result;
        resultElement.textContent = result;
        if (copyButton) {
            copyButton.disabled = !copyable;
        }
    }

    document.addEventListener("DOMContentLoaded", function() {
        // Prepopulate input from ?q= param
        const inputElement = document.getElementById("fraction");
        const initialQuery = decodeURIComponent(getQueryParam('q'));
        if (initialQuery) {
            inputElement.value = initialQuery;
        }
        updateFract();
        inputElement.focus();
        inputElement.addEventListener('input', function() {
            setQueryParam('q', encodeURIComponent(inputElement.value));
            updateFract();
        });
    });
</script>

Inspired by [Ben Schattinger](https://lights0123.com/fractions/).
