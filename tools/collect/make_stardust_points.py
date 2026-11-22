"""Yıldız tozu (toplanabilir) için aday noktalar: kampüs yaya yollarının üstünde, ~20 m arayla, binaların dışında.

Kullanım: python tools/collect/make_stardust_points.py
Çıktı  : game/data/stardust_points.json  ve  server/nakama/modules/index.js içindeki STARDUST_POINTS bloğu
         (sunucu toplamayı konuma göre doğrular; ikisi aynı listeyi kullanmalı).
"""
import json
import math
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GREYBOX = os.path.join(ROOT, "game/data/zones/kampus_greybox.json")
OUT = os.path.join(ROOT, "game/data/stardust_points.json")
SERVER = os.path.join(ROOT, "server/nakama/modules/index.js")
STEP = 20.0
MIN_GAP = 18.0
BUILDING_MARGIN = 3.0


def inside(pt, poly):
    x, y = pt
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi:
            c = not c
        j = i
    return c


def near_poly(pt, poly, m):
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = dx * dx + dy * dy or 1e-9
        t = max(0.0, min(1.0, ((pt[0] - a[0]) * dx + (pt[1] - a[1]) * dy) / L))
        if math.hypot(pt[0] - a[0] - t * dx, pt[1] - a[1] - t * dy) < m:
            return True
    return False


def main():
    d = json.load(open(GREYBOX, encoding="utf-8"))
    polys = [b["points"] for b in d["buildings"] if len(b.get("points", [])) >= 3]
    pts = []
    for p in d["paths"]:
        if p.get("kind") not in ("footway", "pedestrian"):
            continue
        line = p["points"]
        carry = STEP / 2
        for a, b in zip(line, line[1:]):
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            s = carry
            while s < seg:
                q = (a[0] + (b[0] - a[0]) * s / seg, a[1] + (b[1] - a[1]) * s / seg)
                if all(math.hypot(q[0] - o[0], q[1] - o[1]) >= MIN_GAP for o in pts) and \
                        not any(inside(q, pl) or near_poly(q, pl, BUILDING_MARGIN) for pl in polys):
                    pts.append(q)
                s += STEP
            carry = s - seg
    pts = [[round(x, 1), round(z, 1)] for x, z in pts]
    json.dump({"points": pts}, open(OUT, "w", encoding="utf-8"), separators=(",", ":"))
    src = open(SERVER, encoding="utf-8").read()
    block = "// <stardust-points> (tools/collect/make_stardust_points.py üretir, elle düzenleme)\nvar STARDUST_POINTS = %s;\n// </stardust-points>" % json.dumps(pts, separators=(",", ":"))
    src, n = re.subn(r"// <stardust-points>.*?// </stardust-points>", lambda _m: block, src, flags=re.S)
    if n != 1:
        raise SystemExit("index.js'de <stardust-points> bloğu yok")
    open(SERVER, "w", encoding="utf-8", newline="\n").write(src)
    print("OK %d nokta" % len(pts))


if __name__ == "__main__":
    main()
