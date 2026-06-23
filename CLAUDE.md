# CLAUDE.md — TrimrPix (macOS)

Quick-start context for developers and AI assistants. Detailed specs in `docs/` and `ARCHITECTURE.md`.

## What is TrimrPix?

A macOS SwiftUI app for high-quality image compression with a simple UI — the same core idea as [ImageOptim](https://github.com/ImageOptim/ImageOptim) but with modern formats and Apple-Silicon performance. Everything runs locally; no cloud, no accounts, no internet required.

- **Developer:** Jarl Lyng / [IAMJARL](https://iamjarl.com)
- **Website:** [trimrpix.iamjarl.com](https://trimrpix.iamjarl.com)
- **App Store:** [apps.apple.com/app/trimrpix/id6758639590](https://apps.apple.com/app/trimrpix/id6758639590)
- **License:** [MIT](LICENSE) — open source.
- **Price:** $1.99 USD one-time (no in-app purchases, no subscription, no ads)
- **Sister app:** [TrimrPix for iOS](https://trimrpixforios.iamjarl.com) — separate app; iOS does in-place replacement, macOS has drag-and-drop, Watch Folder, and extra formats (AVIF/GIF).

## Strategy lives in the private hub

Target audience, positioning, pricing reasoning, SEO/ASO playbooks, and competitor analysis are **not** in this public repo — they're in the private [iamjarl-strategy](https://github.com/JarlLyng/iamjarl-strategy) hub (folder `TrimrPix/`). Before doing any audience/positioning/pricing/marketing-planning work, read that repo's `CONVENTIONS.md` and write results there, not here.

## App features (be precise — do not invent features that don't exist)

- **6 formats:** JPEG, PNG, GIF, WebP, AVIF, HEIC.
- **Quality control:** configurable 60–95% for JPEG/WebP/AVIF/HEIC; presets Low/Medium/High/Custom.
- **PNG lossy quantization** (median-cut, 256 colors) + alpha stripping for opaque images.
- **Progressive JPEG** (optimized Huffman); **GIF** LZW re-encode preserving animation.
- **Metadata stripping** — EXIF / GPS / IPTC across formats.
- **Optional resize** (max-dimension downscale) before compression.
- **Drag & drop**, **batch** (concurrent) + per-image controls; real-time size/percentage feedback.
- **Watch Folder** — auto-processes new images (configurable 0.5–10s delay).
- **Auto-save** in the originals' folder (default) or manual save dialog; overwrite-or-new with conflict-safe naming.

### Features that do NOT exist (common hallucination targets)
- No cloud upload, account, or internet processing — fully local.
- Not the iOS "in-place Photos library" model — this is a file/folder tool with auto-save.
- No subscription / IAP.

## Requirements & build
- Runtime: **macOS 15.2+** (deployment target). Language: **Swift 6** mode, SwiftUI, async/await.
- **Builds with Xcode 26 / macOS 26 SDK** — older Xcodes (e.g. 16.2) fail to compile because MetricsService uses MetricKit payload APIs absent from the macOS 15.x SDK. CI runs on `macos-26`.
- Open `TrimrPix.xcodeproj` and run the **TrimrPix** scheme. Tests in `TrimrPixTests`.

## Conventions
- Privacy-first: images never leave the Mac; no tracking.
- See `ARCHITECTURE.md` for the service layer (`CompressionService`, `ColorQuantizer`, `WatchFolderService`).
