#!/usr/bin/env python3
"""Check that a surveymap HTML map draws a figure nobody has to squint at.

A layout bug in an SVG does not raise an error: Stata writes the coordinates
it was given and the browser draws them, so a box half off the canvas or a
lane label sitting on top of a connector looks like working code and a broken
picture.  This reads the coordinates back out and asserts the things a reader
would notice.

    python3 check_map_geometry.py map.html [map2.html ...]

Exits non-zero on the first file that fails, and names what it found.
"""

import re
import sys

RECT = re.compile(r'<rect x="(-?\d+)" y="(-?\d+)" width="(\d+)" height="(\d+)"')
TEXT = re.compile(r'<text x="(-?\d+)" y="(-?\d+)"[^>]*>([^<]*)</text>')
SVG = re.compile(r'<svg[^>]*width="(\d+)"[^>]*height="(\d+)"')
# an embed fragment scales to its container, so it carries a viewBox and no
# width or height of its own; the viewBox is the canvas either way
VBOX = re.compile(r'<svg[^>]*viewBox="0 0 (\d+) (\d+)"')


def overlap(a, b):
    return (a[0] < b[0] + b[2] and b[0] < a[0] + a[2]
            and a[1] < b[1] + b[3] and b[1] < a[1] + a[3])


def check(path):
    s = open(path, encoding="utf-8").read()
    fails = []

    m = SVG.search(s) or VBOX.search(s)
    if not m:
        return ["no <svg> with either a width and height or a viewBox"]
    w, h = int(m.group(1)), int(m.group(2))
    if w < 1 or h < 1:
        fails.append("the canvas is %dx%d" % (w, h))

    rects = [tuple(map(int, r.groups())) for r in RECT.finditer(s)]
    texts = [(int(t.group(1)), int(t.group(2)), t.group(3)) for t in TEXT.finditer(s)]
    if not rects:
        fails.append("no boxes were drawn")
    if not texts:
        fails.append("no text was drawn")

    # a box or a label past the edge is a box or a label the reader loses
    for r in rects:
        if r[0] < 0 or r[1] < 0 or r[0] + r[2] > w or r[1] + r[3] > h:
            fails.append("a box at (%d,%d) %dx%d falls outside the %dx%d canvas"
                         % (r[0], r[1], r[2], r[3], w, h))
            break
    for t in texts:
        if t[0] < 0 or t[1] < 0 or t[0] > w or t[1] > h:
            fails.append('text "%s" at (%d,%d) falls outside the %dx%d canvas'
                         % (t[2][:30], t[0], t[1], w, h))
            break

    # two boxes on top of each other means one of them cannot be read
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            if overlap(rects[i], rects[j]):
                fails.append("boxes at (%d,%d) and (%d,%d) overlap"
                             % (rects[i][0], rects[i][1], rects[j][0], rects[j][1]))
                break
        if fails and fails[-1].startswith("boxes at"):
            break

    # every gate must announce itself, and its lanes must sit below the heading
    heads = [t for t in texts if t[2].startswith("split by")]
    for hd in heads:
        below = [r for r in rects if hd[1] < r[1] < hd[1] + 140]
        if len(below) < 2:
            fails.append('lane heading "%s" has %d boxes under it; a split needs at least two'
                         % (hd[2], len(below)))

    print("%s: %dx%d, %d boxes, %d labels, %d lane headings"
          % (path, w, h, len(rects), len(texts), len(heads)))
    return fails


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    bad = 0
    for path in argv[1:]:
        try:
            fails = check(path)
        except OSError as e:
            print("FAIL: %s" % e)
            bad += 1
            continue
        if fails:
            bad += 1
            for f in fails:
                print("  FAIL: %s" % f)
        else:
            print("  PASS: nothing off the canvas, nothing overlapping")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
