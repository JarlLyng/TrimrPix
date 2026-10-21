# App Store screenshots and listing

What goes into App Store Connect, per release. Not the website's images, which are in `docs/`
and served by GitHub Pages. Nothing in this folder is published by Pages.

```
appstore/
  manifest.json     the poster set: which capture, which caption, which slot
  raw/              the window captures the posters are made from
  <version>/        what is uploaded for that release: mac-*.png, and listing.md for the text
```

Current: **`1.7.3/`**, four posters at 2880 × 1800 (the Mac's largest slot, which Apple scales
down from), RGB without alpha, and `listing.md`.

## The captures

Taken with the capture mode in Debug builds (`TrimrPix/ScreenshotMode.swift`, #88), on the
site's sample of CC0 iPhone photos (`tools/redesign/fetch_sample.py`), light, active and at 2x.
The window is 1280 × 810 points for 1 and 4, tall enough to show all six files without
scrolling, and 1280 × 720 for 2 and 3, where the Settings sheet is the subject. The usage,
including the build without the sandbox it needs to read a folder, is at the top of
`ScreenshotMode.swift`. The four states:

1. Six photos after Optimize All, at Medium, resized to 2048 px (`-screenshotOptimize YES
   -resizeEnabled YES -maxDimension 2048`).
2. Settings at the defaults, over the thirty photos just dropped in (`-screenshotSettings YES`).
3. Settings scrolled to Watch Folder, turned on (`-screenshotSettingsAtEnd YES
   -watchFolderEnabled YES -watchFolderPath /Users/Shared/Screenshots`).
4. One file per format, just dropped in: a HEIC, an AVIF and an image PDF made from the sample
   photos with `sips`, a GIF of the app's own window, a PNG screenshot of it, and a JPEG.

## The posters

Composed with the hub's `tools/appstore_screenshots.py`. 1.7.3's set is on the dark ground with
`#D0FF00`, the standard at the time:

```sh
<hub>/.venv/bin/python <hub>/tools/appstore_screenshots.py batch appstore/manifest.json
```

The captions are public copy, so the hub's `VOICE.md` applies: no em-dashes, no hype, and no
claim the app can't back. A number states its condition, so "79% smaller" says "when resized
for the web" (the site's measured sample, #86).

### From the next version: the site's light identity

**The owner's decision, 2026-10-22** (the hub's `DESIGN.md`, 1411e50): the posters take the
website's light look from the next version on, and replace 1.7.3's dark set then, not before.

- **Ground** `#F1F0F6`, the site's. **Caption text** `#1C1B22`.
- **Lime `#D0FF00` only as a highlighter chip behind black text**, as on the site's "Keep
  quality.". **Never lime text on the light ground.**
- **Accent text, where a caption needs it, is olive `#4A5900`.**

In the manifest that is:

```json
"mode": "light", "ground": "#F1F0F6", "text": "#1C1B22",
"accent": "#D0FF00", "chip_text": "#000000"
```

The tool draws a `[chip]`, an `*accent*` phrase and the tick above the caption all in the one
`accent`. So with lime as the accent, emphasise with `[chips]` only: a `*phrase*` would be
lime text. A caption that wants olive text instead sets `"accent": "#4A5900"` on its own shot,
and then has no chip. 1.7.3's `*phrase*` captions need rewriting either way.

Superseded sets are deleted rather than kept; git history has them.
