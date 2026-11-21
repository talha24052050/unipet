# 006 — Hazır cümleler + emote menüsü + konuşma baloncuğu (ROADMAP 4.5)

## Amaç
Oyuncu serbest yazı yazmadan hazır cümle ve emote gönderebilsin; gönderilen cümle petin üstünde baloncukta,
emote ise petin animasyonu olarak görünsün. Ağ katmanı soyut: sadece `Services.net` kullan
(şu an `OfflineNetworkService` gönderilen mesajı hemen geri yansıtıyor; Nakama gelince aynı kod çalışacak).

## Dokunabileceğin dosyalar
- `game/data/chat/presets.json` (yeni)
- `game/src/ui/chat_menu.gd`, `game/scenes/ui/chat_menu.tscn` (yeni)
- `game/src/ui/chat_bubble.gd`, `game/scenes/ui/chat_bubble.tscn` (yeni)
- `game/src/net/chat_catalog.gd` (yeni)
- `game/tests/test_chat.gd` (yeni)
- `game/scenes/main.tscn` — SADECE `UI` altına chat menüsünü eklemek ve oyuncuya baloncuk bağlamak için
- `agy-tasks/done/006-hazir-chat-emote.report.md`
Bunların dışına dokunma (özellikle `player.gd`, `pet_visual.gd`, `chat_message.gd`, `network_service.gd`, `config.gd`).
Eksik bir şey varsa değiştirme, rapora yaz.

## Hazır API'ler (oku, değiştirme)
- `ChatMessage.preset(id)`, `ChatMessage.emote(id)`; alanlar `kind` (`ChatMessage.Kind.PRESET|EMOTE|FREE`), `payload`, `sender_id`
- `Services.net.send_chat(msg)`, sinyal `Services.net.chat_received(message: ChatMessage)`, `Services.net.local_player_id()`
- Oyuncu: `main.tscn` içindeki `Player` düğümü; `player.visual` bir PetVisual → `play_emote(&"emote_wave")` vb. `-> bool`
  Mantıksal emote adları: `emote_wave`, `emote_jump`, `emote_yes`, `emote_no`, `emote_dance` (bazı petlerde bazıları yok → false döner, sorun değil)

## Yapılacaklar
1. `presets.json`: `{"presets": [{"id": "...", "text": "..."}], "emotes": [{"id": "...", "anim": "emote_wave", "label": "..."}]}`.
   12-16 kampüs temalı, kısa, kibar Türkçe cümle (ör. "Selam!", "Yemekhaneye gidiyorum", "Hokka'da buluşalım mı?",
   "Sınav nasıl geçti?", "Kolay gelsin", "Görüşürüz!"). Emote'lar: el salla, zıpla, evet, hayır, dans.
2. `chat_catalog.gd` (RefCounted, class_name YOK): json'u yükler; `preset_text(id) -> String` (bilinmeyen id → ""),
   `emote_anim(id) -> StringName`, `presets()`, `emotes()`. Bilinmeyen id'li mesajlar GÖSTERİLMEZ (ağdan sahte id gelirse).
3. `chat_menu`: sağ altta yuvarlak bir "sohbet" butonu (joystick sol altta, çakışmasın). Basınca iki sekmeli panel açılır:
   Cümleler (liste) | Emote'lar (ızgara). Seçince `Services.net.send_chat(...)` ve panel kapanır.
   Gönderimler arası 1.5 sn bekleme (spam önleme), bu sürede butonlar pasif. Panel açıkken dokunuşlar oyuna geçmesin.
4. `chat_bubble`: 3D'de petin başının üstünde duran, kameraya bakan baloncuk (`Label3D` + arka plan ya da `Sprite3D`
   üzerinde SubViewport — basit olan). 4 sn sonra kaybolur; yeni mesaj eskisinin yerini alır.
5. `main.tscn`'de bağlantı: `chat_received` gelince `sender_id == Services.net.local_player_id()` ise yerel oyuncunun
   baloncuğunu göster (PRESET) ya da `player.visual.play_emote(anim)` (EMOTE). Uzak oyuncular sonra eklenecek: bu eşlemeyi
   `sender_id` → düğüm bulan küçük bir fonksiyonla yaz ki genişletmek kolay olsun (şimdilik sadece yerel oyuncu).
6. FREE türü mesajları `Config.FREE_CHAT_ENABLED` false iken gösterme.
7. Mobil: butonlar ≥ 96 px, yazılar ≥ 28 px.
8. Test (`test_chat.gd`, mevcut formatta): katalog yükleniyor, preset sayısı 12-16, bilinmeyen id boş dönüyor,
   tüm emote'ların `anim` değeri yukarıdaki mantıksal adlardan biri, menü sahnesi yükleniyor.

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0 (mevcut 45 + seninkiler)
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Ekran görüntüsü: `agy-tasks/done/006-chat.png` (menü açık ya da baloncuk görünür). Görüntü alma kodunu OYUN KODUNA
      KOYMA; ayrı bir `-s` scripti kullan ve onu repo dışına (`%TEMP%`) yaz.

## Kurallar
- CLAUDE.md ve docs/DECISIONS.md'ye uy. GDScript, tipler açık. Kullanıcıya görünen metinler Türkçe.
- `Services._ready()` gibi autoload iç fonksiyonlarını elle ÇAĞIRMA.
- git commit/push YAPMA (runner yapar).
- Rapor: `agy-tasks/done/006-hazir-chat-emote.report.md`, Türkçe.
