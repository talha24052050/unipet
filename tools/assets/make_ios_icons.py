#!/usr/bin/env python3
"""UniPet iOS uygulama ikonu setini üretir (şeffaflıksız RGB PNG).

Apple App Store kuralları:
- İkonlarda alfa (şeffaflık) kanalı OLMAMALI (RGB).
- Köşeler dik olmalı (iOS kendi yuvarlak maskesini uygular).

Kaynak tasarım: game/icon.svg (#1b2a4a arka plan, #ffd34d yıldız, yüz ifadesi).
Çalıştırma: python tools/assets/make_ios_icons.py
"""
from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "game" / "assets" / "icons" / "ios"

BG_COLOR = (0x1B, 0x2A, 0x4A)
STAR_COLOR = (0xFF, 0xD3, 0x4D)

SIZES = [1024, 180, 167, 152, 120, 80, 76, 40]


def render_master(size: int = 2048) -> Image.Image:
    """game/icon.svg geometrisini yüksek çözünürlükte RGB olarak çizer."""
    img = Image.new("RGB", (size, size), BG_COLOR)
    draw = ImageDraw.Draw(img)
    s = size / 128.0

    # 5 köşeli yıldız (icon.svg path koordinatlarıyla birebir)
    pts_svg = [
        (64.0, 18.0),
        (76.9, 44.2),
        (105.8, 48.4),
        (84.9, 68.8),
        (89.8, 97.6),
        (64.0, 84.0),
        (38.2, 97.6),
        (43.1, 68.8),
        (22.2, 48.4),
        (51.1, 44.2),
    ]
    pts = [(x * s, y * s) for x, y in pts_svg]
    draw.polygon(pts, fill=STAR_COLOR)

    # Gözler (cx=55/73, cy=58, r=4)
    for cx in (55.0, 73.0):
        r = 4.0 * s
        draw.ellipse((cx * s - r, 58.0 * s - r, cx * s + r, 58.0 * s + r), fill=BG_COLOR)

    # Gülümseme: M56 68 q8 7 16 0 -> kuadratik Bezier (56,68), (64,75), (72,68)
    smile_pts = []
    steps = 48
    for i in range(steps + 1):
        t = i / steps
        mt = 1.0 - t
        x = mt * mt * 56.0 + 2 * mt * t * 64.0 + t * t * 72.0
        y = mt * mt * 68.0 + 2 * mt * t * 75.0 + t * t * 68.0
        smile_pts.append((x * s, y * s))
    width = max(1, round(3.0 * s))
    draw.line(smile_pts, fill=BG_COLOR, width=width, joint="curve")
    # Yuvarlak uç kapakları (stroke-linecap="round")
    cap_r = width / 2.0
    for px, py in (smile_pts[0], smile_pts[-1]):
        draw.ellipse((px - cap_r, py - cap_r, px + cap_r, py + cap_r), fill=BG_COLOR)

    return img


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    master = render_master(2048)
    for sz in SIZES:
        resized = master.resize((sz, sz), Image.Resampling.LANCZOS).convert("RGB")
        out_path = OUT_DIR / f"icon_{sz}.png"
        resized.save(out_path, format="PNG", optimize=True)
        print(f"wrote {out_path.relative_to(ROOT)} ({sz}x{sz} RGB)")


if __name__ == "__main__":
    main()
