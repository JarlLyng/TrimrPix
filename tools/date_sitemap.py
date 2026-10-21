#!/usr/bin/env python3
"""Date the sitemap from git: each page's <lastmod> is the date of the last commit to its file.

Never hand-written, and never the build date: Google stops trusting a lastmod that is always
the same or always today (#96, as walkful#191 does). The deploy runs this on its checkout, so
the served sitemap carries the dates and the committed one carries none.

    python3 tools/date_sitemap.py           # rewrite docs/sitemap.xml in place (the deploy)
    python3 tools/date_sitemap.py --print   # show the result, change nothing
"""
from __future__ import annotations
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
SITEMAP = DOCS / "sitemap.xml"
SITE = "https://trimrpix.iamjarl.com/"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()


def lastmod(loc: str) -> str:
    if not loc.startswith(SITE):
        raise SystemExit(f"The sitemap lists {loc}, which isn't on {SITE}.")
    path = loc[len(SITE):]
    if path == "" or path.endswith("/"):
        path += "index.html"
    source = DOCS / path
    if not source.is_file():
        raise SystemExit(f"The sitemap lists {loc}, but {source.relative_to(ROOT)} does not exist.")
    date = git("log", "-1", "--format=%cs", "--", str(source.relative_to(ROOT)))
    if not date:
        raise SystemExit(f"{source.relative_to(ROOT)} has no commit to date it by.")
    return date


def main() -> int:
    # A shallow clone has one commit, so every page would get that commit's date.
    if git("rev-parse", "--is-shallow-repository") == "true":
        raise SystemExit("Shallow clone: every page would get the same date. Check out with fetch-depth: 0.")
    xml = re.sub(r"\s*<lastmod>[^<]*</lastmod>", "", SITEMAP.read_text(encoding="utf-8"))
    # Only a page's <loc>: an <image:loc> is not a page and gets no date.
    xml = re.sub(r"(\s*)<loc>([^<]+)</loc>",
                 lambda m: f"{m[1]}<loc>{m[2]}</loc>{m[1]}<lastmod>{lastmod(m[2])}</lastmod>", xml)
    if "--print" in sys.argv:
        print(xml)
    else:
        SITEMAP.write_text(xml, encoding="utf-8")
        print(f"Dated {xml.count('<lastmod>')} pages in {SITEMAP.relative_to(ROOT)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
