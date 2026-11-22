"""Ortabahçe ve kampüs prop yerleşimi üretici scripti.

Kullanım:
    python tools/osm/place_props.py
    python tools/osm/place_props.py game/data/zones/ortabahce_greybox.json --out game/data/zones/ortabahce_props.json
    python tools/osm/place_props.py --greybox game/data/zones/kampus_greybox.json --out game/data/zones/kampus_props.json

Çıktı:
    {"props": [{"type": "...", "pos": [x, z], "yaw": rad, "scale": s}]}

Kurallar:
- Standart kütüphane, random.Random(42)
- Ağaç (tree_birch, tree_pine, tree_common) ve çalı (bush_common, bush_berries):
  areas çokgenleri içine, birbirinden >= 4m, yollardan >= 2.5m, binalardan >= 3m, orijinden >= 6m.
- Ortabahçe: Ağaç <= 120, çalı <= 80, bank her ~18m, lamba her ~25m (Ortabahçe içi).
- Kampüs: Ağaç <= 700, çalı <= 300, bank <= 250, lamba <= 200 (tüm yaya yolları).
- Çöp kutusu (trashcan): her 3 bankın birinin yanında.
- Bina ve orijin (>= 6m) kuralları hepsi için geçerli.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
from typing import Any


def point_in_polygon(x: float, z: float, poly: list[list[float]]) -> bool:
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if ((zi > z) != (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi):
            inside = not inside
        j = i
    return inside


def dist_pt_seg(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
    dx = bx - ax
    dz = bz - az
    l2 = dx * dx + dz * dz
    if l2 == 0.0:
        return math.hypot(px - ax, pz - az)
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / l2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def dist_pt_polyline(px: float, pz: float, pts: list[list[float]]) -> float:
    min_d = float("inf")
    for i in range(len(pts) - 1):
        d = dist_pt_seg(px, pz, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
        if d < min_d:
            min_d = d
    return min_d


def dist_pt_poly_boundary(px: float, pz: float, poly: list[list[float]]) -> float:
    min_d = float("inf")
    n = len(poly)
    for i in range(n):
        p1 = poly[i]
        p2 = poly[(i + 1) % n]
        d = dist_pt_seg(px, pz, p1[0], p1[1], p2[0], p2[1])
        if d < min_d:
            min_d = d
    return min_d


def is_valid_building_dist(x: float, z: float, buildings: list[dict[str, Any]], min_dist: float = 3.0) -> bool:
    for b in buildings:
        poly: list[list[float]] = b["points"]
        if point_in_polygon(x, z, poly):
            return False
        if dist_pt_poly_boundary(x, z, poly) < min_dist:
            return False
    return True


def _run_ortabahce(data: dict[str, Any], out_path: str, seed: int) -> None:
    buildings: list[dict[str, Any]] = data.get("buildings", [])
    areas: list[dict[str, Any]] = data.get("areas", [])
    paths: list[dict[str, Any]] = data.get("paths", [])

    ortabahce_area = next((a for a in areas if a.get("name") == "Ortabahçe"), None)
    if ortabahce_area is None:
        raise ValueError("Ortabahçe alanı greybox verisinde bulunamadı!")
    ortabahce_poly: list[list[float]] = ortabahce_area["points"]

    rng = random.Random(seed)

    props: list[dict[str, Any]] = []
    benches: list[dict[str, Any]] = []
    lamps: list[dict[str, Any]] = []
    trashcans: list[dict[str, Any]] = []

    bench_interval = 18.0
    lamp_interval = 25.0

    # 1. Banklar, lambalar ve çöp kutuları (Ortabahçe içi yollar boyunca)
    for p in paths:
        pts: list[list[float]] = p["points"]
        for i in range(len(pts) - 1):
            p1 = pts[i]
            p2 = pts[i + 1]
            dx = p2[0] - p1[0]
            dz = p2[1] - p1[1]
            seg_len = math.hypot(dx, dz)
            if seg_len < 0.1:
                continue
            ux = dx / seg_len
            uz = dz / seg_len
            nx = -uz
            nz = ux

            s = 2.0
            while s < seg_len:
                px = p1[0] + ux * s
                pz = p1[1] + uz * s
                s += 3.0

                if not point_in_polygon(px, pz, ortabahce_poly):
                    continue

                # Bank yerleşimi kontrolü (~18m aralık)
                if not any(math.hypot(px - b["pos"][0], pz - b["pos"][1]) < bench_interval for b in benches):
                    candidates = [
                        (px + nx * 1.8, pz + nz * 1.8),
                        (px - nx * 1.8, pz - nz * 1.8),
                    ]
                    for cx, cz in candidates:
                        if not point_in_polygon(cx, cz, ortabahce_poly):
                            continue
                        if math.hypot(cx, cz) < 6.0:
                            continue
                        if not is_valid_building_dist(cx, cz, buildings, 3.0):
                            continue
                        if any(math.hypot(cx - b["pos"][0], cz - b["pos"][1]) < bench_interval for b in benches):
                            continue
                        # Yola dönük yaw: (cx, cz)'den (px, pz)'ye yön
                        fx = px - cx
                        fz = pz - cz
                        yaw = math.atan2(-fx, -fz)
                        bench_obj = {
                            "type": "bench",
                            "pos": [round(cx, 2), round(cz, 2)],
                            "yaw": round(yaw, 3),
                            "scale": 1.0,
                        }
                        benches.append(bench_obj)
                        props.append(bench_obj)

                        # Her 3 bankın birinin yanına çöp kutusu
                        if (len(benches) - 1) % 3 == 0:
                            for sign in [1, -1]:
                                tx = cx + ux * 1.4 * sign
                                tz = cz + uz * 1.4 * sign
                                if (
                                    point_in_polygon(tx, tz, ortabahce_poly)
                                    and math.hypot(tx, tz) >= 6.0
                                    and is_valid_building_dist(tx, tz, buildings, 3.0)
                                ):
                                    if not any(math.hypot(tx - pr["pos"][0], tz - pr["pos"][1]) < 0.8 for pr in props):
                                        tc_obj = {
                                            "type": "trashcan",
                                            "pos": [round(tx, 2), round(tz, 2)],
                                            "yaw": 0.0,
                                            "scale": 1.0,
                                        }
                                        trashcans.append(tc_obj)
                                        props.append(tc_obj)
                                        break
                        break

                # Lamba yerleşimi kontrolü (~25m aralık)
                if not any(math.hypot(px - l["pos"][0], pz - l["pos"][1]) < lamp_interval for l in lamps):
                    candidates = [
                        (px - nx * 1.8, pz - nz * 1.8),
                        (px + nx * 1.8, pz + nz * 1.8),
                    ]
                    for cx, cz in candidates:
                        if not point_in_polygon(cx, cz, ortabahce_poly):
                            continue
                        if math.hypot(cx, cz) < 6.0:
                            continue
                        if not is_valid_building_dist(cx, cz, buildings, 3.0):
                            continue
                        if any(math.hypot(cx - l["pos"][0], cz - l["pos"][1]) < lamp_interval for l in lamps):
                            continue
                        if any(math.hypot(cx - b["pos"][0], cz - b["pos"][1]) < 2.5 for b in benches):
                            continue
                        # Lamba kafası +Z'de, yola dönük yaw
                        fx = px - cx
                        fz = pz - cz
                        yaw = math.atan2(fx, fz)
                        lamp_obj = {
                            "type": "lamp",
                            "pos": [round(cx, 2), round(cz, 2)],
                            "yaw": round(yaw, 3),
                            "scale": 1.0,
                        }
                        lamps.append(lamp_obj)
                        props.append(lamp_obj)
                        break

    # 2. Ağaçlar ve çalılar (areas çokgenleri içine)
    min_x = min(min(pt[0] for pt in a["points"]) for a in areas)
    max_x = max(max(pt[0] for pt in a["points"]) for a in areas)
    min_z = min(min(pt[1] for pt in a["points"]) for a in areas)
    max_z = max(max(pt[1] for pt in a["points"]) for a in areas)

    tree_types = ["tree_birch", "tree_pine", "tree_common"]
    bush_types = ["bush_common", "bush_berries"]

    trees: list[dict[str, Any]] = []
    bushes: list[dict[str, Any]] = []
    target_trees = 80
    target_bushes = 45

    attempts = 0
    max_attempts = 40000

    while attempts < max_attempts and (len(trees) < target_trees or len(bushes) < target_bushes):
        attempts += 1
        cx = rng.uniform(min_x, max_x)
        cz = rng.uniform(min_z, max_z)

        # Alan içinde mi?
        if not any(point_in_polygon(cx, cz, a["points"]) for a in areas):
            continue
        # Orijine mesafe >= 6m
        if math.hypot(cx, cz) < 6.0:
            continue
        # Binalardan mesafe >= 3m
        if not is_valid_building_dist(cx, cz, buildings, 3.0):
            continue
        # Yollardan mesafe >= 2.5m
        if any(dist_pt_polyline(cx, cz, p["points"]) < 2.5 for p in paths):
            continue
        # Diğer proplardan mesafe >= 4.0m
        if any(math.hypot(cx - pr["pos"][0], cz - pr["pos"][1]) < 4.0 for pr in props):
            continue

        if len(trees) < target_trees and (len(bushes) >= target_bushes or rng.random() < 0.64):
            ttype = rng.choice(tree_types)
            scale = round(rng.uniform(0.9, 1.2), 2)
            yaw = round(rng.uniform(0.0, 2 * math.pi), 3)
            obj = {"type": ttype, "pos": [round(cx, 2), round(cz, 2)], "yaw": yaw, "scale": scale}
            trees.append(obj)
            props.append(obj)
        elif len(bushes) < target_bushes:
            btype = rng.choice(bush_types)
            scale = 1.0
            yaw = round(rng.uniform(0.0, 2 * math.pi), 3)
            obj = {"type": btype, "pos": [round(cx, 2), round(cz, 2)], "yaw": yaw, "scale": scale}
            bushes.append(obj)
            props.append(obj)

    out_data = {"props": props}
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, ensure_ascii=False, indent=2)

    print(
        f"Üretildi: {len(props)} prop "
        f"({len(trees)} ağaç, {len(bushes)} çalı, {len(benches)} bank, {len(lamps)} lamba, {len(trashcans)} çöp kutusu) -> {out_path}"
    )


def _run_campus(data: dict[str, Any], out_path: str, seed: int) -> None:
    buildings: list[dict[str, Any]] = data.get("buildings", [])
    areas: list[dict[str, Any]] = data.get("areas", [])
    all_paths: list[dict[str, Any]] = data.get("paths", [])
    ped_paths: list[dict[str, Any]] = [p for p in all_paths if p.get("kind") != "service"]

    # Hızlandırma için sınırlayıcı kutular (bounding boxes)
    b_boxes = []
    for b in buildings:
        pts = b["points"]
        b_boxes.append((min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts), pts))

    p_boxes = []
    for p in all_paths:
        pts = p["points"]
        p_boxes.append((min(pt[0] for pt in pts), max(pt[0] for pt in pts), min(pt[1] for pt in pts), max(pt[1] for pt in pts), pts))

    a_boxes = []
    for a in areas:
        pts = a["points"]
        a_boxes.append((min(pt[0] for pt in pts), max(pt[0] for pt in pts), min(pt[1] for pt in pts), max(pt[1] for pt in pts), pts))

    def fast_is_valid_building_dist(x: float, z: float, min_dist: float = 3.0) -> bool:
        for min_x, max_x, min_z, max_z, pts in b_boxes:
            if x < min_x - min_dist or x > max_x + min_dist or z < min_z - min_dist or z > max_z + min_dist:
                continue
            if point_in_polygon(x, z, pts):
                return False
            if dist_pt_poly_boundary(x, z, pts) < min_dist:
                return False
        return True

    def fast_dist_paths(x: float, z: float, min_dist: float = 2.5) -> bool:
        for min_x, max_x, min_z, max_z, pts in p_boxes:
            if x < min_x - min_dist or x > max_x + min_dist or z < min_z - min_dist or z > max_z + min_dist:
                continue
            if dist_pt_polyline(x, z, pts) < min_dist:
                return False
        return True

    # Mekansal ızgara (spatial hash) ile prop mesafe kontrolleri O(1)
    grid: dict[tuple[int, int], list[dict[str, Any]]] = {}
    cell_size = 10.0

    def add_to_grid(pr: dict[str, Any]) -> None:
        cx, cz = pr["pos"]
        gx, gz = int(cx // cell_size), int(cz // cell_size)
        grid.setdefault((gx, gz), []).append(pr)

    def is_far_from_props(x: float, z: float, min_dist: float) -> bool:
        min_dist_sq = min_dist * min_dist
        gx, gz = int(x // cell_size), int(z // cell_size)
        r = int(math.ceil(min_dist / cell_size))
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                cell = grid.get((gx + dx, gz + dz))
                if cell:
                    for pr in cell:
                        px, pz = pr["pos"]
                        if (x - px) ** 2 + (z - pz) ** 2 < min_dist_sq:
                            return False
        return True

    props: list[dict[str, Any]] = []
    benches: list[dict[str, Any]] = []
    lamps: list[dict[str, Any]] = []
    trashcans: list[dict[str, Any]] = []

    bench_interval = 38.0
    lamp_interval = 45.0
    max_benches = 250
    max_lamps = 200

    # 1. Banklar, lambalar ve çöp kutuları (tüm yaya yolları boyunca)
    for p in ped_paths:
        pts: list[list[float]] = p["points"]
        for i in range(len(pts) - 1):
            p1 = pts[i]
            p2 = pts[i + 1]
            dx = p2[0] - p1[0]
            dz = p2[1] - p1[1]
            seg_len = math.hypot(dx, dz)
            if seg_len < 0.1:
                continue
            ux = dx / seg_len
            uz = dz / seg_len
            nx = -uz
            nz = ux

            s = 2.0
            while s < seg_len:
                px = p1[0] + ux * s
                pz = p1[1] + uz * s
                s += 3.0

                # Bank yerleşimi
                if len(benches) < max_benches and not any(math.hypot(px - b["pos"][0], pz - b["pos"][1]) < bench_interval for b in benches):
                    candidates = [
                        (px + nx * 1.8, pz + nz * 1.8),
                        (px - nx * 1.8, pz - nz * 1.8),
                    ]
                    for cx, cz in candidates:
                        if math.hypot(cx, cz) < 6.0:
                            continue
                        if not fast_is_valid_building_dist(cx, cz, 3.0):
                            continue
                        if any(math.hypot(cx - b["pos"][0], cz - b["pos"][1]) < bench_interval for b in benches):
                            continue
                        fx = px - cx
                        fz = pz - cz
                        yaw = math.atan2(-fx, -fz)
                        bench_obj = {
                            "type": "bench",
                            "pos": [round(cx, 2), round(cz, 2)],
                            "yaw": round(yaw, 3),
                            "scale": 1.0,
                        }
                        benches.append(bench_obj)
                        props.append(bench_obj)
                        add_to_grid(bench_obj)

                        # Her 3 bankın birinin yanına çöp kutusu
                        if (len(benches) - 1) % 3 == 0:
                            for sign in [1, -1]:
                                tx = cx + ux * 1.4 * sign
                                tz = cz + uz * 1.4 * sign
                                if math.hypot(tx, tz) >= 6.0 and fast_is_valid_building_dist(tx, tz, 3.0):
                                    if is_far_from_props(tx, tz, 0.8):
                                        tc_obj = {
                                            "type": "trashcan",
                                            "pos": [round(tx, 2), round(tz, 2)],
                                            "yaw": 0.0,
                                            "scale": 1.0,
                                        }
                                        trashcans.append(tc_obj)
                                        props.append(tc_obj)
                                        add_to_grid(tc_obj)
                                        break
                        break

                # Lamba yerleşimi
                if len(lamps) < max_lamps and not any(math.hypot(px - l["pos"][0], pz - l["pos"][1]) < lamp_interval for l in lamps):
                    candidates = [
                        (px - nx * 1.8, pz - nz * 1.8),
                        (px + nx * 1.8, pz + nz * 1.8),
                    ]
                    for cx, cz in candidates:
                        if math.hypot(cx, cz) < 6.0:
                            continue
                        if not fast_is_valid_building_dist(cx, cz, 3.0):
                            continue
                        if any(math.hypot(cx - l["pos"][0], cz - l["pos"][1]) < lamp_interval for l in lamps):
                            continue
                        if any(math.hypot(cx - b["pos"][0], cz - b["pos"][1]) < 2.5 for b in benches):
                            continue
                        fx = px - cx
                        fz = pz - cz
                        yaw = math.atan2(fx, fz)
                        lamp_obj = {
                            "type": "lamp",
                            "pos": [round(cx, 2), round(cz, 2)],
                            "yaw": round(yaw, 3),
                            "scale": 1.0,
                        }
                        lamps.append(lamp_obj)
                        props.append(lamp_obj)
                        add_to_grid(lamp_obj)
                        break

    # 2. Ağaçlar ve çalılar (tüm kampüs alanları içine)
    rng = random.Random(seed)
    tree_types = ["tree_birch", "tree_pine", "tree_common"]
    bush_types = ["bush_common", "bush_berries"]

    trees: list[dict[str, Any]] = []
    bushes: list[dict[str, Any]] = []
    target_trees = 600
    target_bushes = 250

    attempts = 0
    max_attempts = 150000

    while attempts < max_attempts and (len(trees) < target_trees or len(bushes) < target_bushes):
        attempts += 1
        a_box = rng.choice(a_boxes)
        cx = rng.uniform(a_box[0], a_box[1])
        cz = rng.uniform(a_box[2], a_box[3])

        if not point_in_polygon(cx, cz, a_box[4]):
            continue
        if math.hypot(cx, cz) < 6.0:
            continue
        if not fast_is_valid_building_dist(cx, cz, 3.0):
            continue
        if not fast_dist_paths(cx, cz, 2.5):
            continue
        if not is_far_from_props(cx, cz, 4.0):
            continue

        if len(trees) < target_trees and (len(bushes) >= target_bushes or rng.random() < 0.70):
            ttype = rng.choice(tree_types)
            scale = round(rng.uniform(0.9, 1.2), 2)
            yaw = round(rng.uniform(0.0, 2 * math.pi), 3)
            obj = {"type": ttype, "pos": [round(cx, 2), round(cz, 2)], "yaw": yaw, "scale": scale}
            trees.append(obj)
            props.append(obj)
            add_to_grid(obj)
        elif len(bushes) < target_bushes:
            btype = rng.choice(bush_types)
            scale = 1.0
            yaw = round(rng.uniform(0.0, 2 * math.pi), 3)
            obj = {"type": btype, "pos": [round(cx, 2), round(cz, 2)], "yaw": yaw, "scale": scale}
            bushes.append(obj)
            props.append(obj)
            add_to_grid(obj)

    out_data = {"props": props}
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_data, f, ensure_ascii=False, indent=2)

    print(
        f"Üretildi: {len(props)} prop "
        f"({len(trees)} ağaç, {len(bushes)} çalı, {len(benches)} bank, {len(lamps)} lamba, {len(trashcans)} çöp kutusu) -> {out_path}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Prop yerleşimi üretici")
    parser.add_argument("greybox_json_pos", nargs="?", default=None, help="Greybox JSON yolu (opsiyonel)")
    parser.add_argument("--greybox", default=None, help="Greybox JSON yolu")
    parser.add_argument("--out", default=None, help="Çıktı JSON yolu")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    greybox_path = args.greybox or args.greybox_json_pos or "game/data/zones/ortabahce_greybox.json"

    with open(greybox_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    is_campus = "kampus" in os.path.basename(greybox_path).lower()

    if args.out:
        out_path = args.out
    else:
        out_path = "game/data/zones/kampus_props.json" if is_campus else "game/data/zones/ortabahce_props.json"

    if is_campus:
        _run_campus(data, out_path, args.seed)
    else:
        _run_ortabahce(data, out_path, args.seed)


if __name__ == "__main__":
    main()
