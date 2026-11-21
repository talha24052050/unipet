# 006 — Hazır Cümleler + Emote Menüsü + Konuşma Baloncuğu Raporu

## 1. Ne Yapıldı?
- **Chat Kataloğu (`presets.json` & `chat_catalog.gd`)**:
  - 14 adet kampüs temalı, kısa ve kibar Türkçe hazır cümle tanımlandı ("Selam!", "Günaydın!", "Yemekhaneye gidiyorum", "Hokka'da buluşalım mı?", "Kütüphaneye geçiyorum", "Ortabahçe'deyim", "Derse yetişmem lazım", "Sınav nasıl geçti?", "Kolay gelsin!" vb.).
  - 5 adet mantıksal animasyona (`emote_wave`, `emote_jump`, `emote_yes`, `emote_no`, `emote_dance`) bağlı emote eklendi ("El Salla", "Zıpla", "Evet", "Hayır", "Dans").
  - `chat_catalog.gd` (RefCounted, `class_name` olmadan) dosyası yazıldı. JSON dosyasını yükler, `preset_text(id)` ve `emote_anim(id)` fonksiyonlarıyla geçerli değerleri döner; sahte/bilinmeyen id'ler için boş değer döndürerek ağdan gelebilecek geçersiz mesajların gösterilmesini engeller.
- **Sohbet Menüsü (`chat_menu.gd` & `chat_menu.tscn`)**:
  - Ekranın sağ altına mobil dokunmatik kullanıma uygun (104x104 px, ≥ 96 px) yuvarlak "💬" sohbet butonu eklendi (sol alttaki joystick bölgesiyle çakışmaz).
  - Butona tıklandığında iki sekmeli panel açılır: "Cümleler" (dikey liste) ve "Emote'lar" (2 sütunlu ızgara).
  - Seçim yapıldığında `Services.net.send_chat(...)` çağrılır ve panel otomatik kapanır.
  - Spam önleme için gönderimler arası 1.5 saniye cooldown (bekleme) mekanizması kuruldu; bu sürede chat butonu ve seçenekler pasifleşir (`disabled`).
  - Panel açıldığında tam ekran `mouse_filter = Control.MOUSE_FILTER_STOP` overlay (`Backdrop`) sayesinde dokunuşlar arkadaki oyuna ve joystick'e geçmez; arka plana dokunulduğunda panel kapanır.
  - Tüm butonlar ≥ 96 px yükseklikte ve yazılar ≥ 28 px font boyutunda yapılarak mobil tasarım kurallarına tam uyuldu.
- **Konuşma Baloncuğu (`chat_bubble.gd` & `chat_bubble.tscn`)**:
  - Petin başının üstünde duran (`Sprite3D` + `SubViewport` ile kameraya bakan / billboard) konuşma baloncuğu oluşturuldu.
  - Pet görselinin yüksekliğini (`footprint().y`) otomatik okuyarak baloncuğu pet modelinin üstüne konumlandırır.
  - Mesaj gösterildiğinde 4 saniye sonra otomatik kaybolur; yeni mesaj geldiğinde eskisinin yerini alıp süreyi 4 saniyeye sıfırlar.
- **Sahne Bağlantısı (`main.tscn`)**:
  - `Player` altına `ChatBubble` bağlandı.
  - `UI` (CanvasLayer) altına `ChatMenu` eklendi.
  - `main.tscn` kök düğümündeki GDScript ile `Services.net.chat_received` sinyali dinlendi: `sender_id == Services.net.local_player_id()` eşleşmesiyle yerel oyuncunun baloncuğunda `PRESET` mesajı gösterilir veya `player.visual.play_emote(anim)` ile emote oynatılır. İleride çok oyunculu sisteme genişletilebilecek şekilde `_find_player_node(sender_id)` fonksiyonu ile ayrıştırıldı.
  - `Config.FREE_CHAT_ENABLED == false` iken serbest metin mesajlarının gösterilmemesi sağlandı.
- **Testler (`test_chat.gd`)**:
  - Katalog yükleme, 12-16 arası preset sayısı (14 adet), bilinmeyen id'lerde boş dönme, tüm emote animasyonlarının izin verilen 5 mantıksal addan biri olması, chat menüsü sahnesinin yüklenmesi, buton boyutları (≥ 96 px) ve font boyutları (≥ 28 px), cooldown / spam önleme davranışı, baloncuk zamanlayıcısı ve mesaj değişimi, `main.tscn` entegrasyonu ve sinyal yönlendirmesi test edildi.
- **Ekran Görüntüsü**:
  - Repo dışındaki geçici script ile (`$env:TEMP/capture_chat.gd`) menü açık ve konuşma baloncuğu görünür vaziyette `agy-tasks/done/006-chat.png` üretildi.

## 2. Dokunulan Dosyalar
Sadece görev tanımında izin verilen dosyalar oluşturuldu ve düzenlendi:
- `game/data/chat/presets.json` (yeni)
- `game/src/net/chat_catalog.gd` (yeni)
- `game/src/ui/chat_menu.gd` (yeni)
- `game/scenes/ui/chat_menu.tscn` (yeni)
- `game/src/ui/chat_bubble.gd` (yeni)
- `game/scenes/ui/chat_bubble.tscn` (yeni)
- `game/tests/test_chat.gd` (yeni)
- `game/scenes/main.tscn` (düzenlendi — sadece UI altına ChatMenu ve Player altına ChatBubble bağlandı)
- `agy-tasks/done/006-chat.png` (yeni — ekran görüntüsü)
- `agy-tasks/done/006-hazir-chat-emote.report.md` (yeni — bu rapor)

> Not: `player.gd`, `pet_visual.gd`, `chat_message.gd`, `network_service.gd`, `config.gd` gibi çekirdek dosyalara kesinlikle dokunulmadı. Git commit veya push yapılmadı.

## 3. Test Sonuçları
- `godot --headless --path game --import --quit`: Hatasız tamamlandı (exit code 0).
- `godot_console.exe --headless --path game -s res://tests/run_tests.gd`:
  - **57 geçti, 0 başarısız** (Mevcut 45 test + yeni eklenen 12 test fonksiyonu/kapsamı).
  - Exit code 0.
- `godot_console.exe --headless --path game --quit-after 60`:
  - Çıktıda hiçbir `ERROR` veya `SCRIPT ERROR` bulunmuyor (temiz çıkış, exit code 0).
- Ekran görüntüsü: `agy-tasks/done/006-chat.png` (73 KB) oluşturuldu.

## 4. Belirsiz Kalanlar / Notlar
- Çok oyunculu (Nakama) Parça 4'e geçildiğinde, `main.tscn` içerisindeki `_find_player_node(sender_id: String) -> Node3D` fonksiyonu uzak oyuncuların düğüm sözlüğüne bakacak şekilde kolaylıkla genişletilebilir.
- Serbest chat (`Kind.FREE`) şu an `Config.FREE_CHAT_ENABLED = false` olduğu için filtreleme / güvenlik gereği gösterilmemektedir; ileride bu konfigürasyon açıldığında baloncuk altyapısı doğrudan serbest metinleri de gösterecek şekilde hazırdır.
