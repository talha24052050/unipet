"""art/pets.json + art/pets_inspect.json -> game/data/characters/<id>.tres (CharacterDef).

Kullanım: python tools/assets/make_pet_defs.py
Ölçek: modelin boyu TARGET_HEIGHT_M'ye indirilir (pet başına override: HEIGHT_OVERRIDE).
Animasyonlar: önce modelde birebir karşılık aranır, yoksa FALLBACK kullanılır.
Elle ince ayar gerekirse .tres'i değil bu scripti değiştir, yeniden üret.
"""

from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
PREFIX = "CharacterArmature|"
TARGET_HEIGHT_M = 1.1
HEIGHT_OVERRIDE = {"shark": 1.25}  # kollu-bacaklı, yüzgeç dahil boy

# mantıksal ad -> (tercih sırasıyla) modeldeki animasyon adları
CANDIDATES = {
    "idle": ["Idle"],
    "walk": ["Walk"],
    "run": ["Run", "Walk"],
    "emote_wave": ["Wave", "Dance"],  # Talha: blob'larda el sallama yerine Dans
    "emote_jump": ["Jump"],
    "emote_yes": ["Yes"],
    "emote_no": ["No"],
    "emote_dance": ["Dance"],
}
# run walk'tan geliyorsa hızlandır
RUN_FROM_WALK_SPEED = 1.6

# Pet başına aksesuar ince ayarı (PetVisual.accessory_anchor'a bak).
# pos: metre kaydırma, height: yüzeyin arandığı boy oranı, scale: çarpan.
ACCESSORY_TWEAKS = {
    "shark": {
        "head": {"pos": (0.0, -0.22, 0.02)},  # yüzgeç tepesini atla
        "face": {"height": 0.66},
        "neck": {"height": 0.42, "scale": 0.42},  # kollar yarıçapı büyütüyor
        "back": {"height": 0.52},
    },
    "chicken": {"head": {"pos": (0.0, -0.1, -0.03)}},  # ibiğin üstüne değil kafaya
    "mushnub": {"face": {"height": 0.42, "pos": (0.0, 0.0, 0.07)}},
    "yeti": {"face": {"height": 0.64}},
    "birb": {"neck": {"scale": 0.85}},
}

# slot -> (tercih sırasıyla) kemik adları
BONE_CANDIDATES = {
    "head": ["Head"],
    "face": ["Head"],
    "neck": ["Neck", "Body"],
    "back": ["Torso", "Body"],
}


def tres(pet: dict, info: dict) -> str:
    anims = {a.removeprefix(PREFIX) for a in info["animations"]}
    amap, aspeed = {}, {}
    for logical, cands in CANDIDATES.items():
        hit = next((c for c in cands if c in anims), None)
        if hit:
            amap[logical] = PREFIX + hit
            if logical == "run" and hit == "Walk":
                aspeed[logical] = RUN_FROM_WALK_SPEED
    bones = {}
    for slot, cands in BONE_CANDIDATES.items():
        hit = next((c for c in cands if c in info["bones"]), None)
        if hit:
            bones[slot] = hit
    height = info["size"][1]
    scale = round(HEIGHT_OVERRIDE.get(pet["id"], TARGET_HEIGHT_M) / height, 3)

    def gd_value(v) -> str:
        if isinstance(v, dict):
            return gd_dict(v)
        if isinstance(v, tuple):
            return "Vector3(" + ", ".join(str(float(x)) for x in v) + ")"
        return json.dumps(v, ensure_ascii=False)

    def gd_dict(d: dict) -> str:
        if not d:
            return "{}"
        items = ",\n".join(f'"{k}": {gd_value(v)}' for k, v in d.items())
        return "{\n" + items + "\n}"

    return f"""[gd_resource type="Resource" script_class="CharacterDef" format=3]

[ext_resource type="Script" path="res://src/characters/character_def.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{pet['id']}"
display_name = "{pet['name']}"
model_path = "res://assets/characters/{pet['id']}/{pet['id']}.glb"
model_scale = {scale}
animation_map = {gd_dict(amap)}
animation_speed = {gd_dict(aspeed)}
accessory_bones = {gd_dict(bones)}
accessory_offsets = {gd_dict(ACCESSORY_TWEAKS.get(pet["id"], {}))}
"""


def main() -> None:
    pets = json.loads((ROOT / "art/pets.json").read_text(encoding="utf-8"))["pets"]
    inspect = json.loads((ROOT / "art/pets_inspect.json").read_text(encoding="utf-8"))
    out_dir = ROOT / "game/data/characters"
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in pets:
        path = out_dir / f"{p['id']}.tres"
        path.write_text(tres(p, inspect[p["id"]]), encoding="utf-8", newline="\n")
        print(f"yazıldı {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
