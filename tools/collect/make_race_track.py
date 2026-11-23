"""Stadyum pisti koşu yarışı: pist orta çizgisinden başlangıç + kontrol noktaları (yarım tur, ~200 m).

Kullanım: python tools/collect/make_race_track.py
Çıktı  : game/data/race.json  ve  server/nakama/modules/index.js içindeki RACE_CPS bloğu
         (sunucu kontrol noktası geçişlerini konuma göre doğrular; ikisi aynı listeyi kullanmalı).
Kaynak : game/data/zones/kampus_greenery.json tracks[0] (inner/outer aynı sayıda nokta).
"""
import json
import math
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GREENERY = os.path.join(ROOT, "game/data/zones/kampus_greenery.json")
OUT = os.path.join(ROOT, "game/data/race.json")
SERVER = os.path.join(ROOT, "server/nakama/modules/index.js")
CP_COUNT = 6          # başlangıç hariç: 5 ara + bitiş
CP_RADIUS = 9.0


def main():
    t = json.load(open(GREENERY, encoding="utf-8"))["tracks"][0]
    mid = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(t["inner"], t["outer"])]
    width = sum(math.dist(a, b) for a, b in zip(t["inner"], t["outer"])) / len(mid)
    n = len(mid)
    seg = [math.dist(mid[i], mid[(i + 1) % n]) for i in range(n)]
    total = sum(seg)
    # başlangıç: uzun düzlüğün ortası (en uzun parçanın ortası)
    s0 = max(range(n), key=lambda i: seg[i])
    def at(dist):
        d = dist % total
        i = s0
        start_frac = 0.5
        d += seg[s0] * start_frac
        while d > seg[i]:
            d -= seg[i]
            i = (i + 1) % n
        a, b = mid[i], mid[(i + 1) % n]
        u = d / seg[i]
        p = (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)
        dx, dz = b[0] - a[0], b[1] - a[1]
        return [round(p[0], 2), round(p[1], 2)], round(math.atan2(dx, dz), 3)
    half = total / 2
    cps = []
    for k in range(CP_COUNT + 1):
        p, yaw = at(half * k / CP_COUNT)
        cps.append({"p": p, "yaw": yaw, "d": round(half * k / CP_COUNT, 1)})
    data = {"_note": "make_race_track.py üretir. cps[0] başlangıç, son eleman bitiş; d = başlangıçtan pist mesafesi (m).",
            "width": round(width, 2), "radius": CP_RADIUS, "length": round(half, 1), "cps": cps}
    json.dump(data, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    src = open(SERVER, encoding="utf-8").read()
    block = ("// <race-cps> (tools/collect/make_race_track.py üretir, elle düzenleme)\nvar RACE_CPS = %s;\n// </race-cps>"
             % json.dumps([[c["p"][0], c["p"][1], c["d"]] for c in cps], separators=(",", ":")))
    src, k = re.subn(r"// <race-cps>.*?// </race-cps>", lambda _m: block, src, flags=re.S)
    if k != 1:
        raise SystemExit("index.js'de <race-cps> bloğu yok")
    open(SERVER, "w", encoding="utf-8", newline="\n").write(src)
    print("OK yarış: %.0f m, pist genişliği %.1f m, %d kontrol noktası" % (half, width, len(cps)))


if __name__ == "__main__":
    main()
