#!/usr/bin/env python3
"""Davutpaşa kampüsü gerçek yükseklik haritasını (DEM) indirir ve oyun verisine çevirir.

Kaynak: AWS Open Data Terrain Tiles (Terrarium PNG, zoom 14, ~7 m/piksel, ücretsiz, anahtar gerektirmez).
Formül: elev_m = (R * 256 + G + B / 256.0) - 32768.0
Özellikler:
- 12.5 m ızgara çözünürlüğü (yol, bina ve saha geçişleri pürüzsüz).
- Ortabahçe avlusu, Stadyum pisti (kampus_greenery.json -> tracks) ve tüm spor sahaları / oyun alanları
  (kampus_greybox.json -> areas: pitch, playground) yumuşak geçişle tam düzleştirilir.

Kullanım:
    python tools/osm/fetch_elevation.py
"""
from __future__ import annotations

import io
import json
import math
import urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GREYBOX_PATH = ROOT / "game" / "data" / "zones" / "kampus_greybox.json"
GREENERY_PATH = ROOT / "game" / "data" / "zones" / "kampus_greenery.json"
OUT_PATH = ROOT / "game" / "data" / "zones" / "kampus_terrain.json"

M_PER_DEG_LAT = 110_540.0
M_PER_DEG_LON_EQ = 111_320.0

STEP_M = 12.5
MARGIN_M = 50.0
ZOOM = 14
TILE_URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"


def unproject(x: float, z: float, lat0: float, lon0: float) -> tuple[float, float]:
    lat = lat0 - z / M_PER_DEG_LAT
    lon = lon0 + x / (M_PER_DEG_LON_EQ * math.cos(math.radians(lat0)))
    return lat, lon


def latlon_to_tile_px(lat: float, lon: float, zoom: int) -> tuple[int, int, float, float]:
    n = 2.0 ** zoom
    tx_f = (lon + 180.0) / 360.0 * n
    lat_rad = math.radians(lat)
    ty_f = (1.0 - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi) / 2.0 * n
    tx = int(math.floor(tx_f))
    ty = int(math.floor(ty_f))
    px = (tx_f - tx) * 256.0
    py = (ty_f - ty) * 256.0
    return tx, ty, px, py


def fetch_tile(z: int, x: int, y: int) -> Image.Image:
    url = TILE_URL.format(z=z, x=x, y=y)
    req = urllib.request.Request(url, headers={"User-Agent": "UniPet-Terrain/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return Image.open(io.BytesIO(resp.read())).convert("RGB")


def decode_terrarium(r: int, g: int, b: int) -> float:
    return (r * 256.0 + g + b / 256.0) - 32768.0


def sample_tile_elev(img: Image.Image, px: float, py: float) -> float:
    x0 = min(max(int(math.floor(px)), 0), 255)
    y0 = min(max(int(math.floor(py)), 0), 255)
    x1 = min(x0 + 1, 255)
    y1 = min(y0 + 1, 255)
    fx = px - x0
    fy = py - y0
    e00 = decode_terrarium(*img.getpixel((x0, y0)))
    e10 = decode_terrarium(*img.getpixel((x1, y0)))
    e01 = decode_terrarium(*img.getpixel((x0, y1)))
    e11 = decode_terrarium(*img.getpixel((x1, y1)))
    return (e00 * (1.0 - fx) + e10 * fx) * (1.0 - fy) + (e01 * (1.0 - fx) + e11 * fx) * fy


def smooth_grid(grid: list[list[float]], passes: int = 3) -> list[list[float]]:
    """3x3 Gaussian benzeri yumuşatma: DEM basamaklanmasını giderir."""
    rows = len(grid)
    cols = len(grid[0])
    cur = [row[:] for row in grid]
    for _ in range(passes):
        nxt = [[0.0] * cols for _ in range(rows)]
        for r in range(rows):
            for c in range(cols):
                acc = 0.0
                wsum = 0.0
                for dr in (-1, 0, 1):
                    rr = min(max(r + dr, 0), rows - 1)
                    for dc in (-1, 0, 1):
                        cc = min(max(c + dc, 0), cols - 1)
                        w = 4.0 if (dr == 0 and dc == 0) else (2.0 if (dr == 0 or dc == 0) else 1.0)
                        acc += cur[rr][cc] * w
                        wsum += w
                nxt[r][c] = acc / wsum
        cur = nxt
    return cur


def flatten_box(
    grid: list[list[float]],
    min_x: float,
    min_z: float,
    step: float,
    bx0: float,
    bx1: float,
    bz0: float,
    bz1: float,
    pad: float = 10.0,
    blend: float = 28.0,
    target_h: float | None = None,
) -> float:
    """Dikdörtgen bir alanı (stadyum, halı saha, kort, avlu) yumuşak geçişle düzleştirir."""
    rows = len(grid)
    cols = len(grid[0])
    x0, x1 = bx0 - pad, bx1 + pad
    z0, z1 = bz0 - pad, bz1 + pad

    if target_h is None:
        samples = []
        for r in range(rows):
            z = min_z + r * step
            if z < z0 or z > z1:
                continue
            for c in range(cols):
                x = min_x + c * step
                if x0 <= x <= x1:
                    samples.append(grid[r][c])
        if not samples:
            return 0.0
        target_h = sum(samples) / len(samples)

    for r in range(rows):
        z = min_z + r * step
        dz = 0.0 if (z0 <= z <= z1) else (z0 - z if z < z0 else z - z1)
        if dz > blend:
            continue
        for c in range(cols):
            x = min_x + c * step
            dx = 0.0 if (x0 <= x <= x1) else (x0 - x if x < x0 else x - x1)
            if dx > blend:
                continue
            dist = math.hypot(dx, dz)
            if dist <= 0.0:
                grid[r][c] = target_h
            elif dist < blend:
                t = dist / blend
                s = t * t * (3.0 - 2.0 * t)
                grid[r][c] = target_h * (1.0 - s) + grid[r][c] * s
    return target_h


def sample_bilinear(grid: list[list[float]], min_x: float, min_z: float, step: float, x: float, z: float) -> float:
    rows = len(grid)
    cols = len(grid[0])
    fx = min(max((x - min_x) / step, 0.0), cols - 1.0001)
    fz = min(max((z - min_z) / step, 0.0), rows - 1.0001)
    c0 = int(fx)
    r0 = int(fz)
    tx = fx - c0
    tz = fz - r0
    h00 = grid[r0][c0]
    h10 = grid[r0][c0 + 1]
    h01 = grid[r0 + 1][c0]
    h11 = grid[r0 + 1][c0 + 1]
    return (h00 * (1.0 - tx) + h10 * tx) * (1.0 - tz) + (h01 * (1.0 - tx) + h11 * tx) * tz


def main() -> None:
    greybox = json.loads(GREYBOX_PATH.read_text(encoding="utf-8"))
    origin = greybox["origin"]
    lat0, lon0 = float(origin["lat"]), float(origin["lon"])

    xs, zs = [], []
    for key in ("buildings", "areas", "paths"):
        for item in greybox.get(key, []):
            for pt in item.get("points", []):
                xs.append(float(pt[0]))
                zs.append(float(pt[1]))

    min_x = math.floor((min(xs) - MARGIN_M) / STEP_M) * STEP_M
    max_x = math.ceil((max(xs) + MARGIN_M) / STEP_M) * STEP_M
    min_z = math.floor((min(zs) - MARGIN_M) / STEP_M) * STEP_M
    max_z = math.ceil((max(zs) + MARGIN_M) / STEP_M) * STEP_M

    cols = int(round((max_x - min_x) / STEP_M)) + 1
    rows = int(round((max_z - min_z) / STEP_M)) + 1
    print(f"Grid: {cols}x{rows} ({cols * rows} nokta, adım={STEP_M} m), X=[{min_x}, {max_x}], Z=[{min_z}, {max_z}]")

    tiles: dict[tuple[int, int], Image.Image] = {}
    grid: list[list[float]] = []
    for r in range(rows):
        z = min_z + r * STEP_M
        row_vals: list[float] = []
        for c in range(cols):
            x = min_x + c * STEP_M
            lat, lon = unproject(x, z, lat0, lon0)
            tx, ty, px, py = latlon_to_tile_px(lat, lon, ZOOM)
            if (tx, ty) not in tiles:
                print(f"  DEM karosu indiriliyor: z={ZOOM} x={tx} y={ty}")
                tiles[(tx, ty)] = fetch_tile(ZOOM, tx, ty)
            row_vals.append(sample_tile_elev(tiles[(tx, ty)], px, py))
        grid.append(row_vals)

    grid = smooth_grid(grid, passes=3)

    # 1) Ortabahçe + Kışla kompleksi (gerçekte düz plato)
    flatten_box(grid, min_x, min_z, STEP_M, -110.0, 145.0, -90.0, 95.0, pad=12.0, blend=35.0)

    # 2) Stadyum pisti ve iç saha (kampus_greenery.json -> tracks listesi)
    if GREENERY_PATH.exists():
        greenery = json.loads(GREENERY_PATH.read_text(encoding="utf-8"))
        for tr in greenery.get("tracks", []):
            pts = tr.get("outer", [])
            if pts:
                txs = [float(p[0]) for p in pts]
                tzs = [float(p[1]) for p in pts]
                th = flatten_box(grid, min_x, min_z, STEP_M, min(txs), max(txs), min(tzs), max(tzs), pad=16.0, blend=35.0)
                print(f"  Stadyum pisti düzleştirildi: X=[{min(txs):.0f}..{max(txs):.0f}] Z=[{min(tzs):.0f}..{max(tzs):.0f}] -> {th:.1f} m")

    # 3) Tüm spor sahaları (pitch) ve oyun alanları (playground)
    flat_count = 0
    for a in greybox.get("areas", []):
        if a.get("kind") in ("pitch", "playground"):
            pts = a.get("points", [])
            if pts:
                axs = [float(p[0]) for p in pts]
                azs = [float(p[1]) for p in pts]
                flatten_box(grid, min_x, min_z, STEP_M, min(axs), max(axs), min(azs), max(azs), pad=8.0, blend=22.0)
                flat_count += 1
    print(f"  {flat_count} spor sahası / oyun alanı düzleştirildi")

    origin_h = sample_bilinear(grid, min_x, min_z, STEP_M, 0.0, 0.0)
    heights: list[float] = []
    min_h = 1e9
    max_h = -1e9
    for r in range(rows):
        for c in range(cols):
            rel = round(grid[r][c] - origin_h, 2)
            heights.append(rel)
            min_h = min(min_h, rel)
            max_h = max(max_h, rel)

    out = {
        "source": "aws-terrarium-z14",
        "origin": origin,
        "origin_elevation_m": round(origin_h, 2),
        "min_x": min_x,
        "min_z": min_z,
        "step": STEP_M,
        "cols": cols,
        "rows": rows,
        "heights": heights,
    }
    OUT_PATH.write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
    print(f"Yazıldı: {OUT_PATH.relative_to(ROOT)} ({len(tiles)} karo, kot aralığı: {min_h:.2f} m .. +{max_h:.2f} m, orijin={origin_h:.1f} m)")


if __name__ == "__main__":
    main()
