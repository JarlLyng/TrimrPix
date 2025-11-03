# TrimrPix Landing Page

This directory contains the landing page for TrimrPix, hosted on GitHub Pages.

## Structure

- `index.html` - Main landing page
- `styles.css` - All CSS styles
- Screenshots are referenced from the root `/Screenshots/` directory

## GitHub Pages Configuration

To enable GitHub Pages:

1. Go to repository Settings
2. Navigate to Pages
3. Select source: `Deploy from a branch`
4. Select branch: `main` or `gh-pages`
5. Select folder: `/docs`
6. Save

The site will be available at: `https://jarllyng.github.io/TrimrPix/`

## Local Development

To preview the site locally:

1. Install a local web server (Python, Node.js, etc.)
2. Serve the docs directory:
   ```bash
   # Python 3
   python3 -m http.server 8000
   
   # Node.js (with http-server)
   npx http-server docs -p 8000
   ```
3. Open `http://localhost:8000` in your browser

## Updating Content

- Edit `index.html` for content changes
- Edit `styles.css` for styling changes
- Images should be placed in `/Screenshots/` directory (root level)

