# TrimrPix 1.8.0: listing

Everything for 1.8.0's App Store Connect fields in one place, for the hub to fill in and the
owner to approve. Each block between the fences is pasted as it stands. No em-dashes anywhere
(#46), and no claim the app can't back.

Counted: the description is 2,332 characters (limit 4,000), the promotional text
163 (limit 170) and What's New 875 (limit 4,000).

## What 1.8.0 carries

- **Drop a folder** onto the window, and TrimrPix adds the images and PDFs in it and its
  subfolders, in the order Finder lists them (#92, #99). It takes the same files Watch Folder
  does: no WebP, and not TrimrPix's own `-optimized` copies. Hidden files and the inside of
  packages, such as a Photos library, are left out. A folder with nothing to optimize says so.
- The empty window says "Drag images or folders here to optimize", and the drop zone at the top
  of the window "Drop images or folders here".
- **Anonymous crash reports and two counts** (#106, #107). When the Mac is online, the app sends
  Sentry its crash reports, Apple's diagnostics (MetricKit), whether a session ended in a crash,
  and two counts, one for each image optimized, with its output format, and one for the
  kilobytes it saved. Every install reports as the same user, "anonymous", with no installation
  or device ID, and no file name, path or image content is sent. It is the first time the app has a network connection,
  so the listing no longer says "offline" about the app as a whole, only about compressing.
  `SENTRY.md` in the repo lists what is sent.
- Nothing else in the app has changed since 1.7.3. The sample measurement added for the site
  (#86) is a test, not part of the app.

---

## Subtitle (unchanged)

```
Trim file size. Keep quality.
```

---

## Promotional text (App Store Connect blanks it for every version)

"All offline" from 1.7.3 is gone, since the app now sends anonymous crash reports. What stays
true is said instead, and "on your Mac" moves from the first sentence to the new one, to stay
under 170.

```
Compress images and scanned PDFs without visible quality loss. JPEG, PNG, GIF, AVIF and HEIC. Your images never leave your Mac. One-time purchase, no subscription.
```

---

## Keywords (unchanged)

Set with 1.7.3 and carried over by App Store Connect, so nothing to paste.

---

## Description

Four places change from 1.7.3's text. "Drag and drop" now says that a whole folder can go in.
"Fully offline" goes from the first paragraph and from its own bullet, since the app now sends
anonymous crash reports. In their place the text says that compressing works offline and that
images never leave the Mac, which stays true. The last paragraph says what the app does send.
The rest is 1.7.3's text as it stands.

```
TrimrPix shrinks image file sizes on your Mac without visible quality loss. Drag, drop, optimize, and save space. It works offline, and your images never leave your Mac.

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
• Works offline: your images are compressed on your Mac and never uploaded, with no cloud and no account
• One-time purchase: no subscription, no in-app purchases

PERFECT FOR
• Web developers optimizing site assets
• Bloggers compressing images before upload
• Photographers making files smaller for sharing
• App developers optimizing App Store screenshots
• Anyone who wants smaller images without visible quality loss

All processing happens on your Mac, and your images never leave it. When your Mac is online, the app sends only anonymous crash reports and diagnostics, and how many images were optimized and how much space they saved. There is no ID, and no file name, folder or image content is ever sent.

Requires macOS 15.2 or later.
```

---

## What's New in 1.8.0

A draft in the maker's voice (the hub's `VOICE.md`). It says what was missing before, and what a
dropped folder leaves out, so nobody wonders where their WebP files went. The last paragraph says
plainly that the app now sends something, and what.

```
You can now drop a whole folder onto TrimrPix's window. It adds the images and PDFs inside, subfolders included, in the order Finder lists them. Before, a folder did nothing, and you had to open it and select the files yourself.

I gave it the same rule Watch Folder uses. WebP files are left out, because macOS can't write WebP, and so are the -optimized copies TrimrPix saved earlier, so nothing gets optimized twice. Hidden files and the inside of packages, such as a Photos library, are skipped. If a folder has nothing TrimrPix can optimize, it tells you.

TrimrPix now sends anonymous crash reports when your Mac is online, so I find out when a release breaks something. It also sends a count of the images optimized, by format, and how much space they saved. There is no ID, and no image, file name or folder ever leaves your Mac. Compressing works offline, as before.
```

---

## App Privacy: the owner's step on release day

The label in App Store Connect (App Privacy) changes with this version, because 1.7.3 collected
nothing. It must be in place no later than the day 1.8.0 goes live, and on the same day the site's
privacy policy goes out (#108). It matches `TrimrPix/PrivacyInfo.xcprivacy`.

- **Data Not Linked to You**
  - **Diagnostics:** Crash Data, Performance Data, Other Diagnostic Data. Purpose: App
    Functionality.
  - **Usage Data:** Product Interaction. Purpose: Analytics.
- For every type: not linked to the user's identity, and not used for tracking.

---

## Screenshots

The raw window captures for 1.8.0's posters are in `raw/`. The posters take the site's light
identity from this version on (the hub's `DESIGN.md`, the owner's decision of 2026-10-22), as
`appstore/README.md` describes. The hub composes and uploads them; nothing here is uploaded
from this repo.
