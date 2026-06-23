# Security Policy

## Reporting a vulnerability

If you've found a security issue in TrimrPix, please **don't open a public issue**. Email me directly:

**jarl@iamjarl.com**

Please include:
- A description of the vulnerability
- Steps to reproduce
- The affected version (Mac App Store version or commit SHA)
- Your contact info if you'd like credit when it's fixed

I'll respond within 7 days. For confirmed issues, I'll work on a patch and ship it as quickly as the App Store review process allows (typically 1–3 days for review, plus development time).

## Scope

In scope:
- TrimrPix macOS app code
- The marketing site at `trimrpix.iamjarl.com`
- Build/release scripts

Out of scope:
- Third-party dependencies (e.g. IAMJARLDesignTokens) — report to those projects directly
- Apple platform vulnerabilities — report to Apple Product Security
- Issues in forks of this repo

## What TrimrPix does and doesn't handle

TrimrPix is a single-purpose image compressor with a deliberately small attack surface:

- **No backend.** No server, no database, no API endpoints.
- **No accounts.** No sign-up, no authentication, no password storage.
- **Images never leave the Mac.** All compression is local; nothing is uploaded.
- **No tracking.** No analytics in the app. The marketing website uses Umami for aggregate page views (no cookies, no fingerprinting).
- **Local file access only.** The app reads/writes the images and folders you point it at (including the optional Watch Folder), via security-scoped access.

If you find a way to break any of those guarantees, I want to know.

## Past advisories

None to date.
