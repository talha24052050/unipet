---
name: godot-dev
description: UniPet'te Godot 4.7 sahne/script yazarken, test çalıştırırken veya asset (glb/fbx) import ederken kullan.
---

# Godot geliştirme kuralları (UniPet)

## Script
- GDScript, tipler açık. `class_name` sadece global erişilmesi gereken tiplerde (CharacterDef, ChatMessage).
- Soyut servisler `extends Node` + `push_error("... soyut")` gövdeli metotlar; implementasyon `extends "res://src/.../x_service.gd"`.
- Sinyal adları geçmiş zaman/olay: `player_joined`, `code_sent`.
- Sihirli sayı yok → `Config` sabitleri.

## Sahne (.tscn)
- Sahneleri metin olarak yazabilirsin ama `uid` ve `ext_resource id` alanlarını elle uydurma;
  uid'siz `ext_resource path=` kullan, Godot import sırasında tamamlar.
- UI `CanvasLayer` altında. 3D kök `Node3D`.
- Dokunmatik: `InputEventScreenTouch/Drag`; masaüstünde `emulate_touch_from_mouse` açık.

## Test
Her task sonunda:
```bash
godot --headless --path game --import
godot --headless --path game -s res://tests/run_tests.gd   # exit 0 olmalı
timeout 20 godot --headless --path game --quit-after 30 2>&1 | grep -iE "error|warn"   # boş olmalı
```
Yeni mantık = `game/tests/test_<alan>.gd` içinde `test_*` fonksiyonu; "" döndürürse geçer, aksi halde hata mesajı.
Görsel/his gerektiren şeyler (kamera, joystick) test edilemez → checkpoint'te Talha'ya ekran görüntüsü/APK.

## Asset
- Kaynak dosyalar (fbx/blend) repo'ya girmez (`art/source/` gitignore'da); sadece dönüştürülmüş `.glb` `game/assets/` altına.
- Dönüşüm Blender scriptiyle (`art/blender/`), elle değil. Blender headless: `blender -b -P script.py -- args`.
- Lisans: sadece CC0/izinli asset. Her yeni asset paketini `game/assets/CREDITS.md`'ye yaz.
- Mobil bütçe: karakter < 5k üçgen, bina < 2k üçgen, doku ≤ 1024px.
