/* newsfoot originally published by Andrew Brehaut at https://gist.github.com/brehaut/567947031a477c89a7f89d96e38a908c
 *
 * This file is an adaptation of the version checked into NetNewsWire,
 * which has a more concrete license:
 *
 * MIT License
 *
 * Copyright (c) 2017-2022 Brent Simmons and Andrew Brehaut
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
// @ts-check
 (function () {
	/** @param {Node | null} el */
	const remove = (el) => { if (el) el.parentElement.removeChild(el) };

	const stripPx = (s) => +s.slice(0, -2);

	/** @param {string} tag
	 * @param {string} cls
	 * @returns HTMLElement
	 */
	function newEl(tag, cls) {
		const el = document.createElement(tag);
		el.classList.add(cls);
		return el;
	}

	/** @type {<T extends any[]>(fn: (...args: T) => void, t: number) => ((...args: T) => void)} */
	function debounce(f, ms) {
		let t = Date.now();
		return (...args) => {
			const now = Date.now();
			if (now - t < ms) return;
			t = now;
			f(...args);
		};
	}

	const clsPrefix = "newsfoot-footnote-";
	const CONTAINER_CLS = `${clsPrefix}container`;
	const POPOVER_CLS = `${clsPrefix}popover`;
    const POPOVER_INNER_CLS = `${clsPrefix}popover-inner`;
    const POPOVER_ARROW_CLS = `${clsPrefix}popover-arrow`;

	/**
	 * @param {string} content
	 * @returns {HTMLElement}
	 */
	function footnoteMarkup(content) {
		const popover = newEl("div", POPOVER_CLS);
		const arrow = newEl("div", POPOVER_ARROW_CLS);
        const inner = newEl("div", POPOVER_INNER_CLS);
		popover.appendChild(inner);
		popover.appendChild(arrow);
		inner.innerHTML = content;
		return popover;
	}

	class Footnote {
		/**
		 * @param {string} content
		 * @param {Element} fnref
		 */
		constructor(content, fnref) {
			this.popover = footnoteMarkup(content);
			this.style = window.getComputedStyle(this.popover);
			this.fnref = fnref;
			this.fnref.closest(`.${CONTAINER_CLS}`).insertBefore(this.popover, fnref);
			/** @type {HTMLElement} */
		    this.arrow = this.popover.querySelector(`.${POPOVER_ARROW_CLS}`);
			this.reposition();
  
			/** @type {(ev:MouseEvent) => void} */
			this.clickoutHandler = (ev) => {
				if (!(ev.target instanceof Element)) return;
				if (ev.target.closest(`.${POPOVER_CLS}`) === this.popover) return;
				if (ev.target === this.fnref) {
				    ev.stopPropagation();
					ev.preventDefault();
				}
				this.cleanup();
			}
			document.addEventListener("click", this.clickoutHandler, {capture: true});
  
			this.resizeHandler = debounce(() => this.reposition(), 20);
			window.addEventListener("resize", this.resizeHandler);
		}
  
		cleanup() {
			remove(this.popover);
			document.removeEventListener("click", this.clickoutHandler, {capture: true});
			window.removeEventListener("resize", this.resizeHandler);
			delete this.popover;
			delete this.clickoutHandler;
			delete this.resizeHandler;
		}
  
		reposition() {
			const refRect = this.fnref.getBoundingClientRect();
			const center = refRect.left + (refRect.width / 2);
			const popoverHalfWidth = this.popover.clientWidth / 2;
			const marginLeft = stripPx(this.style.marginLeft);
			const marginRight = stripPx(this.style.marginRight);
  
		    const rightOverhang = center + popoverHalfWidth + marginRight > window.innerWidth;
		    const leftOverhang = center - (popoverHalfWidth + marginLeft) < 0;
										   
			let offset = 0;
			if (!leftOverhang && rightOverhang) {
				offset = -((center + popoverHalfWidth + marginRight) - window.innerWidth);
			}
			else if (leftOverhang && !rightOverhang) {
				offset = (popoverHalfWidth + marginLeft) - center;
			}
			this.popover.style.transform = `translate(${offset}px)`;
			this.arrow.style.transform = `translate(${-offset}px) rotate(45deg)`;
		}
	}

	/** @param {HTMLAnchorElement} a */
	function installContainer(a) {
		if (!a.parentElement.matches(`.${CONTAINER_CLS}`)) {
			const container = newEl("div", CONTAINER_CLS);
			a.parentElement.insertBefore(container, a);
			container.appendChild(a);
		}
	}
			
	function idFromHash(target) {
		if (!target.hash) return;
		return decodeURIComponent(target.hash.substring(1));
	}
	/** @type {{fnref(target:HTMLAnchorElement): string|undefined}[]} */
	const footnoteFormats = [
		{ // Multimarkdown
			fnref(target) {
				if (!target.matches(".footnote")) return;
				return idFromHash(target);
			}
		}
	];
	
	// Handle clicks on the footnote reference
	document.addEventListener("click", (ev) => {
		if (!(ev.target && ev.target instanceof HTMLAnchorElement)) return;

		let targetId = undefined;
		for(const f of footnoteFormats) {
			targetId = f.fnref(ev.target);
			if (targetId) break;
		}
		if (targetId === undefined) return;
		
		// Only override the default behaviour when we know we can find the
		// target element
		const targetElement = document.getElementById(targetId);
		if (targetElement === null) return;
				
		ev.preventDefault();

		installContainer(ev.target);
				
		void new Footnote(targetElement.innerHTML, ev.target);
    });
										   
	// Handle clicks on the footnote reverse link
    document.addEventListener("click", (ev) =>
    {
	    if (!(ev.target && ev.target instanceof HTMLAnchorElement)) return;
        if (!ev.target.matches(".footnotes .reversefootnote, .footnotes .footnoteBackLink, .footnotes .footnote-return, .footnotes a[href*='#fn'], .footnotes a[href^='#']")) return;
		const id = idFromHash(ev.target);
		if (!id) return;
		const fnref = document.getElementById(id);

		window.scrollTo({ top: fnref.getBoundingClientRect().top + window.scrollY });
	    ev.preventDefault();
	});
}());
