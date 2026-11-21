# 007 — Uzak oyuncular + ağ senkronu (ROADMAP 4.4 oyun tarafı)

## Amaç
Odadaki diğer oyuncular kendi petleri ve aksesuarlarıyla görünsün ve yumuşakça hareket etsin; yerel oyuncunun durumu
saniyede `Config.NET_TICK_RATE` kez gönderilsin. Sadece `Services.net` arayüzünü kullan
(şu an `OfflineNetworkService`; Nakama da aynı sinyalleri verir). Ağ servislerinin kendisine dokunma.

## Dokunabileceğin dosyalar
- `game/src/net/network_sync.gd` (yeni) — ana sahnede tek düğüm
- `game/src/player/remote_player.gd`, `game/scenes/remote_player.tscn` (yeni)
- `game/src/net/fake_network_service.gd` (yeni, SADECE testler için: sinyalleri elle tetiklenebilen sahte servis)
- `game/tests/test_network_sync.gd` (yeni)
- `game/scenes/main.tscn` — SADECE NetworkSync düğümünü eklemek için
- `game/src/ui/chat_menu.gd` / ilgili baloncuk eşleme fonksiyonu — SADECE uzak oyuncunun baloncuğu/emote'u için `sender_id → düğüm` eşlemesini NetworkSync'e bağlamak için (006'nın bıraktığı genişletme noktası)
- `agy-tasks/done/007-uzak-oyuncular.report.md`
Başka dosyaya dokunma (`player.gd`, `pet_visual.gd`, `network_service.gd`, `nakama_network_service.gd`, `offline_network_service.gd`, `services.gd`, `config.gd`).

## Hazır API'ler (oku, değiştirme)
- `Services.net` sinyalleri: `connected`, `disconnected(reason)`, `room_joined(room_id)`, `player_joined(id, state)`,
  `player_left(id)`, `player_state(id, state)`, `player_profile(id, {"pet": StringName, "acc": {slot: id}})`, `chat_received(msg)`
- `Services.net`: `connect_to_server(token)`, `join_zone("ortabahce")`, `send_state({"pos": Vector3, "yaw": float, "anim": String})`,
  `send_profile(pet_id, accessories)`, `local_player_id()`
- `Services.auth.get_access_token()`, `Services.characters.get_def(id)`, `Services.accessories.get_def(id)`
- Yerel oyuncu: `Player` düğümü; `player.character_id`, `player.visual` (PetVisual: `set_character`, `equip`, `set_locomotion(hız)`,
  `play_emote(ad) -> bool`, `current_logical() -> StringName`, `equipped_ids() -> {slot: id}`)
- `res://src/core/local_profile.gd` → `LocalProfile.load_or_default()`

## Yapılacaklar
1. `NetworkSync` (Node): `_ready`'de `connect_to_server(Services.auth.get_access_token())` → `connected` gelince `join_zone("ortabahce")`
   → `room_joined` gelince `send_profile(...)` (yerel oyuncunun pet + aksesuarları). Sonra her `1.0 / Config.NET_TICK_RATE` saniyede
   `send_state` (pos, yaw = player.rotation.y, anim = `player.visual.current_logical()`). Durum değişmediyse (konum < 2 cm, yaw < 0.02,
   anim aynı) her tick gönderme, ama en az saniyede bir gönder.
2. `RemotePlayer` (Node3D + PetVisual): gelen durumlar arasında interpolasyon. Durumları zaman damgasıyla tampona al,
   ~100 ms geriden oynat (tipik "interpolation delay"); arada kalınca son iki durum arasında lerp, yaw için `lerp_angle`.
   Büyük sıçrama (> 5 m) varsa ışınla. Animasyon: hızdan `set_locomotion`, ya da gelen anim bir emote ise `play_emote`.
   Profil gelince `set_character` + aksesuarlar (bilinmeyen pet → `Config.DEFAULT_PET_ID`, bilinmeyen aksesuar → atla).
   Profil henüz gelmediyse varsayılan pet görünsün.
3. `player_joined` → RemotePlayer oluştur (yerel id'yi atla, aynı id iki kez gelirse tekrar oluşturma); `player_left` → kaldır;
   `disconnected` → hepsini kaldır ve 5 sn sonra yeniden bağlanmayı dene (en çok 5 deneme, sonra dur).
4. Uzak oyuncuların üstünde küçük isim etiketi (`Label3D`, billboard): şimdilik id'nin ilk 6 karakteri (Parça 3.4'te kullanıcı adı gelecek).
5. Chat: 006'nın `sender_id → düğüm` eşleme fonksiyonunu uzak oyuncuları da bulacak şekilde NetworkSync'e bağla
   (baloncuk + emote uzak oyuncuda da çalışsın).
6. Test (`test_network_sync.gd`): `fake_network_service.gd` ile — join → RemotePlayer oluşur; aynı id ikinci kez → tek düğüm;
   state'ler → interpolasyon iki durum arasında bir konum verir; left → düğüm silinir; profil → doğru pet; yerel id atlanır;
   gönderim kısıtlaması (değişmeyen durum her tick gönderilmez). Sahte servisi `Services.net`'e KOYMA; NetworkSync'e
   bağımlılık enjeksiyonu ile ver (ör. `var net: Node` alanı, boşsa `Services.net`).

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Offline modda oyun eskisi gibi çalışıyor (tek oyuncu, uzak oyuncu yok, hata yok)

## Kurallar
- CLAUDE.md ve docs/DECISIONS.md'ye uy. GDScript, tipler açık. Sihirli sayılar dosya başında `const` olarak.
- `Services._ready()` gibi autoload iç fonksiyonlarını ÇAĞIRMA. Görüntü alma kodunu oyun koduna KOYMA.
- git commit/push YAPMA (runner yapar).
- Rapor: `agy-tasks/done/007-uzak-oyuncular.report.md`, Türkçe.
