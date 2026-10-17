#!/usr/bin/env python3
"""Fetch the sample folder behind the site's measured number (#86), and prove it is the same one.

The folder is 30 unedited CC0 iPhone originals from Wikimedia Commons, listed in
sample-manifest.json with each file's URL, SHA-1 and size as Commons records them. The photos
are not kept in the repo; this rebuilds the folder byte for byte, so the number can be measured
again on exactly the same files:

    python3 tools/redesign/fetch_sample.py ~/trimrpix-sample
    TEST_RUNNER_SAMPLE_DIR=~/trimrpix-sample TEST_RUNNER_SAMPLE_OUT=~/trimrpix-report \\
      xcodebuild test ... -only-testing:TrimrPixTests/SampleSavingsMeasurement

A file whose SHA-1 or size differs from the manifest is deleted and reported, never measured.
Files already present and correct are left alone.
"""
from __future__ import annotations
import hashlib, json, pathlib, sys, time, urllib.request

MANIFEST = pathlib.Path(__file__).with_name("sample-manifest.json")
# Wikimedia asks automated clients to say who they are.
USER_AGENT = "TrimrPix-site-measurement/1.0 (https://trimrpix.iamjarl.com; support@iamjarl.com)"


def sha1(path: pathlib.Path) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    out = pathlib.Path(sys.argv[1]).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    files = json.loads(MANIFEST.read_text(encoding="utf-8"))
    bad = []
    for i, f in enumerate(files, 1):
        path = out / f["file"]
        if path.exists() and path.stat().st_size == f["bytes"] and sha1(path) == f["sha1"]:
            print(f"[{i:2}/{len(files)}] ok      {f['file']}")
            continue
        req = urllib.request.Request(f["url"], headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=120) as r:
            path.write_bytes(r.read())
        if path.stat().st_size != f["bytes"] or sha1(path) != f["sha1"]:
            path.unlink()
            bad.append(f["file"])
            print(f"[{i:2}/{len(files)}] WRONG   {f['file']} (deleted)")
        else:
            print(f"[{i:2}/{len(files)}] fetched {f['file']}")
        time.sleep(1)  # one at a time, politely
    if bad:
        print(f"{len(bad)} file(s) did not match the manifest: " + ", ".join(bad), file=sys.stderr)
        return 1
    print(f"All {len(files)} files match the manifest.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
