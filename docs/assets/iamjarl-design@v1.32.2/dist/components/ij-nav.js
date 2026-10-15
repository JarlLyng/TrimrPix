// IAMJARL <ij-nav> v1.32.2: generated, do not edit
// Sources: components/nav-rules.js, components/labels.js, components/ij-nav.js

// The rules <ij-nav> enforces, kept out of the DOM so they are covered by the
// same dependency-free contract tests as the tokens. The element is a rendering
// shell over these, the way <ij-footer> is a shell over select-links.js.
//
// Pure: no DOM, no fetch, no globals.

// How opaque the bar is. Derived, not chosen: text sits on a translucent ground
// with the page scrolling underneath, so its background is whatever is behind
// it. Compositing the bar over the worst case (pure white under a dark bar,
// pure black under a light one) gives the opacity at which text.primary and
// text.secondary still clear AA: 0.58 in light mode, 0.64 in dark. A contract
// test re-derives both from color.js, so this value cannot drift below them.
//
// The family accent is deliberately NOT a text colour on the bar. Keeping an
// accent legible over the worst case needs 0.94, which leaves no translucency
// worth having; at 0.75 a teal link falls to 3.86:1. So the accent is carried by
// the dot and by the CTA's opaque fill, where it is safe at any opacity.
const NAV_ALPHA = 0.75;

// Below this width the links fold behind a disclosure button and the bar stays
// one row. The system's `md` breakpoint; a contract test holds them together.
const NAV_COLLAPSE_BELOW = 768;

// The top nav is for intent (DESIGN.md, "Rules for a site that sells an app").
const MAX_LINKS = 3;

// Obligations, not destinations: they belong in the footer.
const FOOTER_ONLY = /^\s*(privacy|support|terms|legal|imprint|contact)\b/i;

// A URL reduced to what identifies a page on a static site: no query, no hash,
// no trailing slash, no `index.html`, and `/page.html` equal to `/page` so that
// hosts serving clean URLs match the links written with the extension.
function pageKey(url) {
  let p = url.pathname.replace(/\/index\.html$/, '/').replace(/\.html$/, '');
  if (p.length > 1) p = p.replace(/\/$/, '');
  return `${url.origin}${p}`;
}

// Which of the links, if any, points at the page the visitor is on. Returns an
// index into `hrefs`, or -1. Links to another origin never match, and a link
// that only changes the hash (`#download`) is not a page.
function currentIndex(hrefs, here) {
  let at;
  try { at = new URL(here); } catch { return -1; }
  const key = pageKey(at);
  return hrefs.findIndex(href => {
    let u;
    try { u = new URL(href, at); } catch { return false; }
    if (u.origin !== at.origin) return false;
    if (u.hash) return false;   // an anchor on a page, not the page itself
    return pageKey(u) === key;
  });
}

// Whether the hero's CTA is on screen, from one IntersectionObserver callback.
// A callback can carry several entries for the same target: if the page
// scrolls before the first delivery (a visitor landing on /#download, say),
// the stale "on screen" entry and the fresh "gone" one arrive together. Only
// the last is current. Reading the first left the nav's CTA hidden for the
// rest of the visit. Returns null for an empty callback: nothing to decide.
function heroOnScreen(entries) {
  return entries.length ? entries[entries.length - 1].isIntersecting : null;
}

// What a site put in the nav that the rules say does not belong there. The
// element logs these as warnings rather than hiding anything: every link stays
// in light DOM for crawlers, and the site decides what to do about it.
//
//   content = {
//     brand:     number of slot="brand" elements,
//     links:     [{ text }],
//     cta:       [{ text, event, placement }]   // data-umami-* attributes
//     secondary: number of slot="secondary" elements,
//   }
function navWarnings({ brand = 0, links = [], cta = [], secondary = 0 }) {
  const out = [];
  if (brand === 0) {
    out.push('no slot="brand": the nav needs the site\'s name, linking home');
  } else if (brand > 1) {
    out.push(`${brand} elements in slot="brand"; use one`);
  }
  if (links.length > MAX_LINKS) {
    out.push(`${links.length} links; the top nav holds at most ${MAX_LINKS}; ` +
      'the rest belong on the page or in the footer');
  }
  for (const { text } of links) {
    if (FOOTER_ONLY.test(text ?? '')) {
      out.push(`"${text.trim()}" belongs in the footer: it is an obligation, not a destination`);
    }
  }
  if (cta.length > 1) {
    out.push(`${cta.length} elements in slot="cta"; the nav has one call to action`);
  }
  for (const { text, event, placement } of cta) {
    if (event && placement !== 'nav') {
      out.push(`the CTA "${(text ?? '').trim()}" reports placement="${placement ?? ''}"; ` +
        'use data-umami-event-placement="nav" so it can be told apart from the hero\'s');
    }
  }
  if (secondary > 1) {
    out.push(`${secondary} elements in slot="secondary"; use at most one`);
  }
  return out;
}

// The words <ij-nav> and <ij-footer> print themselves, in the languages the
// portfolio's sites are written in (#80), and the nav landmark's name (#88). Until 1.29.0 they were English on
// every page, so Wean's Danish, Swedish and Norwegian pages and WODrounds' six
// translations said "Menu" and "More from IAMJARL" in English.
//
// A component reads the language from the nearest lang attribute, so a Danish
// page gets Danish without setting anything. An attribute on the element
// (label, skip-label, menu-label, more-label, projects-label) overrides a word, for a
// language not listed here or a site's own phrasing. Anything unknown is English.
//
// Pure apart from langOf, which reads the DOM: the build imports labelsFor to
// write the footer fragments in each language.

const LABELS = {
  en: { nav: 'Main', skip: 'Skip to content', menu: 'Menu', more: 'More from IAMJARL', projects: 'All projects' },
  da: { nav: 'Hovedmenu', skip: 'Gå til indhold', menu: 'Menu', more: 'Mere fra IAMJARL', projects: 'Alle projekter' },
  de: { nav: 'Hauptmenü', skip: 'Zum Inhalt springen', menu: 'Menü', more: 'Mehr von IAMJARL', projects: 'Alle Projekte' },
  es: { nav: 'Menú principal', skip: 'Saltar al contenido', menu: 'Menú', more: 'Más de IAMJARL', projects: 'Todos los proyectos' },
  fr: { nav: 'Menu principal', skip: 'Aller au contenu', menu: 'Menu', more: 'Plus d’IAMJARL', projects: 'Tous les projets' },
  nb: { nav: 'Hovedmeny', skip: 'Gå til innhold', menu: 'Meny', more: 'Mer fra IAMJARL', projects: 'Alle prosjekter' },
  sv: { nav: 'Huvudmeny', skip: 'Till innehållet', menu: 'Meny', more: 'Mer från IAMJARL', projects: 'Alla projekt' },
};

// Norwegian pages are often marked "no" or "nn"; the words are Bokmål's.
const ALIASES = { no: 'nb', nn: 'nb' };

function labelsFor(lang) {
  const base = String(lang || 'en').toLowerCase().split(/[-_]/)[0];
  return LABELS[ALIASES[base] ?? base] ?? LABELS.en;
}

// The registry's link to the whole portfolio is a phrase, not a name, so it is
// the one cross-link that is translated.
const PROJECTS_ID = 'iamjarl';

const langOf = el => el.closest('[lang]')?.getAttribute('lang') || document.documentElement.lang || 'en';

// <ij-nav label="Main" skip-to="main" cta-after="#hero-cta">
//   <a slot="brand" href="/">Echolume</a>
//   <a slot="links" href="/how-it-works.html">How it works</a>
//   <a slot="links" href="/obs-guide.html">OBS Guide</a>
//   <a slot="cta" href="https://apps.apple.com/app/…"
//      data-umami-event="store-click" data-umami-event-placement="nav">Download</a>
//   <a slot="secondary" href="https://github.com/…">GitHub</a>
// </ij-nav>
//
// The shared site navigation. Unlike the footer it is not the same everywhere:
// it carries each site's name and its most important button, so it shares
// behaviour, not content. Every link is the site's own, in light DOM, in the
// served HTML: crawlers that do not run JavaScript see all of it, and without
// JavaScript it is a row of plain links.
//
// What the component owns:
//   - its own words in the page's language: the skip link's and the menu
//     button's, from the nearest lang attribute (components/labels.js), or
//     from skip-label and menu-label (#80)
//   - a <nav> landmark (aria-label from `label`, default "Main" in the page's
//     language) and a skip link
//     to #main (or the id in `skip-to`), rendered only if that target exists
//     and the page has no skip link of its own: a link to the same target
//     before the nav, such as the kit's .ij-skip, which works without
//     JavaScript. Two would be two tab stops that say the same (#84)
//   - aria-current="page" on the link for this page, unless the site set one
//   - sticky, translucent and blurred; solid where backdrop-filter is missing or
//     the visitor prefers reduced transparency
//   - below 768px, ONE row: brand and CTA stay, links and the secondary item
//     fold behind a disclosure button. Escape closes it and returns focus.
//   - `cta-after="<selector>"`: hide the nav's CTA while that element (the
//     hero's CTA) is on screen, so there is one call to action above the fold
//
// Theming is the two-tier pattern <ij-footer> uses: the host's tokens win, the
// fallbacks are the system's own values. The dot beside the wordmark and the
// CTA's fill use the site's accent where its identity sheet has one, the
// primary otherwise. The dot is omitted when the brand link carries its own mark (an
// <svg> or <img>), so a site with a logo does not get two.
//
// Order is DOM order, so focus follows what the eye sees: brand, links, the
// secondary item, then the CTA. At phone width the folded links move after the
// disclosure button, so Tab goes from the button into the menu it opened.


const NARROW = `(max-width: ${NAV_COLLAPSE_BELOW - 0.02}px)`;

// Phosphor, regular weight: the system's icon set (design.md).
const ICON_LIST = '<path d="M224,128a8,8,0,0,1-8,8H40a8,8,0,0,1,0-16H216A8,8,0,0,1,224,128ZM40,72H216a8,8,0,0,0,0-16H40a8,8,0,0,0,0,16ZM216,184H40a8,8,0,0,0,0,16H216a8,8,0,0,0,0-16Z"/>';
const ICON_X = '<path d="M205.66,194.34a8,8,0,0,1-11.32,11.32L128,139.31,61.66,205.66a8,8,0,0,1-11.32-11.32L116.69,128,50.34,61.66A8,8,0,0,1,61.66,50.34L128,116.69l66.34-66.35a8,8,0,0,1,11.32,11.32L139.31,128Z"/>';

const NAV_STYLE = `
:host {
  /* The host page wins if it has tokens; otherwise the system's own values.
     Never import tokens.shadow.css here; see COMPONENTS.md. */
  --_bg:        var(--ij-color-bg-app,         #FFFFFF);
  --_text:      var(--ij-color-text-secondary, rgba(0, 0, 0, 0.70));
  --_strong:    var(--ij-color-text-primary,   #000000);
  --_border:    var(--ij-color-border-subtle,  rgba(0, 0, 0, 0.10));
  --_border-hi: var(--ij-color-border-default, rgba(0, 0, 0, 0.16));
  --_card:      var(--ij-color-bg-card,        rgba(0, 0, 0, 0.04));
  --_accent:    var(--ij-color-accent, var(--ij-color-accent-family, var(--ij-color-primary, #A435D2)));
  --_on-accent: var(--ij-color-on-accent, var(--ij-color-on-primary, #FFFFFF));
  --_gap:       var(--ij-spacing-sm,    8px);
  --_gap-md:    var(--ij-spacing-lg,   16px);
  --_gap-lg:    var(--ij-spacing-xxxl, 32px);
  --_pad-y:     var(--ij-spacing-md,   12px);
  --_radius:    var(--ij-radius-md,    12px);
  --_focus:     var(--ij-focus-width,   2px);
  --_offset:    var(--ij-focus-offset,  2px);

  display: block;
  position: sticky;
  top: 0;
  z-index: var(--ij-z-sticky, 1100);
  color: var(--_text);
  font-size: var(--ij-font-size-base, 16px);
  line-height: var(--ij-line-height-base, 24px);
}

/* Only for hosts with no token layer at all. */
@media (prefers-color-scheme: dark) {
  :host {
    --_bg:        var(--ij-color-bg-app,         #000000);
    --_text:      var(--ij-color-text-secondary, rgba(255, 255, 255, 0.75));
    --_strong:    var(--ij-color-text-primary,   #FFFFFF);
    --_border:    var(--ij-color-border-subtle,  rgba(255, 255, 255, 0.12));
    --_border-hi: var(--ij-color-border-default, rgba(255, 255, 255, 0.18));
    --_card:      var(--ij-color-bg-card,        rgba(255, 255, 255, 0.05));
    --_accent:    var(--ij-color-accent, var(--ij-color-accent-family, var(--ij-color-primary, #D0FF00)));
    --_on-accent: var(--ij-color-on-accent, var(--ij-color-on-primary, #000000));
  }
}

.bar {
  display: flex;
  align-items: center;
  gap: var(--_gap-lg);
  padding: var(--_pad-y) var(--_gap-lg);
  background: var(--_bg);
  background: color-mix(in srgb, var(--_bg) ${NAV_ALPHA * 100}%, transparent);
  -webkit-backdrop-filter: blur(16px);
  backdrop-filter: blur(16px);
  border-bottom: 1px solid var(--_border);
}
/* Translucency without blur puts text over a sharp, moving page: go solid. */
@supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  .bar { background: var(--_bg); }
}
@media (prefers-reduced-transparency: reduce) {
  .bar { background: var(--_bg); -webkit-backdrop-filter: none; backdrop-filter: none; }
}

.brand { display: flex; align-items: center; gap: var(--_gap); margin-right: auto; min-width: 0; }
.dot {
  flex: none;
  width: 0.5em;
  height: 0.5em;
  border-radius: 50%;
  background: var(--_accent);
  box-shadow: 0 0 0.6em var(--_accent);
}
::slotted([slot="brand"]) {
  display: inline-flex;
  align-items: center;
  gap: var(--_gap);
  color: var(--_strong);
  font-family: var(--ij-font-display, inherit);
  font-variation-settings: var(--ij-font-display-axes, normal);
  font-size: var(--ij-font-size-lg, 18px);
  font-weight: var(--ij-font-weight-bold, 700);
  line-height: var(--ij-line-height-lg, 28px);
  text-decoration: none;
  white-space: nowrap;
}

.menu, .links { display: flex; align-items: center; gap: var(--_gap-lg); }

/* Never the accent as text: the bar is translucent, and an accent over the
   worst case falls below AA (see nav-rules.js). Hover and the current page go
   to text.primary, and the current page is underlined, so colour is not the
   only signal. */
::slotted([slot="links"]) {
  color: var(--_text);
  text-decoration: none;
  white-space: nowrap;
}
::slotted([slot="links"]:hover) { color: var(--_strong); }
/* An underline rather than a border: it follows the text, so it still reads
   as "this page" when the folded menu stretches each link to full width. */
::slotted([slot="links"][aria-current="page"]) {
  color: var(--_strong);
  text-decoration: underline;
  text-decoration-thickness: var(--_focus);
  text-underline-offset: 0.35em;
}

/* design.md's secondary button: card ground, subtle border, primary text. */
::slotted([slot="secondary"]) {
  display: inline-flex;
  align-items: center;
  gap: var(--_gap);
  padding: var(--_gap) var(--_gap-md);
  background: var(--_card);
  border: 1px solid var(--_border);
  border-radius: var(--_radius);
  color: var(--_strong);
  font-size: var(--ij-font-size-sm, 14px);
  line-height: var(--ij-line-height-sm, 20px);
  text-decoration: none;
  white-space: nowrap;
}
::slotted([slot="secondary"]:hover) { border-color: var(--_border-hi); }

/* design.md's primary button, on the site's accent, with the on-colour its
   identity sheet derives for it (#65). A sheet from before 1.22 has neither,
   so the button falls back to the family accent and onPrimary, which is
   background.app in both modes; every family accent cleared 4.5:1 on it. */
.cta { display: flex; transition: opacity var(--ij-duration-normal, 250ms), visibility var(--ij-duration-normal, 250ms); }
::slotted([slot="cta"]) {
  display: inline-flex;
  align-items: center;
  padding: var(--_gap) var(--_gap-md);
  background: var(--_accent);
  color: var(--_on-accent);
  border-radius: var(--_radius);
  font-size: var(--ij-font-size-sm, 14px);
  font-weight: var(--ij-font-weight-semibold, 600);
  line-height: var(--ij-line-height-sm, 20px);
  text-decoration: none;
  white-space: nowrap;
}
/* No invented hover colour (rule 8): the label underlines instead. */
::slotted([slot="cta"]:hover) { text-decoration: underline; text-underline-offset: 0.2em; }

/* cta-after: hidden but still holding its place, so nothing shifts when it
   returns. visibility also takes it out of the tab order. */
.bar.cta-held .cta { opacity: 0; visibility: hidden; }

.toggle {
  display: none;
  align-items: center;
  justify-content: center;
  min-width: 44px;
  min-height: 44px;
  padding: 0;
  margin: 0;
  border: 0;
  border-radius: var(--_radius);
  background: transparent;
  color: var(--_strong);
  cursor: pointer;
}
.toggle svg { width: 24px; height: 24px; }
.toggle .when-open { display: none; }
.bar.open .toggle .when-open { display: block; }
.bar.open .toggle .when-closed { display: none; }

.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}

.skip {
  position: absolute;
  top: var(--_gap);
  left: var(--_gap-md);
  z-index: 1;
  padding: var(--_gap) var(--_gap-md);
  background: var(--_bg);
  color: var(--_strong);
  border: 1px solid var(--_border-hi);
  border-radius: var(--_radius);
  text-decoration: none;
  transform: translateY(-200%);
}
.skip:focus { transform: none; }

/* The focus ring is text.primary, not the accent, for the same reason as the
   links: it has to clear 3:1 over whatever is under the bar. */
a:focus-visible, button:focus-visible, ::slotted(a:focus-visible) {
  outline: var(--_focus) solid var(--_strong);
  outline-offset: var(--_offset);
  border-radius: var(--ij-radius-sm, 8px);
}

@media ${NARROW} {
  .bar { gap: var(--_gap); padding: var(--_gap) var(--_gap-md); }
  .toggle { display: inline-flex; }
  .menu {
    display: none;
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    flex-direction: column;
    align-items: stretch;
    gap: var(--_gap-md);
    padding: var(--_gap) var(--_gap-md) var(--_gap-md);
    background: var(--_bg);
    border-bottom: 1px solid var(--_border);
    box-shadow: var(--ij-shadow-md, 0 4px 8px rgba(0, 0, 0, 0.08));
  }
  .bar.open .menu { display: flex; }
  .links { flex-direction: column; align-items: stretch; gap: 0; }
  ::slotted([slot="links"]) { padding-block: var(--_pad-y); }
  ::slotted([slot="secondary"]) { align-self: flex-start; }
}

@media (prefers-reduced-motion: reduce) {
  .cta { transition: none; }
}
.bar.instant .cta { transition: none; }
`;

const esc = s => String(s).replace(/[&<>"]/g, c =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

class IjNav extends HTMLElement {
  static observedAttributes = ['label', 'skip-to', 'cta-after', 'skip-label', 'menu-label'];

  constructor() {
    super();
    this._narrow = typeof matchMedia === 'function' ? matchMedia(NARROW) : null;
    this._onMedia = () => { this._close(); this._place(); };
    this._onKey = e => {
      if (e.key === 'Escape' && this._isOpen()) {
        this._close();
        this._toggle?.focus();
      }
    };
    this._onDocPointer = e => {
      if (this._isOpen() && !e.composedPath().includes(this)) this._close();
    };
  }

  connectedCallback() {
    this.render();
    this._narrow?.addEventListener('change', this._onMedia);
    this.addEventListener('keydown', this._onKey);
    document.addEventListener('pointerdown', this._onDocPointer);
  }

  disconnectedCallback() {
    this._narrow?.removeEventListener('change', this._onMedia);
    this.removeEventListener('keydown', this._onKey);
    document.removeEventListener('pointerdown', this._onDocPointer);
    this._observer?.disconnect();
  }

  attributeChangedCallback() {
    if (this.shadowRoot) this.render();
  }

  // Light-DOM children in each slot, read directly so the answer does not
  // depend on whether the shadow root has been painted yet.
  _slotted(name) {
    return [...this.children].filter(el => el.getAttribute('slot') === name);
  }

  render() {
    if (!this.shadowRoot) this.attachShadow({ mode: 'open' });

    const brand = this._slotted('brand');
    const links = this._slotted('links');
    const cta = this._slotted('cta');
    const secondary = this._slotted('secondary');

    // Its own words in the page's language (#80), the landmark's name too
    // (#88), unless the site sets them.
    const words = labelsFor(langOf(this));
    const label = this.getAttribute('label') || words.nav;
    const skipLabel = this.getAttribute('skip-label') || words.skip;
    const menuLabel = this.getAttribute('menu-label') || words.menu;
    const skipId = this.getAttribute('skip-to') || 'main';
    const skipTarget = document.getElementById(skipId);
    const pageSkips = skipTarget && [...document.querySelectorAll('a[href]')].some(a =>
      a.getAttribute('href') === '#' + skipId && (a.compareDocumentPosition(this) & Node.DOCUMENT_POSITION_FOLLOWING));
    const ownMark = brand.some(el => el.querySelector('svg, img'));
    const folds = links.length > 0 || secondary.length > 0;

    this.shadowRoot.innerHTML = `
      <style>${NAV_STYLE}</style>
      ${skipTarget && !pageSkips ? '<a class="skip" href="#' + esc(skipId) + '">' + esc(skipLabel) + '</a>' : ''}
      <nav class="bar" aria-label="${esc(label)}">
        <div class="brand">${ownMark ? '' : '<span class="dot" aria-hidden="true"></span>'}<slot name="brand"></slot></div>
        ${folds ? `
        <div class="menu" id="menu">
          <div class="links"><slot name="links"></slot></div>
          <slot name="secondary"></slot>
        </div>` : ''}
        <div class="cta"><slot name="cta"></slot></div>
        ${folds ? `
        <button class="toggle" type="button" aria-expanded="false" aria-controls="menu">
          <svg class="when-closed" viewBox="0 0 256 256" fill="currentColor" aria-hidden="true">${ICON_LIST}</svg>
          <svg class="when-open" viewBox="0 0 256 256" fill="currentColor" aria-hidden="true">${ICON_X}</svg>
          <span class="visually-hidden">${esc(menuLabel)}</span>
        </button>` : ''}
      </nav>`;

    const root = this.shadowRoot;
    this._bar = root.querySelector('.bar');
    this._menu = root.querySelector('.menu');
    this._ctaBox = root.querySelector('.cta');
    this._toggle = root.querySelector('.toggle');

    this._toggle?.addEventListener('click', () => (this._isOpen() ? this._close() : this._open()));
    this._menu?.addEventListener('click', e => {
      if (e.target.closest?.('a')) this._close();
    });
    root.querySelector('.skip')?.addEventListener('click', e => {
      e.preventDefault();
      this._skipTo(skipTarget);
    });

    this._markCurrent(links);
    this._place();
    this._watchHeroCta(cta.length > 0);

    for (const w of navWarnings({
      brand: brand.length,
      links: links.map(a => ({ text: a.textContent })),
      cta: cta.map(a => ({
        text: a.textContent,
        event: a.getAttribute('data-umami-event'),
        placement: a.getAttribute('data-umami-event-placement'),
      })),
      secondary: secondary.length,
    })) console.warn('[ij-nav]', w);
    if (!skipTarget) {
      console.warn('[ij-nav]', `no element with id="${skipId}" to skip to; ` +
        'give the main content that id, or set skip-to');
    }
  }

  // The site's own aria-current wins; otherwise mark the link for this page.
  _markCurrent(links) {
    if (this._marked && !links.includes(this._marked)) this._marked = null;
    if (links.some(a => a !== this._marked && a.hasAttribute('aria-current'))) return;
    this._marked?.removeAttribute('aria-current');
    this._marked = null;
    const i = currentIndex(links.map(a => a.href), location.href);
    if (i >= 0) {
      links[i].setAttribute('aria-current', 'page');
      this._marked = links[i];
    }
  }

  // The folded menu sits before the CTA on a wide screen and after the button
  // on a narrow one, so focus order always matches what the eye sees.
  _place() {
    if (!this._menu) return;
    if (this._narrow?.matches) this._toggle.after(this._menu);
    else this._ctaBox.before(this._menu);
  }

  _isOpen() { return this._bar?.classList.contains('open') ?? false; }

  _open() {
    this._bar.classList.add('open');
    this._toggle.setAttribute('aria-expanded', 'true');
  }

  _close() {
    if (!this._isOpen()) return;
    this._bar.classList.remove('open');
    this._toggle.setAttribute('aria-expanded', 'false');
  }

  // The bar is sticky, so a plain jump would land the target underneath it.
  _skipTo(target) {
    if (!target) return;
    if (!target.hasAttribute('tabindex') && target.tabIndex < 0) target.setAttribute('tabindex', '-1');
    target.focus({ preventScroll: true });
    const y = target.getBoundingClientRect().top + scrollY - this.getBoundingClientRect().height;
    scrollTo({ top: Math.max(0, y) });
  }

  // One call to action above the fold: while the hero's CTA is on screen, the
  // nav's waits.
  _watchHeroCta(hasCta) {
    this._observer?.disconnect();
    this._observer = null;
    this._bar.classList.remove('cta-held');
    const sel = this.getAttribute('cta-after');
    if (!sel || !hasCta || typeof IntersectionObserver !== 'function') return;
    let hero = null;
    try { hero = document.querySelector(sel); } catch { /* invalid selector */ }
    if (!hero) {
      console.warn('[ij-nav]', `cta-after="${sel}" matches nothing; the CTA stays visible`);
      return;
    }
    const height = Math.round(this.getBoundingClientRect().height);
    // Decide the first state now, before the bar paints. Left to the observer's
    // first callback, the CTA would paint, then fade out on every page load,
    // and stay focusable while it did. Measuring the hero has already computed
    // the CTA as visible, so the first change is made with transitions off.
    const r = hero.getBoundingClientRect();
    const onScreen = r.width + r.height > 0 && r.bottom > height && r.top < innerHeight;
    this._bar.classList.add('instant');
    this._bar.classList.toggle('cta-held', onScreen);
    getComputedStyle(this._ctaBox).visibility;   // commit it while instant
    const bar = this._bar;
    requestAnimationFrame(() => requestAnimationFrame(() => bar.classList.remove('instant')));
    this._observer = new IntersectionObserver(entries => {
      const onScreen = heroOnScreen(entries);
      if (onScreen !== null) this._bar.classList.toggle('cta-held', onScreen);
    }, { rootMargin: `-${height}px 0px 0px 0px` });
    this._observer.observe(hero);
  }
}

if (!customElements.get('ij-nav')) customElements.define('ij-nav', IjNav);
