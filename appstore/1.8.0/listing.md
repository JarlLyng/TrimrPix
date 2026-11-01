# TrimrPix 1.8.0: listing

Everything for 1.8.0's App Store Connect fields in one place, for the hub to fill in and the
owner to approve. Each block between the fences is pasted as it stands. No em-dashes anywhere
(#46), and no claim the app can't back.

Counted: the description is 2,037 characters (limit 4,000), the promotional text
154 (limit 170) and What's New 560 (limit 4,000).

## What 1.8.0 carries

- **Drop a folder** onto the window, and TrimrPix adds the images and PDFs in it and its
  subfolders, in the order Finder lists them (#92, #99). It takes the same files Watch Folder
  does: no WebP, and not TrimrPix's own `-optimized` copies. Hidden files and the inside of
  packages, such as a Photos library, are left out. A folder with nothing to optimize says so.
- The empty window says "Drag images or folders here to optimize".
- Nothing else in the app has changed since 1.7.3. The sample measurement added for the site
  (#86) is a test, not part of the app.

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

---

## Keywords (unchanged)

Set with 1.7.3 and carried over by App Store Connect, so nothing to paste.

---

## Description

One bullet changes from 1.7.3's: "Drag and drop" now says that a whole folder can go in. The rest
is 1.7.3's text as it stands.

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
• Drag and drop: add images, PDFs or whole folders straight from Finder, subfolders included
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

---

## What's New in 1.8.0

A draft in the maker's voice (the hub's `VOICE.md`). It says what was missing before, and what a
dropped folder leaves out, so nobody wonders where their WebP files went.

```
You can now drop a whole folder onto TrimrPix's window. It adds the images and PDFs inside, subfolders included, in the order Finder lists them. Before, a folder did nothing, and you had to open it and select the files yourself.

I gave it the same rule Watch Folder uses. WebP files are left out, because macOS can't write WebP, and so are the -optimized copies TrimrPix saved earlier, so nothing gets optimized twice. Hidden files and the inside of packages, such as a Photos library, are skipped. If a folder has nothing TrimrPix can optimize, it tells you.
```

---

## Screenshots

The raw window captures for 1.8.0's posters are in `raw/`. The posters take the site's light
identity from this version on (the hub's `DESIGN.md`, the owner's decision of 2026-10-22), as
`appstore/README.md` describes. The hub composes and uploads them; nothing here is uploaded
from this repo.
