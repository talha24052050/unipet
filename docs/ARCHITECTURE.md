# Mimari

```
unipet/
├─ game/                  Godot projesi (res://)
│  ├─ src/core/           autoload'lar: Config, Services
│  ├─ src/net/            NetworkService (soyut) + Offline / Nakama implementasyonları, ChatMessage
│  ├─ src/auth/           AuthService (soyut) + Mock / Supabase implementasyonları
│  ├─ src/characters/     CharacterDef (Resource), CharacterRegistry
│  ├─ src/player/         hareket (joystick + dokun-yürü), kamera, pet kontrolcüsü
│  ├─ scenes/             .tscn sahneler
│  ├─ data/characters/    pet tanımları (.tres)
│  ├─ assets/             import edilmiş modeller (glb), doku, ui
│  └─ tests/              run_tests.gd + test_*.gd
├─ server/                Nakama modülleri (TypeScript) + docker-compose (Parça 4)
├─ art/blender/           Blender Python scriptleri (FBX→glb dönüşüm, kampüs üretimi)
├─ art/reference/         referans fotoğraflar, OSM verisi
├─ agy-tasks/             Antigravity görev kutusu (inbox → done)
├─ tools/agy-runner/      görev kutusunu işleyen PowerShell scripti
├─ tools/osm/             OSM → greybox bölge JSON (game/data/zones/), GreyboxBuilder sahneye kurar
└─ docs/                  kararlar, yol haritası, mimari
```

## Değiştirilebilirlik ilkeleri
1. **Servis katmanı:** `Services.net/auth/characters`. Backend değişimi oyun kodunu etkilemez.
2. **Veri odaklı karakter:** model, animasyon adları, aksesuar kemikleri `.tres` içinde.
   Mantıksal animasyonlar (zorunlu): `idle, walk, run, emote_wave, emote_jump`; isteğe bağlı: `emote_yes, emote_no, emote_dance`.
   `animation_speed` ile hız çarpanı (ör. koşusu olmayan blob'larda run = 1.6× walk).
   `.tres`'ler elle değil `tools/assets/make_pet_defs.py` ile üretilir.
   Aksesuar slotları: `head, face, neck, back`.
3. **Tek mesaj formatı:** `ChatMessage{kind, payload, sender_id, t}`.
4. **Ağ durumu:** `{pos: Vector3, yaw: float, anim: String}`; saniyede `Config.NET_TICK_RATE` kez,
   karşı tarafta interpolasyon. Hareket girişi (joystick/dokun) yerel karakteri yürütür, ağ sadece sonucu taşır.
5. **Bölge/oda:** `zone_id` (ör. `ortabahce`) → sunucu `ortabahce-1`, `ortabahce-2` kanallarına dağıtır.
