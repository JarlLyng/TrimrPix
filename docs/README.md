# TrimrPix Marketing Site

Hosted at **https://trimrpix.iamjarl.com/** via GitHub Pages.

## Pages

- `index.html` – Landing page
- `support.html` – Support and contact
- `privacy.html` – Privacy policy
- `imageoptim-alternative.html` – ImageOptim comparison
- `image-formats-guide.html` – JPEG vs PNG vs WebP vs AVIF vs HEIC
- `compress-images-for-web.html` – Web compression guide
- `batch-image-compression.html` – Batch + Watch Folder guide
- `optimize-images-app-store.html` – App Store image optimization
- `remove-exif-data-on-mac.html` – Removing EXIF data on a Mac
- `404.html` – Not found

## Assets

- `styles.css` – Design tokens, article styles, responsive
- `screenshot-1` to `screenshot-5` (`.avif`, with a `.png` fallback) – App window captures, taken with the
  Debug-only capture mode in `TrimrPix/ScreenshotMode.swift`
- `favicon.png` – Favicon
- `sitemap.xml` – XML sitemap (9 pages + images). The deploy adds each page's `lastmod` from git
- `robots.txt` – Crawler rules
- `CNAME` – Custom domain config

## Deployment

A GitHub Actions workflow, `.github/workflows/deploy-pages.yml`, deploys `docs/` to GitHub Pages on every push to `main`
that changes `docs/`. It checks the shared header and footer, refuses draft slots and CDN stylesheets or
scripts, and dates the sitemap from git (`tools/date_sitemap.py`).

## Local Preview

```bash
cd docs && python3 -m http.server 8000
```

## SEO

All pages have: canonical URLs, Open Graph, Twitter Cards, BreadcrumbList structured data.

Index also has: SoftwareApplication + FAQPage structured data.

Content pages also have: Article structured data, GEO answer boxes.

SEO and marketing tasks are tracked as [GitHub Issues](https://github.com/JarlLyng/TrimrPix/issues).
