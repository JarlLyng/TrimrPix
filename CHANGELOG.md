# Changelog

All notable changes to TrimrPix are documented here.

## [1.7.0] - 2026-09-04

### Added
- Scanned PDFs can now be compressed, typically by around 60%. Drag them in like any image, or let a Watch Folder handle them
- PDFs that contain selectable text are deliberately left untouched, with an explanation, because re-encoding them would remove the text and usually make the file larger

## [1.6.1] - 2026-08-30

### Changed
- Refreshed the app's colours to the current IAMJARL design system (the dependency was pinned to a pre-1.0 snapshot)
- The App Store review prompt now appears at a sensible moment, counts single optimizations as well as batches, and asks at most once per version

## [1.6.0] - 2026-07-15

### Added
- Live progress for "Optimize All" — a progress bar and an "N of M" counter while a batch runs

### Changed
- Faster, lighter list previews: thumbnails are now generated off the main thread at preview size, so dropping many large photos no longer stutters the list

## [1.5.2] - 2026-06-03

### Fixed
- "Optimize All" could update the wrong image if one was removed while optimization was running
- Watch Folder could leak a folder-access handle when monitoring was stopped
- Hardened concurrency in Watch Folder monitoring to prevent data races

### Changed
- Lower peak memory when optimizing large batches: optimizations now run with bounded concurrency, and original files are no longer fully read into memory just to measure their size
- Adopted Swift 6 language mode with complete data-race checking across all targets

## [1.5.1] - 2026-04-15

### Fixed
- HEIC compression failing on some images (metadata stripping caused CGImageDestination to fail)

### Added
- MetricKit diagnostics for crash reports and performance metrics via Apple's pipeline

## [1.5.0] - 2026-04-10

### Added
- Progressive JPEG encoding for 5-15% smaller JPEG files
- Lossy PNG quantization (median-cut algorithm) for up to 80% smaller PNGs
- GIF re-encoding with LZW compression and metadata stripping
- EXIF/GPS/IPTC metadata removal from all formats
- Optional image resizing before compression
- New settings: PNG lossy toggle, max image dimensions

### Fixed
- Optimize button color now uses design system accent color correctly

## [1.4.0] - 2026-03-18

### Added
- Smart size guard: keeps original file if compression would increase file size
- App Store review prompt after 5th successful batch optimization
- Design system updated to iamjarl-design v0.1.3

## [1.3.0] - 2026-03-12

### Added
- Real WebP compression via CGImageDestination
- Real AVIF compression via CGImageDestination with graceful fallback
- HEIC/HEIF format support (read and compress)
- Advanced PNG optimization: alpha channel stripping for opaque images

### Changed
- Compression quality setting now applies to WebP, AVIF, and HEIC (not just JPEG)
- Settings migrated from `jpegQuality` to `compressionQuality` key

## [1.0.0] - 2026-02-01

### Added
- Initial release
- JPEG and PNG compression
- GIF validation
- WebP and AVIF format detection
- Drag & drop interface
- Batch processing
- Watch Folder automation
- Quality presets (Low, Medium, High, Custom)
- Auto-save and overwrite options
- Fully offline processing
