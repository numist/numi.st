---
layout: page
title: Symbol Picker
---

The search box below uses [fuzzy matching](/post/2024/symbols). Click/tap on a symbol to copy it to your clipboard.

<div class="search-container">
    <input class="search" placeholder="Search symbols...">
    <button class="clear-btn" type="button">
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" fill="#808080"/>
            <g transform="translate(12, 12)">
                <path fill="#ffffff" stroke="#ffffff" d="M-3.3-3.3L3.3 3.3M3.3-3.3L-3.3 3.3"/>
            </g>
        </svg>
    </button>
</div>

<div class="symbols">
</div>

<script>
    const symbols = {
        "⌃": "Up Arrowhead (Control Key)",
        "⌥": "Option Key",
        "⇧": "Upwards White Arrow (Shift Key)",
        "⌘": "Place of Interest Sign (Command Key)",
        "←": "Leftwards Arrow",
        "→": "Rightwards Arrow",
        "↑": "Upwards Arrow",
        "↓": "Downwards Arrow",
        "⎋": "Broken Circle with Northwest Arrow (Escape Key)",
        "⇪": "Upwards White Arrow From Bar (Caps Lock)",
        "⏎": "Return Symbol",
        "⏏︎": "Eject Symbol",
        "⇥": "Righwards Arrow to Bar (Tab Right)",
        "⇤": "Leftwards Arrow to Bar (Tab Left)",
        "␣": "Open Box (Space Key)",
        "⌤": "Up Arrowhead Between Two Horizontal Bars (Enter Key)",
        "⌦": "Erase to the Right (Forward Delete)",
        "⌫": "Erase to the Left (Delete)",
        "↖︎": "North West Arrow (Home)",
        "↘︎": "South East Arrow (End)",
        "⇞": "Upwards Arrow with Double Stroke (Page Up)",
        "⇟": "Downwards Arrow with Double Stroke (Page Down)",
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
        "Δ": "Greek Capital Letter Delta",
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
        "≅": "Congruent To",
        "∝": "Proportional To",
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
        "〄": "Japanese Industrial Standard Symbol",
        "㉿": "Korean Standard Symbol",
        "⚡︎": "High Voltage Sign",
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
        "⅛": "Fraction One Eighth",
        "¼": "Fraction One Quarter",
        "⅜": "Fraction Three Eighths",
        "½": "Fraction One Half",
        "⅝": "Fraction Five Eighths",
        "¾": "Fraction Three Quarter",
        "⅞": "Fraction Seven Eighths",
        "⁄": "Fraction Slash",
        "℀": "Account Of",
        "℁": "Addressed To The Subject",
        "℅": "Care Of",
        "℆": "Cada Una",
        "∞": "Infinity",
        "£": "Pound Sign (Currency)",
        "€": "Euro Sign (Currency)",
        "¥": "Yen Sign (Currency)",
        "₩": "Won Sign (Currency)",
        "¢": "Cent Sign (Currency)",
        "¤": "Currency Sign",
        "œ": "Lowercase Ligature OE",
        "Œ": "Uppercase Ligature OE",
        "æ": "Lowercase Ligature AE",
        "Æ": "Uppercase Ligature AE",
        "‹": "Single Left-Pointing Angle Quotation Mark",
        "›": "Single Right-Pointing Angle Quotation Mark",
        "°": "Degree Sign",
        "℃": "Degree Celcius",
        "℉": "Degree Fahrenheit",
        "·": "Middle Dot (interpunct, centered dot)",
        "‚": "Single Low-9 Quotation Mark",
        "„": "Double Low-9 Quotation Mark",
        "№": "Numero Sign",
        "": "Private Use Area-F8FF (Apple Logo)",
        "℞": "Prescription Take (Rx)",
        "✔": "Check Mark (Ballot Check)",
        "✗": "Ballot X",
        "☐": "Ballot Box",
        "☑︎": "Ballot Box With Check",
        "☒": "Ballot Box With X",
        "☞": "White Right Pointing Index",
        "ℹ︎": "Information Source",
        "☃︎": "Snowman",
        "♠︎": "Black Spade Suit",
        "♣︎": "Black Club Suit",
        "♥︎": "Black Heart Suit",
        "♦︎": "Black Diamond Suit",
        "♚": "Black Chess King",
        "♛": "Black Chess Queen",
        "♜": "Black Chess Rook",
        "♝": "Black Chess Bishop",
        "♞": "Black Chess Knight",
        "♟": "Black Chess Pawn",
        "♔": "White Chess King",
        "♕": "White Chess Queen",
        "♖": "White Chess Rook",
        "♗": "White Chess Bishop",
        "♘": "White Chess Knight",
        "♙": "White Chess Pawn",
        "✈︎": "Airplane",
        "⚓︎": "Anchor",
        "‼︎": "Double Exclamation Mark",
        "⁇": "Double Question Mark",
        "⁈": "Question Exclamation Mark",
        "⁉︎": "Exclamation Question Mark",
        "‽": "Interrobang",
        "⸘": "Inverted Interrobang",
        "¡": "Inverted Exclamation Mark",
        "¿": "Inverted Question Mark",
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
    };

    document.addEventListener("DOMContentLoaded", () => {
        const inputElement = document.querySelector('.search');
        const clearBtn = document.querySelector('.clear-btn');

        inputElement.addEventListener('input', () => {
            updateMatches();
            clearBtn.style.display = inputElement.value ? 'block' : 'none';
        });

        clearBtn.addEventListener('click', () => {
            inputElement.value = '';
            clearBtn.style.display = 'none';
            updateMatches();
        });

        updateMatches();
    });

    function fuzzyMatch(haystack, needle) {
        let haystackIndex = 0;
        let needleIndex = 0;
        let haystackIndexLastMatch = -1;
        let matchGaps = [];

        haystack = haystack.toLowerCase();
        needle = needle.toLowerCase();

        while (haystackIndex < haystack.length && needleIndex < needle.length) {
            if (haystack[haystackIndex] === needle[needleIndex]) {
                if (haystackIndexLastMatch >= 0) {
                    // `haystackIndex - haystackIndexLastMatch - 1` may overrepresent
                    // the gap between matches due to greedy matching, so we search
                    // backwards to find the actual gap. This correction may be overly
                    // charitable if the haystack has multiple instances of the same
                    // character, but it's well worth the improvement in identifying
                    // exact matches.
                    //
                    // For example, the needle "note" should match "beamed sixteenth
                    // notes" with no gaps, but without this correction there would
                    // be a gap of 4 ("th n").
                    let gap = haystackIndex - haystackIndexLastMatch - 1;
                    for (let i = haystackIndex - 1; i > haystackIndexLastMatch; i--) {
                        if (haystack[i] === needle[needleIndex - 1]) {
                            gap = haystackIndex - i - 1;
                            break;
                        }
                    }
                    if (gap > 0) {
                        matchGaps.push(gap);
                    }
                }
                needleIndex++;
                haystackIndexLastMatch = haystackIndex;
            }
            haystackIndex++;
        }

        if (needleIndex !== needle.length) {
            // No match: not all needle characters were found in sequence
            return 0;
        }

        return 1 / matchGaps.map(gap => Math.log(gap + 1)).reduce((a, b) => a + b, 0);
    }

    function updateMatches() {
        const inputElement = document.querySelector('.search');
        const parent = document.querySelector(".symbols");
        let filteredSymbols = inputElement.value == "" ? symbols :
            Object.fromEntries(Object.entries(symbols)
                .map(([symbol, description]) => [symbol, { description, score: fuzzyMatch(description, inputElement.value) }])
                .filter(([symbol, { score }]) => score !== 0)
                .sort((a, b) => b[1].score - a[1].score)
                .map(([symbol, { description }]) => [symbol, description]));

        parent.innerHTML = "";
        for (const [symbol, description] of Object.entries(filteredSymbols)) {
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

</script>
