# The marketing site (`docs/`)

How the site at [trimrpix.iamjarl.com](https://trimrpix.iamjarl.com) is built and changed. Read this
before changing anything in `docs/`.

Deployed as plain static files, no build step: what is in `docs/` is exactly what is served. A push
to `main` that changes `docs/` deploys it (`.github/workflows/deploy-pages.yml`).

## Shared header and footer

The shared header and footer live in `tools/partials/` and are written into every page by
`tools/sync_partials.py`. **Edit the partial, not the ten pages**, then run the script and commit
the result. CI runs it with `--check` and fails the deploy if any page has drifted.

## The design system

The site runs on the design system's marketing kit and TrimrPix's identity (iamjarl-design, pinned
to one tag, every file with its `integrity` from that tag's `dist/sri.json`). **It serves its own copy**
under `docs/assets/iamjarl-design@<tag>/`, not jsDelivr, which failed in practice and whose stylesheets
would blank the page (the owner's decision, 2026-10-15). Take the files from the tag's GitHub archive,
check each against its `sri.json` (the recipe is in the design repo's README, "A copy served from the
site itself"), and make a bump a new folder, never an edit in place. The deploy refuses a page that
loads a stylesheet or script from jsDelivr.

The homepage is built from the kit and carries no partials. The subpages take the identity without
the kit's sections, and their shared partials are `<ij-nav>` and `<ij-footer>`.

- **Generated pieces are pasted verbatim, never edited:** the store buttons, the nav's Download link,
  the JSON-LD offer and the Smart App Banner come from `dist/store/` at the pinned tag. **Never write a
  price by hand**; the fragment's facts line carries it.
- **Unfinished content is marked**, not guessed: `data-draft-slot="what it waits on"`, or a
  `{{PLACEHOLDER}}`. The deploy refuses any page that still has one.
- **A gap or a fault in the kit goes to an issue in iamjarl-design**, not a local patch.

## The social card

`docs/social-card.png` (the `og:image`, and the repo's GitHub social preview) is rendered from
`tools/social-card/card.html`; the render command is at the top of that file. Change the source
and render again rather than editing the PNG. The GitHub preview is a manual upload by the owner.

## Outbound click tracking

Every App Store link carries the design system's store event: `data-umami-event="store-click"`,
`data-umami-event-store` (`mac-app-store`, or `app-store` for the iOS sibling),
`data-umami-event-placement` (`nav`, `hero`, `hero-ios`, `midpage`, `footer`) and
`data-umami-event-locale`. Umami adds the page URL and screen size itself, so clicks split by page,
placement and device with no extra attributes.

These replaced `appstore-mac` / `appstore-ios` on 2026-10-14 (#86), when the store buttons became
the design system's generated fragments. **Umami data before that date uses the old names.** The hub's
`store_clicks.py` maps `appstore-mac`, `appstore-ios` and `store-click` to the same site, so the
series continues across the switch. Do not rename them again without a reason:
the point is to make site changes judgeable over time. A new App Store link needs the attributes too,
or it is invisible, and should come from a fragment where one exists.
