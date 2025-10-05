---
layout: page
title: Fixed Point Visualization
excerpt_only: true
description: "A tool for debugging fixed-point integer representations"
published_at: Sat Oct 5 00:00:00 PDT 2025
---

A tool for exploring fixed-point integer representations with configurable integer and fractional bit widths.

<style>
    /* Make readonly divs behave like readonly inputs with proper overflow */
    .form-control#minValue,
    .form-control#maxValue,
    .form-control#epsilon {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }
</style>

<div class="card">
    <div class="card-body">
        <form>
            <div class="row mb-3">
                <div class="col-md-2">
                    <label class="form-label d-block">Signed?</label>
                    <div class="d-flex align-items-center" style="height: auto; min-height: calc(1.5em + 0.75rem + 2px); padding-left: calc(0.75rem + 1px);">
                        <div class="form-check mb-0">
                            <input type="checkbox" id="signed" class="form-check-input" onchange="updateFromControl()">
                        </div>
                    </div>
                </div>
                <div class="col-md-5">
                    <label for="intWidth" class="form-label">Integer Bit Width</label>
                    <input type="number" id="intWidth" class="form-control" min="0" max="63" value="8" oninput="updateFromControl()">
                </div>
                <div class="col-md-5">
                    <label for="fracWidth" class="form-label">Fractional Bit Width</label>
                    <input type="number" id="fracWidth" class="form-control" min="0" max="63" value="8" oninput="updateFromControl()">
                </div>
            </div>
            <div class="row mb-3">
                <div class="col-md-12">
                    <label for="decimal" class="form-label">Decimal Value</label>
                    <div class="form-group copyable">
                        <input type="text" id="decimal" class="form-control" placeholder="0" oninput="updateFromDecimal()" onblur="updateFromDecimal(true)" onkeydown="handleEnter(event, updateFromDecimal)">
                    </div>
                </div>
            </div>
            <div class="row mb-3">
                <div class="col-md-12">
                    <label for="hex" class="form-label">Hexadecimal Value</label>
                    <div class="form-group copyable">
                        <input type="text" id="hex" class="form-control" placeholder="0" oninput="updateFromHex()" onblur="updateFromHex(true)" onkeydown="handleEnter(event, updateFromHex)">
                    </div>
                </div>
            </div>
            <div class="row mb-3">
                <div class="col-md-12">
                    <label for="binary" class="form-label">Binary Value</label>
                    <div class="form-group copyable">
                        <input type="text" id="binary" class="form-control" placeholder="0" oninput="updateFromBinary()" onblur="updateFromBinary(true)" onkeydown="handleEnter(event, updateFromBinary)">
                    </div>
                </div>
            </div>
            <hr>
            <div class="row mb-2">
                <div class="col-md-4">
                    <label class="form-label">Minimum Value</label>
                    <div class="form-group copyable">
                        <div class="form-control" id="minValue">0</div>
                    </div>
                </div>
                <div class="col-md-4">
                    <label class="form-label">Maximum Value</label>
                    <div class="form-group copyable">
                        <div class="form-control" id="maxValue">0</div>
                    </div>
                </div>
                <div class="col-md-4">
                    <label class="form-label">Epsilon (smallest step)</label>
                    <div class="form-group copyable">
                        <div class="form-control" id="epsilon">0</div>
                    </div>
                </div>
            </div>
        </form>
    </div>
</div>

<script>
    // State management
    let shadowValue = 0n; // 64-bit shadow copy
    let updating = false; // Prevent circular updates
    let activeField = null; // Track which field is being edited
    let previousWidth = 16; // Track previous total width for sign extension

    function handleEnter(event, updateFunc) {
        if (event.key === 'Enter') {
            event.target.blur(); // Trigger the blur event
            updateFunc(true);
        }
    }

    function getQueryParam(name) {
        const params = new URLSearchParams(window.location.search);
        return params.get(name) || '';
    }

    function setQueryParams() {
        const intWidth = getIntWidth();
        const fracWidth = getFracWidth();
        const signed = isSigned();
        const raw = getCurrentRawValue();
        
        const params = new URLSearchParams();
        
        // Store bit widths in "int.frac" format
        if (intWidth > 0 || fracWidth > 0) {
            params.set('bits', `${intWidth}.${fracWidth}`);
        }
        
        // Store signed flag
        if (signed) {
            params.set('signed', '1');
        }
        
        // Store value as hex (most compact representation)
        if (raw !== 0n) {
            params.set('value', raw.toString(16));
        }
        
        const newUrl = window.location.pathname + (params.toString() ? '?' + params.toString() : '') + window.location.hash;
        window.history.replaceState({}, '', newUrl);
    }

    function getTotalWidth() {
        const intWidth = parseInt(document.getElementById('intWidth').value) || 0;
        const fracWidth = parseInt(document.getElementById('fracWidth').value) || 0;
        return Math.min(intWidth + fracWidth, 64);
    }

    function isSigned() {
        return document.getElementById('signed').checked;
    }

    function getIntWidth() {
        return parseInt(document.getElementById('intWidth').value) || 0;
    }

    function getFracWidth() {
        return parseInt(document.getElementById('fracWidth').value) || 0;
    }

    // Convert the current value to the active bit width (sign-extend or zero-extend/truncate)
    function adjustValueToWidth(value, fromWidth, toWidth, signed) {
        if (fromWidth === toWidth) return value;

        if (toWidth > fromWidth) {
            // Extending
            if (signed && fromWidth > 0) {
                // Sign extend
                const signBit = (value >> BigInt(fromWidth - 1)) & 1n;
                if (signBit) {
                    // Negative number - fill with 1s
                    const mask = (1n << BigInt(toWidth - fromWidth)) - 1n;
                    return value | (mask << BigInt(fromWidth));
                }
            }
            // Unsigned or positive signed - zero extend (already done)
            return value;
        } else {
            // Truncating
            const mask = (1n << BigInt(toWidth)) - 1n;
            return value & mask;
        }
    }

    // Get the current value as a signed or unsigned integer
    function getCurrentRawValue() {
        const totalWidth = getTotalWidth();
        if (totalWidth === 0) return 0n;

        let value = shadowValue;

        // Truncate to current width
        const mask = (1n << BigInt(totalWidth)) - 1n;
        value = value & mask;

        return value;
    }

    // Convert raw integer to decimal considering fractional bits
    function rawToDecimal(raw, signed, fracWidth) {
        const totalWidth = getTotalWidth();
        if (totalWidth === 0) return 0;

        let value = raw;

        // Handle signed values
        if (signed && totalWidth > 0) {
            const signBit = (value >> BigInt(totalWidth - 1)) & 1n;
            if (signBit) {
                // Negative number - compute two's complement
                const mask = (1n << BigInt(totalWidth)) - 1n;
                value = value - (mask + 1n);
            }
        }

        // Convert to decimal considering fractional part
        const divisor = Math.pow(2, fracWidth);
        return Number(value) / divisor;
    }

    // Convert decimal to raw integer considering fractional bits
    function decimalToRaw(decimal, fracWidth) {
        const multiplier = Math.pow(2, fracWidth);
        return BigInt(Math.round(decimal * multiplier));
    }

    function updateReadOnlyFields() {
        const totalWidth = getTotalWidth();
        const signed = isSigned();
        const fracWidth = getFracWidth();

        if (totalWidth === 0) {
            document.getElementById('minValue').textContent = '0';
            document.getElementById('maxValue').textContent = '0';
            document.getElementById('epsilon').textContent = '0';
            return;
        }

        // Calculate epsilon
        const epsilon = 1.0 / Math.pow(2, fracWidth);
        document.getElementById('epsilon').textContent = epsilon.toString();

        // Calculate min/max
        if (signed) {
            const maxRaw = (1n << BigInt(totalWidth - 1)) - 1n;
            const minRaw = -(1n << BigInt(totalWidth - 1));
            document.getElementById('maxValue').textContent = rawToDecimal(maxRaw, false, fracWidth).toString();
            document.getElementById('minValue').textContent = (Number(minRaw) / Math.pow(2, fracWidth)).toString();
        } else {
            const maxRaw = (1n << BigInt(totalWidth)) - 1n;
            document.getElementById('maxValue').textContent = rawToDecimal(maxRaw, false, fracWidth).toString();
            document.getElementById('minValue').textContent = '0';
        }
    }

    function updateAllFields(skipActiveField = true) {
        if (updating) return;
        updating = true;
        
        const raw = getCurrentRawValue();
        const totalWidth = getTotalWidth();
        const signed = isSigned();
        const fracWidth = getFracWidth();
        
        // Update decimal (skip if it's the active field)
        if (!skipActiveField || activeField !== 'decimal') {
            const decimal = rawToDecimal(raw, signed, fracWidth);
            document.getElementById('decimal').value = decimal.toString();
        }
        
        // Update hex (skip if it's the active field)
        if (!skipActiveField || activeField !== 'hex') {
            if (totalWidth > 0) {
                const hexDigits = Math.ceil(totalWidth / 4);
                document.getElementById('hex').value = raw.toString(16).toUpperCase().padStart(hexDigits, '0');
            } else {
                document.getElementById('hex').value = '0';
            }
        }
        
        // Update binary (skip if it's the active field)
        if (!skipActiveField || activeField !== 'binary') {
            if (totalWidth > 0) {
                document.getElementById('binary').value = raw.toString(2).padStart(totalWidth, '0');
            } else {
                document.getElementById('binary').value = '0';
            }
        }
        
        updateReadOnlyFields();
        
        updating = false;
        
        // Update URL parameters (unless we're still initializing)
        if (document.readyState === 'complete') {
            setQueryParams();
        }
    }

    function updateFromControl() {
        if (updating) return;

        const totalWidth = getTotalWidth();
        const signed = isSigned();

        // Adjust shadow value from previous width to new width
        shadowValue = adjustValueToWidth(shadowValue, previousWidth, totalWidth, signed);
        
        // Update the previous width for next time
        previousWidth = totalWidth;

        // Ensure shadow value fits in the new width
        if (totalWidth > 0) {
            const mask = (1n << BigInt(totalWidth)) - 1n;
            shadowValue = shadowValue & mask;
        } else {
            shadowValue = 0n;
        }

        updateAllFields();
    }

    function updateFromDecimal(forceUpdate = false) {
        if (updating) return;
        
        if (!forceUpdate) {
            activeField = 'decimal';
        }
        
        updating = true;
        
        const decimalStr = document.getElementById('decimal').value;
        if (decimalStr === '') {
            updating = false;
            if (forceUpdate) activeField = null;
            return;
        }
        
        const decimal = parseFloat(decimalStr);
        if (isNaN(decimal)) {
            updating = false;
            if (forceUpdate) activeField = null;
            return;
        }
        
        const fracWidth = getFracWidth();
        const totalWidth = getTotalWidth();
        const signed = isSigned();
        
        // Convert to raw
        let raw = decimalToRaw(decimal, fracWidth);
        
        // Handle negative numbers for signed types
        if (signed && raw < 0n && totalWidth > 0) {
            const mask = (1n << BigInt(totalWidth)) - 1n;
            raw = (mask + 1n) + raw; // Two's complement
        }
        
        // Mask to current width
        if (totalWidth > 0) {
            const mask = (1n << BigInt(totalWidth)) - 1n;
            raw = raw & mask;
        } else {
            raw = 0n;
        }
        
        shadowValue = raw;
        previousWidth = totalWidth; // Update previous width when value changes
        
        updating = false;
        
        if (forceUpdate) {
            activeField = null;
            updateAllFields(false);
        } else {
            updateAllFields(true);
        }
    }

    function updateFromHex(forceUpdate = false) {
        if (updating) return;
        
        if (!forceUpdate) {
            activeField = 'hex';
        }
        
        updating = true;
        
        const hexStr = document.getElementById('hex').value.replace(/[^0-9A-Fa-f]/g, '');
        if (hexStr === '') {
            updating = false;
            if (forceUpdate) activeField = null;
            return;
        }
        
        try {
            let raw = BigInt('0x' + hexStr);
            const totalWidth = getTotalWidth();
            
            // Mask to current width
            if (totalWidth > 0) {
                const mask = (1n << BigInt(totalWidth)) - 1n;
                raw = raw & mask;
            } else {
                raw = 0n;
            }
            
            shadowValue = raw;
            previousWidth = totalWidth; // Update previous width when value changes
            
            updating = false;
            
            if (forceUpdate) {
                activeField = null;
                updateAllFields(false);
            } else {
                updateAllFields(true);
            }
        } catch (e) {
            updating = false;
            if (forceUpdate) activeField = null;
        }
    }

    function updateFromBinary(forceUpdate = false) {
        if (updating) return;
        
        if (!forceUpdate) {
            activeField = 'binary';
        }
        
        updating = true;
        
        const binaryStr = document.getElementById('binary').value.replace(/[^01]/g, '');
        if (binaryStr === '') {
            updating = false;
            if (forceUpdate) activeField = null;
            return;
        }
        
        try {
            let raw = BigInt('0b' + binaryStr);
            const totalWidth = getTotalWidth();
            
            // Mask to current width
            if (totalWidth > 0) {
                const mask = (1n << BigInt(totalWidth)) - 1n;
                raw = raw & mask;
            } else {
                raw = 0n;
            }
            
            shadowValue = raw;
            previousWidth = totalWidth; // Update previous width when value changes
            
            updating = false;
            
            if (forceUpdate) {
                activeField = null;
                updateAllFields(false);
            } else {
                updateAllFields(true);
            }
        } catch (e) {
            updating = false;
            if (forceUpdate) activeField = null;
        }
    }

    // Initialize on page load
    document.addEventListener('DOMContentLoaded', function() {
        // Load from URL parameters if present
        const bitsParam = getQueryParam('bits');
        const signedParam = getQueryParam('signed');
        const valueParam = getQueryParam('value');
        
        // Parse bits parameter (format: "int.frac")
        if (bitsParam) {
            const parts = bitsParam.split('.');
            if (parts.length === 2) {
                const intWidth = parseInt(parts[0]);
                const fracWidth = parseInt(parts[1]);
                if (!isNaN(intWidth) && intWidth >= 0 && intWidth <= 63) {
                    document.getElementById('intWidth').value = intWidth;
                }
                if (!isNaN(fracWidth) && fracWidth >= 0 && fracWidth <= 63) {
                    document.getElementById('fracWidth').value = fracWidth;
                }
            }
        }
        
        // Set signed checkbox
        if (signedParam === '1') {
            document.getElementById('signed').checked = true;
        }
        
        // Load value
        if (valueParam) {
            try {
                shadowValue = BigInt('0x' + valueParam);
                const totalWidth = getTotalWidth();
                if (totalWidth > 0) {
                    const mask = (1n << BigInt(totalWidth)) - 1n;
                    shadowValue = shadowValue & mask;
                }
            } catch (e) {
                shadowValue = 0n;
            }
        }
        
        previousWidth = getTotalWidth(); // Initialize previous width
        updateAllFields();
        
        // Focus the decimal field if no value was loaded
        if (!valueParam) {
            document.getElementById('decimal').focus();
        }
    });
</script>

## About Fixed-Point Numbers

Fixed-point numbers represent fractional values using integer arithmetic by allocating a fixed number of bits to the fractional part. For example, with 8 integer bits and 8 fractional bits:
- The value `3.25` is stored as `832` (3 × 256 + 0.25 × 256)
- In binary: `00000011.01000000`
- In hex: `0x0340`

This representation is commonly used in embedded systems, digital signal processing, and situations where floating-point arithmetic is unavailable or too expensive.
