---
layout: page
---

<input class="search">

<div class="symbols">
</div>

<script>
    const symbols = {
        "←": "Leftwards Arrow",
        "→": "Rightwards Arrow",
        "↑": "Upwards Arrow",
        "↓": "Downwards Arrow",
        "⌘": "Place of Interest Sign (Command Key)",
        "⎋": "Broken Circle with Northwest Arrow (Escape Key)",
        "⏎": "Return Symbol",
        "⏏︎": "Eject Symbol",
        "⇥": "Righwards Arrow to Bar (Tab Right)",
        "⇤": "Leftwards Arrow to Bar (Tab Left)",
        "⇪": "Upwards White Arrow From Bar (Caps Lock)",
        "⇧": "Upwards White Arrow (Shift Key)",
        "⌥": "Option Key",
        "␣": "Open Box (Space Key)",
        "⌃": "Up Arrowhead (Control Key)",
        "⌤": "Up Arrowhead Between Two Horizontal Bars (Enter Key)",
        "⌦": "Erase to the Right (Forward Delete)",
        "⌫": "Erase to the Left (Delete)",
        "↖︎": "North West Arrow (Home)",
        "↘︎": "South East Arrow (End)",
        "⇞": "Upwards Arrow with Double Stroke (Page Up)",
        "⇟": "Downwards Arrow with Double Stroke (Page Down)",
        "¡": "Inverted Exclamation Mark",
        "¿": "Inverted Question Mark",
        "§": "Section Sign",
        "¶": "Pilcrow Sign (Paragraph)",
        "•": "Bullet",
        "ª": "Feminine Ordinal Indicator",
        "º": "Masculine Ordinal Indicator",
        "≥": "Greater-Than or Equal To",
        "≤": "Less-Than or Equal To",
        "≠": "Not Equal To",
        "≈": "Almost Equal To",
        "⨉": "N-ary Times Operator",
        "×": "Multiplication Sign",
        "÷": "Division Sign",
        "√": "Square Root",
        "−": "Minus Sign",
        "±": "Plus-Minus Sign",
        "∑": "N-ary Summation",
        "π": "Greek Small Letter Pi",
        "ε": "Greek Small Letter Epsilon",
        "α": "Greek Small Letter Alpha",
        "β": "Greek Small Letter Beta",
        "θ": "Greek Small Letter Theta",
        "ɸ": "Greek Small Letter Phi",
        "σ": "Greek Small Letter Sigma",
        "∈": "Element Of",
        "∉": "Not Element Of",
        "∩": "Intersection",
        "∪": "Union",
        "∀": "For All",
        "∁": "Complement",
        "∂": "Partial Differential",
        "℮": "Estimated Symbol",
        "∃": "There Exists",
        "∄": "There Does Not Exist",
        "∅": "Empty Set",
        "⊂": "Subset Of",
        "⊃": "Superset Of",
        "⊄": "Not a Subset Of",
        "⊅": "Not a Superset Of",
        "⊆": "Subset Of or Equal To",
        "⊇": "Superset Of or Equal To",
        "⊈": "Not a Subset Of or Equal To",
        "⊉": "Not a Superset Of or Equal To",
        "⊊": "Subset Of With Not Equal To",
        "⊋": "Superset Of With Not Equal To",
        "∋": "Contains as Member",
        "∌": "Does Not Contain as Member",
        "∧": "Logical And",
        "∨": "Logical Or",
        "≪": "Much Less Than",
        "≫": "Much Greater Than",
        "∏": "N-ary Product",
        "∐": "N-ary Coproduct",
        "∕": "Division Slash",
        "∛": "Cube Root",
        "∟": "Right Angle",
        "∠": "Angle",
        "∡": "Measured Angle",
        "∥": "Parallel To",
        "∦": "Not Parallel To",
        "∴": "Therefore",
        "∵": "Because",
        "∶": "Ratio",
        "∷": "Proportion",
        "∿": "Sine Wave",
        "≃": "Approximately Equal To",
        "⌀": "Diameter Sign",
        "µ": "Micro Sign",
        "Ω": "Ohm Sign",
        "㏀": "Square K Ohm",
        "㏁": "Square M Ohm",
        "Σ": "Greek Capital Letter Sigma",
        "‐": "Hyphen",
        "–": "En Dash",
        "—": "Em Dash",
        "‰": "Per Mille Sign (Per Thousand)",
        "‱": "Per Ten Thousand Sign",
        "✄": "Cut Above",
        "✪": "Circled White Star",
        "♻︎": "Recycling Symbol",
        "ƒ": "Function",
        "●": "Black Circle",
        "◼︎": "Black Medium Square",
        "♪": "Eighth Note",
        "♫": "Beamed Eighth Notes",
        "♯": "Music Sharp Sign",
        "♭": "Music Flat Sign",
        "♮": "Music Natural Sign",
        "♩": "Quarter Note",
        "♬": "Beamed Sixteenth Notes",
        "𝄞": "Musical Symbol G Clef (Treble Clef)",
        "𝄢": "Musical Symbol F Clef (Bass Clef)",
        "𝄡": "Musical Symbol C Clef",
        "𝄆": "Musical Symbol Left Repeat Sign",
        "𝄇": "Musical Symbol Right Repeat Sign",
        "▶︎": "Black Right-Pointing Triangle",
        "©": "Copyright",
        "®": "Registered Trademark",
        "™": "Trademark",
        "“": "Left Double Quotation Mark",
        "”": "Right Double Quotation Mark",
        "‘": "Left Single Quotation Mark",
        "’": "Right Single Quotation Mark",
        "£": "Pound Sign",
        "⅛": "One Eighth",
        "¼": "One Quarter",
        "⅜": "Three Eighths",
        "½": "Half",
        "⅝": "Five Eighths",
        "¾": "Three Quarter",
        "⅞": "Seven Eighths",
        "∞": "Infinity",
        "€": "Euro Sign",
        "¥": "Yen Sign",
        "₩": "Won Sign",
        "¢": "Cent Sign",
        "¤": "Currency Sign",
        "œ": "Lowercase Ligature OE",
        "Œ": "Uppercase Ligature OE",
        "æ": "Lowercase AE",
        "Æ": "Uppercase AE",
        "✔": "Check Mark",
        "⁄": "Fraction Slash",
        "‹": "Single Left-Pointing Angle Quotation Mark",
        "›": "Single Right-Pointing Angle Quotation Mark",
        "°": "Degree Sign",
        "·": "Middle Dot",
        "‚": "Single Low-9 Quotation Mark",
        "„": "Double Low-9 Quotation Mark",
        "№": "Numero Sign",
        "": "Private Use Area-F8FF (Apple Logo)",
        "℞": "Prescription Take (Rx)",
        "⁰": "Superscript Zero",
        "¹": "Superscript One",
        "²": "Superscript Two",
        "³": "Superscript Three",
        "⁴": "Superscript Four",
        "⁵": "Superscript Five",
        "⁶": "Superscript Six",
        "⁷": "Superscript Seven",
        "⁸": "Superscript Eight",
        "⁹": "Superscript Nine",
        "ⁱ": "Superscript Small Letter I",
        "ᵃ": "Superscript Small Letter A",
        "ᵇ": "Superscript Small Letter B",
        "ᶜ": "Superscript Small Letter C",
        "ᵈ": "Superscript Small Letter D",
        "ᵉ": "Superscript Small Letter E",
        "ᶠ": "Superscript Small Letter F",
        "ᵍ": "Superscript Small Letter G",
        "ʰ": "Superscript Small Letter H",
        "ⁱ": "Superscript Small Letter I",
        "ʲ": "Superscript Small Letter J",
        "ᵏ": "Superscript Small Letter K",
        "ˡ": "Superscript Small Letter L",
        "ᵐ": "Superscript Small Letter M",
        "ⁿ": "Superscript Small Letter N",
        "ᵒ": "Superscript Small Letter O",
        "ᵖ": "Superscript Small Letter P",
        "ʳ": "Superscript Small Letter R",
        "ˢ": "Superscript Small Letter S",
        "ᵗ": "Superscript Small Letter T",
        "ᵘ": "Superscript Small Letter U",
        "ᵛ": "Superscript Small Letter V",
        "ʷ": "Superscript Small Letter W",
        "ˣ": "Superscript Small Letter X",
        "ʸ": "Superscript Small Letter Y",
        "ᶻ": "Superscript Small Letter Z",
        "₀": "Subscript Zero",
        "₁": "Subscript One",
        "₂": "Subscript Two",
        "₃": "Subscript Three",
        "₄": "Subscript Four",
        "₅": "Subscript Five",
        "₆": "Subscript Six",
        "₇": "Subscript Seven",
        "₈": "Subscript Eight",
        "₉": "Subscript Nine",
        "₊": "Subscript Plus Sign",
        "₋": "Subscript Minus Sign",
        "₌": "Subscript Equals Sign",
        "₍": "Subscript Left Parenthesis",
        "₎": "Subscript Right Parenthesis",
        "ₐ": "Subscript Small Letter A",
        "ₑ": "Subscript Small Letter E",
        "ₒ": "Subscript Small Letter O",
        "ₓ": "Subscript Small Letter X",
        "ₔ": "Subscript Small Letter Schwa",
        "ₕ": "Subscript Small Letter H",
        "ₖ": "Subscript Small Letter K",
        "ₗ": "Subscript Small Letter L",
        "ₘ": "Subscript Small Letter M",
        "ₙ": "Subscript Small Letter N",
        "ₚ": "Subscript Small Letter P",
        "ₛ": "Subscript Small Letter S",
        "ₜ": "Subscript Small Letter T",
        "₊": "Subscript Plus Sign",
        "₋": "Subscript Minus Sign",
        "₌": "Subscript Equals Sign",
        "₍": "Subscript Left Parenthesis",
        "₎": "Subscript Right Parenthesis",
        "‽": "Interrobang",
    };

    document.addEventListener("DOMContentLoaded", () => {
        const inputElement = document.querySelector('.search');
        inputElement.addEventListener('input', function() { updateMatches(); });

        updateMatches();
    });

    function fuzzyMatch(target, query) {
        let targetIndex = 0; // Index to track position in target
        let queryIndex = 0;  // Index to track position in query

        target = target.toLowerCase(); // Normalize target string
        query = query.toLowerCase();   // Normalize query string

        while (targetIndex < target.length && queryIndex < query.length) {
            if (target[targetIndex] === query[queryIndex]) {
            queryIndex++; // Move to the next character in the query
            }
            targetIndex++; // Always move to the next character in the target
        }

        return queryIndex === query.length; // Check if all query characters were found in sequence
    }

    function updateMatches() {
        const inputElement = document.querySelector('.search');
        const parent = document.querySelector(".symbols");
        parent.innerHTML = "";
        for (const [symbol, description] of Object.entries(symbols)) {
            if (inputElement.value == "" || fuzzyMatch(description, inputElement.value)) {
                const elem = document.createElement("div");
                elem.classList = "symbol";
                elem.textContent = symbol;
                elem.title = description;
                elem.addEventListener("click", () => {
                    const symbol = elem.textContent;
                    navigator.clipboard.writeText(symbol);

                    elem.textContent = "Copied!";
                    elem.classList = "symbol-clicked";

                    setTimeout(() => {
                        elem.textContent = symbol;
                        elem.classList = "symbol";
                    }, 1000);
                });
                parent.appendChild(elem);
            }
        }
    }

</script>
