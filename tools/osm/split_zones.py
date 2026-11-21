"""Kampüs greybox verisini bölgelere böler (ROADMAP 5.4).

Kullanım:
    python tools/osm/split_zones.py
Girdi:  game/data/zones/davutpasa_campus.json  (tools/osm/osm_to_greybox.py --area-way ile üretilir)
        game/data/zones/zones.json             (bölge tanımları)
Çıktı:  game/data/zones/<id>_greybox.json      (ortabahce HARİÇ — o ayrı üretilir ve değişmez)

Her bölge dosyası osm_to_greybox çıktısıyla aynı formattadır; koordinatlar KAMPÜS koordinatı kalır
(bölge merkezi orijin olmaz) ki konumlar bölgeler arasında tutarlı olsun. GreyboxBuilder zemini
"center" alanından kurar. "spawn" bina dışında değilse en yakın açık noktaya kaydırılır.
Sadece standart kütüphane.
"""

from __future__ import annotations

import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
ZONES_DIR = ROOT / "game" / "data" / "zones"
SKIP = {"ortabahce"}
SPAWN_CLEARANCE_M = 6.0


def centroid(pts: list) -> tuple[float, float]:
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def inside(pt: tuple[float, float], poly: list) -> bool:
    x, z = pt
    res = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi + 1e-12) + xi:
            res = not res
        j = i
    return res


def dist_to_poly(pt: tuple[float, float], poly: list) -> float:
    best = math.inf
    for i in range(len(poly)):
        ax, az = poly[i]
        bx, bz = poly[(i + 1) % len(poly)]
        dx, dz = bx - ax, bz - az
        L = dx * dx + dz * dz
        t = 0.0 if L == 0 else max(0.0, min(1.0, ((pt[0] - ax) * dx + (pt[1] - az) * dz) / L))
        best = min(best, math.hypot(pt[0] - (ax + t * dx), pt[1] - (az + t * dz)))
    return best


def free_spawn(start: tuple[float, float], buildings: list) -> tuple[float, float]:
    """start'tan spiral arayarak binalardan SPAWN_CLEARANCE_M uzak ilk noktayı bulur."""
    def ok(p):
        return all(not inside(p, b["points"]) and dist_to_poly(p, b["points"]) >= SPAWN_CLEARANCE_M for b in buildings)
    if ok(start):
        return start
    for r in range(2, 200, 2):
        for k in range(max(8, r)):
            a = 2 * math.pi * k / max(8, r)
            p = (start[0] + r * math.cos(a), start[1] + r * math.sin(a))
            if ok(p):
                return (round(p[0], 1), round(p[1], 1))
    return start


def main() -> None:
    campus = json.loads((ZONES_DIR / "davutpasa_campus.json").read_text(encoding="utf-8"))
    zones = json.loads((ZONES_DIR / "zones.json").read_text(encoding="utf-8"))
    changed_spawns = {}
    for z in zones["zones"]:
        if z["id"] in SKIP:
            continue
        cx, cz = z["center"]
        r = z["radius"]

        def near(pts):
            c = centroid(pts)
            return math.hypot(c[0] - cx, c[1] - cz) <= r

        out = {
            "source": campus.get("source", "OpenStreetMap contributors (ODbL)"),
            "origin": campus.get("origin"),
            "zone": z["id"],
            "center": [cx, cz],
            "radius": r,
            "buildings": [b for b in campus["buildings"] if near(b["points"])],
            "areas": [a for a in campus["areas"] if near(a["points"])],
            "paths": [p for p in campus["paths"] if near(p["points"])],
        }
        sp = free_spawn(tuple(z["spawn"]), out["buildings"])
        if list(sp) != list(z["spawn"]):
            changed_spawns[z["id"]] = list(sp)
        out["spawn"] = list(sp)
        path = ZONES_DIR / f"{z['id']}_greybox.json"
        path.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"{z['id']}: {len(out['buildings'])} bina, {len(out['areas'])} alan, {len(out['paths'])} yol, spawn {sp}")
    if changed_spawns:
        for z in zones["zones"]:
            if z["id"] in changed_spawns:
                z["spawn"] = changed_spawns[z["id"]]
        (ZONES_DIR / "zones.json").write_text(json.dumps(zones, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("zones.json spawn güncellendi:", changed_spawns)


if __name__ == "__main__":
    main()
