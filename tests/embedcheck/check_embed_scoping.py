#!/usr/bin/env python3
"""Assert a surveymap embed fragment cannot restyle the page it is dropped into.

Usage:  python3 check_embed_scoping.py frag.html [prefix]
        prefix defaults to "sm-"

An embed fragment is injected verbatim into somebody else's HTML, so every CSS
selector it carries must be scoped under a .sm- class and every id must be
namespaced.  A bare element selector (body, h1, pre, svg) would silently
restyle the host page.  That is not hypothetical: it is what happened during
the webdoc2 testing that motivated embed mode in the sibling package, where a
fragment's own body{max-width:920px} capped the whole report and its h1/h2
rules shrank the report's own headings.

The check also refuses a fragment that carries script, because a fragment is
meant to be inert.

Exit status is 0 when the fragment is safe and 1 when it is not, so this can
gate a build.
"""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "frag.html"
prefix = sys.argv[2] if len(sys.argv) > 2 else "sm-"
dot = "." + prefix

with open(path, encoding="utf-8") as fh:
    s = fh.read()

fail = []

# ---- every CSS selector is scoped under the prefix class ----------------
sels = 0
for block in re.findall(r"<style[^>]*>(.*?)</style>", s, re.S):
    block = re.sub(r"/\*.*?\*/", "", block, flags=re.S)
    for m in re.finditer(r"([^{}]+)\{[^{}]*\}", block):
        sel = m.group(1).strip()
        if not sel or sel.startswith("@"):
            continue
        for part in (p.strip() for p in sel.split(",")):
            if not part:
                continue
            sels += 1
            if not part.startswith(dot):
                fail.append("unscoped selector: %s" % part)

# ---- no scripts ---------------------------------------------------------
nscript = len(re.findall(r"<script", s, re.I))
if nscript:
    fail.append("%d <script> element(s): a fragment must be inert" % nscript)

# ---- ids are namespaced, so two fragments on one page cannot collide ----
ids = re.findall(r'\sid="([^"]+)"', s)
for i in ids:
    if not i.startswith(prefix):
        fail.append("un-namespaced id: %s" % i)

# ---- a fragment is not a document --------------------------------------
for tag in ("<!doctype", "<html", "<head", "<body"):
    if tag in s.lower():
        fail.append("fragment contains %s; it should be a fragment, not a page" % tag)

print("checked %d selectors and %d ids in %s" % (sels, len(ids), path))
if fail:
    print("FAIL")
    for f in fail:
        print("  " + f)
    sys.exit(1)
print("PASS: fragment is scoped, inert, and namespaced")
