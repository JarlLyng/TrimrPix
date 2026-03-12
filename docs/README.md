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

## Assets

- `styles.css` – Design tokens, article styles, responsive
- `screenshot-1/2/3.png` – App screenshots
- `favicon.png` – Favicon
- `sitemap.xml` – XML sitemap (8 pages + images)
- `robots.txt` – Crawler rules
- `CNAME` – Custom domain config

## Deployment

GitHub Pages serves from `/docs` on `main`. Push to deploy.

## Local Preview

```bash
cd docs && python3 -m http.server 8000
```

## SEO

All pages have: canonical URLs, Open Graph, Twitter Cards, BreadcrumbList structured data.

Index also has: SoftwareApplication + FAQPage structured data.

Content pages also have: Article structured data, GEO answer boxes.

See `SEO_STRATEGY.md` for keyword strategy and content roadmap.
