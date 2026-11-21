"""art/pets.json'daki petlerin glb dosyalarını poly.pizza'dan indirir.

Kullanım:  python tools/assets/fetch_pets.py [--force]
Çıktı:     game/assets/characters/<id>/<id>.glb
Sonra:     Godot import + tools/assets/inspect_pets.gd ile animasyon/kemik listesi.
Sadece standart kütüphane.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "https://static.poly.pizza/{glb}.glb"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="var olanları da yeniden indir")
    args = ap.parse_args()

    pets = json.loads((ROOT / "art/pets.json").read_text(encoding="utf-8"))["pets"]
    total = 0
    for p in pets:
        out = ROOT / "game/assets/characters" / p["id"] / f"{p['id']}.glb"
        if out.exists() and not args.force:
            print(f"var   {out.relative_to(ROOT)}")
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(URL.format(glb=p["glb"]), headers={"User-Agent": "unipet-asset-fetch"})
        data = urllib.request.urlopen(req, timeout=60).read()
        if data[:4] != b"glTF":
            raise SystemExit(f"{p['id']}: glb değil (ilk baytlar {data[:16]!r})")
        out.write_bytes(data)
        total += len(data)
        print(f"indi  {out.relative_to(ROOT)}  {len(data) / 1024:.0f} KB")
    print(f"toplam {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
