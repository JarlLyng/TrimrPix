# TrimrPix marketing site

This directory is the marketing website for TrimrPix, hosted at **https://trimrpix.iamjarl.com/** (via GitHub Pages and CNAME).

## Structure

- `index.html` – Main landing page (App Store CTA, no GitHub links)
- `support.html` – Support and contact
- `privacy.html` – Privacy policy
- `styles.css` – Styles (design tokens, responsive)
- `screenshot-1.png`, `screenshot-2.png`, `screenshot-3.png` – App Store screenshots
- `sitemap.xml` – Sitemap for SEO
- `robots.txt` – Crawler rules
- `CNAME` – Custom domain (trimrpix.iamjarl.com)

## Deployment

GitHub Pages is configured to serve from the `/docs` folder. Push to `main` and the site updates automatically (if Pages is set to “Deploy from a branch” → branch `main` → folder `/docs`).

## Local preview

```bash
cd docs && python3 -m http.server 8000
# Open http://localhost:8000
```

## SEO

- Canonical URLs, meta description, Open Graph, Twitter cards
- Structured data: SoftwareApplication, FAQPage, BreadcrumbList
- Sitemap includes image URLs for indexing
