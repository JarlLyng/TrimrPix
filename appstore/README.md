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
The window is 1280 × 810 points for 1 and 4, tall enough to show all six files without scrolling,
and 1280 × 720 for 2 and 3, where the Settings sheet is the subject. The usage, including the build without the sandbox it needs to
read a folder, is at the top of `ScreenshotMode.swift`. The four states:

1. Six photos after Optimize All, at Medium, resized to 2048 px (`-screenshotOptimize YES
   -resizeEnabled YES -maxDimension 2048`).
2. Settings at the defaults, over the thirty photos just dropped in (`-screenshotSettings YES`).
3. Settings scrolled to Watch Folder, turned on (`-screenshotSettingsAtEnd YES
   -watchFolderEnabled YES -watchFolderPath /Users/Shared/Screenshots`).
4. One file per format, just dropped in: a HEIC, an AVIF and an image PDF made from the sample
   photos with `sips`, a GIF of the app's own window, a PNG screenshot of it, and a JPEG.

## The posters

Composed with the hub's `tools/appstore_screenshots.py`, in the standard its `DESIGN.md` sets
for TrimrPix (dark ground, `#D0FF00`):

```sh
<hub>/.venv/bin/python <hub>/tools/appstore_screenshots.py batch appstore/manifest.json
```

The captions are public copy, so the hub's `VOICE.md` applies: no em-dashes, no hype, and no
claim the app can't back. A number states its condition, so "79% smaller" says "when resized
for the web" (the site's measured sample, #86).

Superseded sets are deleted rather than kept; git history has them.
