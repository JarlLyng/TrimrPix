#!/usr/bin/env python3
"""Keep the shared header and footer identical across the marketing pages.

The site is deployed as plain static files with no build step, and that is worth
keeping: what is in docs/ is exactly what is served, which makes "does live match
the repo" a one-line check. So this does not introduce a template engine. It
writes the shared markup into the pages, which stay complete, directly editable
and directly servable, and CI runs it with --check so the copies cannot drift.

Edit tools/partials/*.html, run this, commit the result.

    python3 tools/sync_partials.py           # rewrite the pages
    python3 tools/sync_partials.py --check   # fail if any page is out of date
"""
from __future__ import annotations
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
PARTIALS = ROOT / "tools" / "partials"

# index.html is served at / so it links to same-page anchors; every other page
# has to name the file. That is the only way the header legitimately differs.
HOME = {"index.html": ""}
DEFAULT_HOME = "index.html"

# index.html carries the full five-column footer; the rest carry the compact one.
FOOTER = {"index.html": "footer-full.html"}
DEFAULT_FOOTER = "footer-compact.html"

SKIP = {"google25b9a18021b6d68d.html"}          # Search Console verification file


def block(name: str, body: str) -> str:
    return f"<!-- partial:{name} -->\n{body.rstrip()}\n{' ' * 4}<!-- /partial:{name} -->"


def render(page: str) -> dict[str, str]:
    header = (PARTIALS / "header.html").read_text(encoding="utf-8")
    header = header.replace("{{HOME}}", HOME.get(page, DEFAULT_HOME))
    footer = (PARTIALS / FOOTER.get(page, DEFAULT_FOOTER)).read_text(encoding="utf-8")
    return {"header": header, "footer": footer}


def apply(text: str, name: str, body: str) -> tuple[str, bool]:
    """Replace an existing marked block, or wrap the element if not yet marked."""
    marked = re.compile(
        rf"[ \t]*<!-- partial:{name} -->.*?<!-- /partial:{name} -->", re.S)
    new = block(name, body)
    if marked.search(text):
        return marked.sub(lambda _: " " * 4 + new, text, count=1), True
    tag = "header" if name == "header" else "footer"
    bare = re.compile(rf"[ \t]*<{tag}[^>]*class=\"(?:site-header|footer)[^\"]*\".*?</{tag}>", re.S)
    if bare.search(text):
        return bare.sub(lambda _: " " * 4 + new, text, count=1), True
    return text, False


def main() -> int:
    check = "--check" in sys.argv
    stale, touched = [], []
    for path in sorted(DOCS.glob("*.html")):
        if path.name in SKIP:
            continue
        original = path.read_text(encoding="utf-8")
        text = original
        for name, body in render(path.name).items():
            text, ok = apply(text, name, body)
            if not ok:
                print(f"  ! {path.name}: no {name} found", file=sys.stderr)
                return 2
        if text != original:
            (stale if check else touched).append(path.name)
            if not check:
                path.write_text(text, encoding="utf-8")
    if check:
        if stale:
            print("Out of date with tools/partials: " + ", ".join(stale), file=sys.stderr)
            print("Run: python3 tools/sync_partials.py", file=sys.stderr)
            return 1
        print("All pages match tools/partials.")
        return 0
    print("Updated: " + (", ".join(touched) if touched else "nothing, already in sync"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
