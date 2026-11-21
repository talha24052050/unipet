"""OSM (Overpass JSON) -> greybox bölge verisi (Godot'un okuduğu JSON).

Kullanım:
    python tools/osm/osm_to_greybox.py art/reference/osm/davutpasa.json \
        --center-park "Ortabahçe" --radius 220 --out game/data/zones/ortabahce_greybox.json

Çıktı (metre, Godot ekseni: +X doğu, -Z kuzey, orijin = parkın merkezi):
    {"origin": {"lat", "lon"}, "radius",
     "buildings": [{"name", "points": [[x, z], ...], "height"}],
     "areas": [{"kind": "park"|"grass"|"pitch", "name", "points": [[x, z], ...]}],
     "paths": [{"kind", "points": [[x, z], ...]}]}

Binalar "düz kutu": OSM taban şekli yükseklik kadar yukarı uzatılır (detay yok, ölçek testi için).
Taban şekli korunur çünkü bazı binalar (ör. Kışla) avluyu çevreleyen içbükey şekillerdir.
Sadece standart kütüphane.
"""

from __future__ import annotations

import argparse
import json
import math

LEVEL_HEIGHT_M = 3.5
DEFAULT_LEVELS = 3
M_PER_DEG_LAT = 110_540.0
M_PER_DEG_LON_EQ = 111_320.0
AREA_KINDS = {"park", "garden", "pitch", "playground", "grass"}
PATH_KINDS = {"footway", "pedestrian", "path", "service"}


def project(lat: float, lon: float, lat0: float, lon0: float) -> tuple[float, float]:
    x = (lon - lon0) * M_PER_DEG_LON_EQ * math.cos(math.radians(lat0))
    z = -(lat - lat0) * M_PER_DEG_LAT
    return (round(x, 2), round(z, 2))


def centroid(pts: list[tuple[float, float]]) -> tuple[float, float]:
    n = len(pts)
    return (sum(p[0] for p in pts) / n, sum(p[1] for p in pts) / n)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("osm_json")
    ap.add_argument("--center-park", required=True)
    ap.add_argument("--radius", type=float, default=220.0)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    with open(args.osm_json, encoding="utf-8") as f:
        elements = json.load(f)["elements"]

    park = next(
        e for e in elements
        if e.get("tags", {}).get("name") == args.center_park and "geometry" in e
    )
    lat0 = sum(g["lat"] for g in park["geometry"]) / len(park["geometry"])
    lon0 = sum(g["lon"] for g in park["geometry"]) / len(park["geometry"])

    def pts_of(e) -> list[tuple[float, float]]:
        return [project(g["lat"], g["lon"], lat0, lon0) for g in e.get("geometry", [])]

    def near(pts) -> bool:
        cx, cz = centroid(pts)
        return math.hypot(cx, cz) <= args.radius

    buildings, areas, paths = [], [], []
    for e in elements:
        tags = e.get("tags", {})
        pts = pts_of(e)
        if len(pts) < 2 or not near(pts):
            continue
        if "building" in tags and len(pts) >= 3:
            ring = pts[:-1] if pts[0] == pts[-1] else pts
            try:
                levels = float(tags.get("building:levels", DEFAULT_LEVELS))
            except ValueError:
                levels = DEFAULT_LEVELS
            buildings.append({
                "name": tags.get("name", ""),
                "points": [list(p) for p in ring],
                "height": round(levels * LEVEL_HEIGHT_M, 2),
            })
        elif (tags.get("leisure") in AREA_KINDS or tags.get("landuse") == "grass") and len(pts) >= 4:
            kind = tags.get("leisure") or "grass"
            ring = pts[:-1] if pts[0] == pts[-1] else pts
            areas.append({"kind": kind, "name": tags.get("name", ""), "points": [list(p) for p in ring]})
        elif tags.get("highway") in PATH_KINDS:
            paths.append({"kind": tags["highway"], "points": [list(p) for p in pts]})

    out = {
        "source": "OpenStreetMap contributors (ODbL)",
        "origin": {"lat": round(lat0, 7), "lon": round(lon0, 7)},
        "radius": args.radius,
        "buildings": buildings, "areas": areas, "paths": paths,
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(buildings)} bina, {len(areas)} alan, {len(paths)} yol -> {args.out}")


if __name__ == "__main__":
    main()
