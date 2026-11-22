"""Greybox binalarını ham OSM etiketleriyle zenginleştirir (bina şekli/konumu değişmez).

Kullanım:  python tools/osm/enrich_buildings.py
Girdi : art/reference/osm/davutpasa.json (ham OSM), game/data/zones/kampus_greybox.json
Çıktı : aynı greybox dosyası; her binaya eşleşen OSM etiketlerinden:
  height      — ölçülmüş 'height' kat sayısıyla tutarlıysa onu, değilse kat × 3.5 (OSM'de çelişkili değerler var)
  kind        — 'roof' (sadece çatı: sundurma/gölgelik), 'greenhouse', 'dormitory', 'school', 'university', ...
  min_height  — 'building:min_level' × 3.5 (binalar arası havada köprü: altı açık)
  roof        — 'hipped' | 'pyramidal' (roof:shape)
  colour      — building:colour (#rrggbb)
Eşleştirme: aynı projeksiyonla OSM yolunun ağırlık merkezi ve köşe sayısı.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from osm_to_greybox import LEVEL_HEIGHT_M, centroid, project  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MATCH_DIST = 1.5
ROOF_ONLY_HEIGHT = 4.0       # sundurma/gölgelik çatı yüksekliği (seviye yoksa)
MIN_STOREY_M, MAX_STOREY_M = 2.6, 4.6  # ölçülmüş yükseklik / kat bu aralıktaysa güvenilir


def chosen_height(tags: dict, levels: float | None) -> float | None:
    try:
        h = float(tags["height"]) if "height" in tags else None
    except ValueError:
        h = None
    if h is not None and levels:
        per = h / levels
        if MIN_STOREY_M <= per <= MAX_STOREY_M:
            return round(h, 2)
        return None  # çelişkili: kat sayısına güven (mevcut değer kalır)
    if h is not None and not levels:
        return round(h, 2)
    return None


def main() -> None:
    raw = json.load(open(os.path.join(ROOT, "art/reference/osm/davutpasa.json"), encoding="utf-8"))
    path = os.path.join(ROOT, "game/data/zones/kampus_greybox.json")
    grey = json.load(open(path, encoding="utf-8"))
    lat0, lon0 = grey["origin"]["lat"], grey["origin"]["lon"]

    osm = []
    for e in raw["elements"]:
        t = e.get("tags", {})
        if "building" not in t or "geometry" not in e:
            continue
        pts = [project(g["lat"], g["lon"], lat0, lon0) for g in e["geometry"]]
        ring = pts[:-1] if pts[0] == pts[-1] else pts
        osm.append((centroid(ring), len(ring), t))

    stats = {"eşleşti": 0, "yükseklik": 0, "çatı-yapı": 0, "köprü": 0, "çatı-şekli": 0, "renk": 0}
    for b in grey["buildings"]:
        c = centroid([tuple(p) for p in b["points"]])
        best = min(osm, key=lambda o: math.dist(o[0], c) + (0 if o[1] == len(b["points"]) else 5.0))
        if math.dist(best[0], c) > MATCH_DIST:
            continue
        t = best[2]
        stats["eşleşti"] += 1
        for k in ("kind", "min_height", "roof", "colour"):
            b.pop(k, None)
        kind = t.get("building", "yes")
        if kind != "yes":
            b["kind"] = kind
        try:
            levels = float(t["building:levels"]) if "building:levels" in t else None
        except ValueError:
            levels = None
        h = chosen_height(t, levels)
        if kind == "roof":
            b["height"] = round((levels or 1) * LEVEL_HEIGHT_M if levels else ROOF_ONLY_HEIGHT, 2)
            stats["çatı-yapı"] += 1
        elif h is not None and abs(h - b["height"]) > 0.05:
            b["height"] = h
            stats["yükseklik"] += 1
        if "building:min_level" in t:
            try:
                b["min_height"] = round(float(t["building:min_level"]) * LEVEL_HEIGHT_M, 2)
                stats["köprü"] += 1
            except ValueError:
                pass
        if t.get("roof:shape") in ("hipped", "pyramidal"):
            b["roof"] = t["roof:shape"]
            stats["çatı-şekli"] += 1
        if str(t.get("building:colour", "")).startswith("#"):
            b["colour"] = t["building:colour"]
            stats["renk"] += 1

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(grey, f, ensure_ascii=False, separators=(",", ":"))  # orijinal gibi tek satır (diff küçük kalsın)
    print(stats, "toplam bina:", len(grey["buildings"]))


if __name__ == "__main__":
    main()
