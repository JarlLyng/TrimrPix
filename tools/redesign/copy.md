# Homepage copy for the redesign (#86)

Draft for the owner's review. Sections follow the brief, top to bottom. Every fact is checked
against the code (AGENTS.md lists them). `{{…}}` marks what waits on the sample measurement or the
before/after photo; nothing there is to be filled in by guesswork.

Voice: no em-dashes, no emoji, no hype, no hand-written price (the store fragment carries it).

---

## 1. Hero

**Trim file size. Keep quality.**

Shrink image file sizes on your Mac without visible quality loss. Drag, drop, optimize, and save
space. Fast, private, and fully offline.

*[store fragment, `.black`, with its facts line]*

*[the loop]* Alt: "Images dragged into TrimrPix, each one's size and saving appearing as it is
optimized."

Looking for iPhone or iPad? →

## 2. Before and after

**One photo, two sizes.**

Chips: `{{BEFORE}} MB → {{AFTER}} MB`

Caption: The same photo twice. On the left, the original at {{BEFORE}} MB. On the right, what
TrimrPix {{VERSION}} made of it at the Medium preset, at {{AFTER}} MB. Nothing else was changed.

Alt, left: "The original photo, {{BEFORE}} MB." Alt, right: "The same photo after TrimrPix, {{AFTER}} MB."

## 3. The window that stays

**Drop them in. Watch them shrink.**

- **One or a few hundred.** Drop in single images or whole folders. Each shows its size before and
  after, and how much it saved, as it goes.
- **Quality, your call.** Low, Medium or High, or a slider from 10 to 100 %. Medium is the default.
- **Watch Folder.** Point it at the folder your screenshots or exports land in. Every new image gets
  a smaller copy beside it, without opening the window. It waits until a file has finished copying.
- **The formats you use.** JPEG, PNG, GIF, AVIF and HEIC, and PDFs that are images rather than text, such as scans. WebP files are left as
  they are: macOS has no way to write them.

## 4. Where it works

**−{{N}} %**

{{FILES}} at Medium, {{BEFORE_TOTAL}} → {{AFTER_TOTAL}}, measured with TrimrPix {{VERSION}}.

- JPEG, PNG, GIF, AVIF and HEIC
- PDFs that are images, such as scans
- Watch Folder
- Metadata stripping: EXIF, GPS and IPTC
- Resize before compressing
- Offline

## 5. Privacy and price

**Your images stay yours.** They are compressed on your Mac and never uploaded. There's no
account and nothing to sign in to.

**Paid for once.** One purchase on the Mac App Store. No subscription, no in-app purchases.

**App Privacy, as the App Store shows it:** Data Not Collected. "The developer does not collect any
data from this app." *(Read off the store page; re-read it when the page is built.)*

## 6. A note from the maker

> I built TrimrPix to do one thing well. It makes your image files smaller without making them
> look worse, it runs on your Mac, and it uploads nothing. You pay for it once.
>
> Jarl

## 7. Guides and comparisons (cards)

- **ImageOptim alternative.** How the two compare, and where ImageOptim is the better choice.
- **JPEG, PNG, WebP, AVIF or HEIC?** Which format to use for what.
- **Compress images for the web.** Smaller pages without visibly worse images.
- **Batch compression on Mac.** Hundreds of images in one go, or a folder that does it for you.
- **App Store images.** Screenshots and assets that pass review and load fast.
- **Remove EXIF data.** What photos carry about you, and how to take it out.

## 8. FAQ (mirrored in FAQPage JSON-LD, word for word)

**Which formats does TrimrPix work with?**
JPEG, PNG, GIF, AVIF and HEIC, plus PDFs that are images rather than text, such as scans. WebP files are skipped with a message and left
as they were, because macOS has no WebP encoder.

**Can it compress PDFs?**
Yes, when the PDF is made of images rather than text, as a scan is: each page is re-encoded at the
quality you choose. PDFs with selectable text are left alone on purpose, because turning them into
images would remove the text and usually make the file bigger, and TrimrPix tells you when it skips
one. A PDF whose text was turned into outlines, as some design tools export it, has no text layer
either. It is treated like a scan, so it gets smaller, but its text comes out slightly softer.

**How does Watch Folder work?**
You choose a folder and turn Watch Folder on. When a new image or image PDF lands there, TrimrPix
waits until the file has finished copying, optimizes it, and saves the smaller copy beside it. The
wait is 2 seconds by default and can be set from 0.5 to 10. It ignores its own output, and it is off
until you turn it on.

**What happens to my originals?**
They are kept. The smaller version is saved next to the original as yourphoto-optimized.jpg, so you
can compare them. If you would rather replace the originals, turn on "Overwrite original files" in
Settings; it is off by default. If compressing would make a file bigger, TrimrPix keeps the
original bytes.

**How much smaller will my images get?**
It depends on the image. Our sample folder, {{FILES}} at Medium, came out {{N}} % smaller in
total. An image that is already well compressed may hardly shrink, and one that would grow is left
as it was.

**What does it cost?**
One purchase on the Mac App Store, with no subscription and no in-app purchases. The price is on
the App Store button.

**Does it work offline?**
Yes. Everything happens on your Mac and your images never leave it. The App Store privacy label
reads "Data Not Collected".

**Which macOS do I need?**
macOS 15.2 or later.

**Can I optimize many images at once?**
Yes. Drop in as many as you like and optimize them together or one by one. Watch Folder does it
for new images on its own.

## 9. Close

**TrimrPix** *(large wordmark)*

*[store fragment, `.black`]*

*[`<ij-footer>`]*

---

### Changed from today's site, and why

- "30–80 %" and the PDF "about two thirds" are gone: neither was measured. The big number replaces
  them once it is (#51).
- "$1.99" is gone from the copy: the brief rules out hand-written prices.
- Watch Folder states its real wait (0.5 to 10 seconds, 2 by default) and that it waits for copies
  to finish, which is true from 1.7.2.
- PDFs are described as "PDFs that are images rather than text, such as scans", and the FAQ says
  outlined text is treated like a scan and comes out slightly softer. #45, option 1, decided by
  the owner 2026-10-13.
- The size guard is stated in the originals answer, since it decides what a user ends up with.
- No PNG-specific saving is claimed. In a function check, a photo-like PNG came out 1 % smaller and a
  screenshot 31 %. If the page ever states a PNG figure, it should be measured, and say what it does
  for screenshots and graphics rather than promise it for every PNG.
