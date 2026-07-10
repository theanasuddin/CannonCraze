# Cannon Craze — official website

The official landing page for [Cannon Craze](https://github.com/theanasuddin/CannonCraze):
a fully static, dependency-free site that shares the game's own design system
(palette, Montserrat with tracked uppercase, glass panels, procedural starfield).

## Stack

None. Hand-written HTML, CSS, and vanilla JS. No build step, no framework,
no external requests — fonts, icons, and screenshots are all self-hosted and
optimized (WebP screens, WOFF2 fonts).

## Deploy to Vercel

1. Import the repository into Vercel.
2. Set **Root Directory** to `website/`.
3. Framework preset: **Other**. No build command, no output directory needed.
4. Deploy.

`vercel.json` already configures clean URLs (`/privacy` serves `privacy.html`),
immutable caching for `/assets/`, and security headers.

### Custom domain

The canonical URL is `https://cannoncraze.vercel.app`. If you attach a custom
domain, search-and-replace that origin in:

- `index.html` (canonical, Open Graph, Twitter, JSON-LD)
- `privacy.html` (canonical, Open Graph)
- `sitemap.xml`
- `robots.txt`

## SEO inventory

- Unique title/meta description per page, canonical URLs
- Open Graph + Twitter Card with a 1200x630 `og-image`
- JSON-LD structured data: `VideoGame` (with offers, platforms, version),
  `WebSite`, and `FAQPage` (mirrors the on-page FAQ exactly)
- `sitemap.xml` (with image extensions) + `robots.txt`
- Semantic single-`h1` document, descriptive alt text, lazy-loaded gallery
- Self-hosted WOFF2 fonts with `font-display: swap`, preloaded
- Total page weight ≈ 350 KB including all images and fonts

## Updating for a new release

Download links use GitHub's stable `releases/latest/download/<file>` URLs, so
they never need editing. When a release changes the version number or file
sizes, update:

- the `v1.1.0` badge and sizes in `index.html` (`#download` section + the
  platform-detect strings in `script.js`)
- `softwareVersion` / `dateModified` in the JSON-LD block
- `lastmod` in `sitemap.xml`

## Asset pipeline

Screenshots come from `docs/screenshots/`, icons from `docs/icon/`, fonts from
`data/`. They were converted with a one-off script (sharp for WebP/PNG sizes,
wawoff2 for fonts); re-run any image through the same tools if you replace one.
