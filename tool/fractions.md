---
layout: page
title: Unicode Fraction Generator
excerpt_only: true
description: "I made a little tool to generate Unicode fractions"
---

Input an integer numerator and denominator to generate a Unicode fraction. Vulgar fractions and fraction numerators are used when available.

<div class="card">
    <div class="card-body">
        <form>
            <div class="row">
                <div id="numerator-container" class="col">
                    <input type="text" id="numerator" name="text" placeholder="Numerator" oninput="updateFract()" class="form-control" required />
                </div>
                <div id="denominator-container" class="col">
                    <input type="text" id="denominator" name="text" placeholder="Denominator" oninput="updateFract()" class="form-control" required />
                </div>
                <div id="result-container" class="form-group copyable col">
                    <input type="text" id="result" name="text" class="form-control" readonly />
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
    function updateFract() {
        const numerator = document.getElementById("numerator").value;
        const denominator = document.getElementById("denominator").value;

        const resultElement = document.getElementById('result');
        const copyButton = document.querySelector('.copyable button');
        if (isInteger(numerator) && isInteger(denominator)) {
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

            resultElement.value = result;
            copyButton.disabled = false;
        } else {
            resultElement.value = "";
            copyButton.disabled = true;
        }
    }

    document.addEventListener("DOMContentLoaded", function() {
        updateFract();
    });
</script>

Inspired by [Ben Schattinger](https://lights0123.com/fractions/).
