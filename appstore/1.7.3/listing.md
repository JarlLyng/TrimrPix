# TrimrPix 1.7.3: listing

Everything for 1.7.3's App Store Connect fields in one place, for the hub to fill in and the
owner to approve. Each block between the fences is pasted as it stands. No em-dashes anywhere
(#46), and no claim the app can't back. Every feature line was checked against the code, and
every number against the measured sample in `tools/redesign/` (#86).

Counted: the description is 2,002 characters (limit 4,000), the keywords 96 (limit 100), the
subtitle 29 (limit 30) and the promotional text 154 (limit 170).

## What 1.7.3 carries

- **The app is under 3 MB, down from 87 MB** (#81). Its five icons are SF Symbols now. The icon
  library it used before shipped every icon in every weight, which was most of the 87 MB. A
  clean Release build of 1.7.3 is 2,864,069 bytes, for Intel and Apple silicon.
- **Watch Folder starts and stops when Settings is saved** (#90). Before, a change only took
  effect the next time the window opened.
- **The Settings sheet scrolls** instead of cutting off its title and Save when Watch Folder is
  on (#89). The PNG setting's caption drops its unmeasured "60-80%" (#46).
- **"PDFs that are images, such as scans"** in the drop zone and messages, instead of "scanned
  PDF" (#45).
- Not in the release: the capture mode for the site's screenshots exists in Debug builds only
  (#88).

---

## Subtitle (unchanged)

```
Trim file size. Keep quality.
```

---

## Promotional text (unchanged; App Store Connect blanks it for every version)

```
Compress images and scanned PDFs on your Mac without visible quality loss. JPEG, PNG, GIF, AVIF and HEIC, all offline. One-time purchase, no subscription.
```

"Scanned PDFs" stays here: it is true, and the field is too short for the full wording. The
description below says it exactly.

---

## Keywords (optional)

The live value has never been recorded in the hub, so read it before replacing it. The proposal
in #8 must not be used as it stands: it has `webp`, which the app refuses, and `converter`,
which it isn't (it keeps every file in its own format).

A proposal (96), with none of the subtitle's words (trim, file, size, keep, quality) and not
the app's name, both of which Apple already indexes:

```
image,compress,compressor,optimizer,shrink,reduce,photo,jpeg,png,heic,avif,gif,batch,resize,exif
```

Every term is one the app backs. `pdf` is left out on purpose: it would bring people looking for
a general PDF compressor, which TrimrPix is not.

---

## Description

```
TrimrPix shrinks image file sizes on your Mac without visible quality loss. Drag, drop, optimize, and save space. Fast, private, and fully offline.

SUPPORTED FORMATS
• JPEG: progressive encoding with optimized compression
• PNG: lossy quantization to 256 colors, and the alpha channel removed where an image has no transparency
• GIF: re-encoded with LZW compression, animation kept and metadata removed
• AVIF: re-encoded at your chosen quality
• HEIC: the format iPhone and iPad shoot in, re-encoded at your chosen quality
• PDFs that are images, such as scans: each page re-encoded at your chosen quality. PDFs with selectable text are left alone on purpose. A PDF whose text was turned into outlines counts as an image, and its text comes out slightly softer

HOW MUCH SMALLER
Measured on 30 unedited iPhone photos at the Medium preset: 79% smaller in total when resized to 2048 px for the web, and 25% smaller at full size, since iPhones already save their photos well compressed.

KEY FEATURES
• Smart size guard: keeps the original if compression would make the file bigger
• Metadata stripping: removes EXIF, GPS, and IPTC data
• Image resizing: optional downscaling before compression, never upscaling
• Drag and drop: add images and PDFs straight from Finder
• Batch processing: optimize hundreds of images at once, with live progress
• Watch Folder: new images in a folder you choose are optimized automatically while TrimrPix is open
• Quality presets: Low (60%), Medium (80%), High (95%), or your own from 10 to 100%
• Fully offline: no uploads, no cloud, no account required
• One-time purchase: no subscription, no in-app purchases

PERFECT FOR
• Web developers optimizing site assets
• Bloggers compressing images before upload
• Photographers making files smaller for sharing
• App developers optimizing App Store screenshots
• Anyone who wants smaller images without visible quality loss

All processing happens on your Mac. Your images never leave it.

Requires macOS 15.2 or later.
```

### What changed from the live text, and why

- **Em-dashes:** 17 to 0. Bullet labels take a colon, as the hub settled on #46.
- **"Reduce file sizes by up to 80%"** is gone. It was never measured, and it only holds with
  resizing. In its place is the measured result with its conditions: −79% resized to 2048 px,
  −25% at full size (#86, `tools/redesign/sample-report-*.json`). The site states the same two
  numbers.
- **PNG "(up to 80% smaller)"** and **"for dramatically smaller files"** are gone. Nothing
  measured them, and in a function check a photo-like PNG came out 1% smaller.
- **AVIF "best-in-class savings"** is gone. Nothing compared it.
- **"Scanned PDF"** becomes "PDFs that are images, such as scans". The outlined-text sentence says
  plainly what happens to those (#45, the owner's decision of 2026-10-13).
- **Watch Folder** says "while TrimrPix is open". It only runs while the window is open.
- **"PNG quantization"** is no longer a key feature of its own. It repeated the PNG format line.
- **"Anyone who wants smaller images without quality loss"** gets "visible", like the first
  line.

---

## What's New in 1.7.3

```
TrimrPix is now under 3 MB, down from 87 MB. The icon library it used to carry was most of that, and its icons are Apple's own symbols now.

Watch Folder starts and stops as soon as you save Settings. Before, a change only took effect the next time TrimrPix opened. And Settings no longer cuts off its title and Save button when Watch Folder is on.
```

---

## Screenshots

The store's screenshots are still the April set. They show a format picker that was removed in
1.1. New ones aren't in this folder yet. The capture mode (#88) can produce the raw window
shots, which the hub's `appstore_screenshots.py` can compose into posters. That's a separate
step for the owner to decide on, and it can go up through the Asset Library without a release.
