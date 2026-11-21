"""art/props.json'daki propların glb dosyalarını poly.pizza'dan indirir.

Kullanım:  python tools/assets/fetch_props.py [--force]
Çıktı:     game/assets/props/<id>.glb
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

    props = json.loads((ROOT / "art/props.json").read_text(encoding="utf-8"))["props"]
    total = 0
    out_dir = ROOT / "game/assets/props"
    out_dir.mkdir(parents=True, exist_ok=True)

    for p in props:
        out = out_dir / f"{p['id']}.glb"
        if out.exists() and not args.force:
            print(f"var   {out.relative_to(ROOT)}")
            continue
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
