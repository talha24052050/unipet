# 007 — Uzak Oyuncular + Ağ Senkronu Raporu

## 1. Ne Yapıldı?
- **NetworkSync (`network_sync.gd`)**:
  - Ana sahneye (`main.tscn`) bağlanan tek ağ senkron yöneticisi düğümü (`Node`) yazıldı.
  - `_ready` aşamasında `Services.auth.get_access_token()` ile sunucuya bağlanır (`connect_to_server`), `connected` sinyali gelince bölgeye katılır (`join_zone("ortabahce")`), `room_joined` sinyali gelince yerel oyuncunun profilini (`send_profile`) sunucuya duyurur.
  - Saniyede `Config.NET_TICK_RATE` (10) sıklıkta yerel oyuncunun pozisyon, yaw ve güncel mantıksal animasyonunu sunucuya iletir (`send_state`).
  - Gönderim optimizasyonu: Konum değişimi < 2 cm, açı değişimi < 0.02 radyan ve animasyon aynı ise gereksiz paket gönderimi engellenir; ancak en az saniyede bir (heartbeat) durum tazelenir.
  - `player_joined` sinyaliyle gelen oyuncular için `RemotePlayer` düğümü oluşturulur (yerel oyuncu ID'si atlanır, aynı ID iki kez gelirse tekrar oluşturulmaz).
  - `player_left` sinyaliyle ilgili oyuncu sahneden kaldırılır ve bellekten temizlenir.
  - `disconnected` sinyali geldiğinde tüm uzak oyuncular temizlenir; 5 saniye aralıklarla en çok 5 kez yeniden bağlanma denenir.
  - Bağımlılık enjeksiyonu (`net` alanı) desteklenerek testlerde ve özel durumlarda sahte servislerle çalışabilmesi sağlandı.

- **RemotePlayer (`remote_player.gd` & `remote_player.tscn`)**:
  - `Node3D + PetVisual` yapısında oluşturuldu.
  - Ağdan gelen durumları zaman damgasıyla tampona (`_buffer`) alarak ~100 ms geriden yumuşak bir interpolasyonla (`Vector3.lerp` ve `lerp_angle`) oynatır.
  - Büyük sıçramalarda (> 5 m) ani ışınlanma (teleport) uygulanır.
  - Animasyon: Yatay hızdan otomatik `set_locomotion` hesaplanır; gelen durum bir emote (`emote_*`) ise `play_emote` tetiklenir.
  - Profil (`player_profile`) geldiğinde pet türü (`set_character`) ve aksesuarlar dinamik olarak yüklenir; bilinmeyen petlerde `Config.DEFAULT_PET_ID`, bilinmeyen aksesuarlarda atlama yapılır. Profil henüz gelmediyse varsayılan pet görünür.
  - Uzak oyuncuların başının üzerinde ID'nin ilk 6 karakterini gösteren billboard `Label3D` isim etiketi ve konuşma baloncuğu (`ChatBubble`) eklendi. Yükseklikler petin boyutuna (`visual.footprint()`) göre dinamik ayarlanır.

- **Chat Entegrasyonu (`main.tscn`)**:
  - `main.tscn` içindeki `_find_player_node(sender_id: String)` fonksiyonu `NetworkSync.get_remote_player(sender_id)` çağrısıyla genişletildi.
  - Gelen hazır cümle (`PRESET`) veya `EMOTE` mesajları, gönderen uzak oyuncunun konuşma baloncuğunda (`ChatBubble`) ve pet modelinde (`visual.play_emote`) kusursuz şekilde tetiklenir.

- **Sahte Ağ Servisi (`fake_network_service.gd`)**:
  - SADECE testler için, tüm `NetworkService` arayüzünü uygulayan ve sinyalleri programatik olarak elle tetiklenebilen (`simulate_*`), gönderilen verileri bellekte tutan sahte servis yazıldı.

- **Testler (`test_network_sync.gd`)**:
  - Görev tanımında istenen tüm senaryolar (katılma, çift katılma koruması, yerel ID filtreleme, ayrılma, profil güncelleme, interpolasyon hesaplaması, 5m ışınlanma, tick ve heartbeat gönderim kısıtlaması, kopma ve yeniden bağlanma zamanlayıcısı, `main.tscn` entegrasyonu) test edildi.

## 2. Dokunulan Dosyalar
Yalnızca görev tanımında açıkça izin verilen dosyalar oluşturuldu ve düzenlendi:
- `game/src/net/network_sync.gd` (yeni)
- `game/src/player/remote_player.gd` (yeni)
- `game/scenes/remote_player.tscn` (yeni)
- `game/src/net/fake_network_service.gd` (yeni)
- `game/tests/test_network_sync.gd` (yeni)
- `game/scenes/main.tscn` (düzenlendi — sadece NetworkSync düğümü ve `_find_player_node` genişletmesi eklendi)
- `agy-tasks/done/007-uzak-oyuncular.report.md` (yeni — bu rapor)

> Not: `player.gd`, `pet_visual.gd`, `network_service.gd`, `nakama_network_service.gd`, `offline_network_service.gd`, `services.gd`, `config.gd` gibi çekirdek dosyalara dokunulmadı. Git commit veya push yapılmadı.

## 3. Test Sonuçları
- `godot --headless --path game --import`: Hatasız tamamlandı (exit code 0).
- `godot_console.exe --headless --path game -s res://tests/run_tests.gd`:
  - **73 geçti, 0 başarısız** (Mevcut 63 test + yeni eklenen 10 ağ senkronizasyon testi).
  - Exit code 0.
- `godot_console.exe --headless --path game --quit-after 60`:
  - Çıktıda hiçbir `ERROR` veya `SCRIPT ERROR` yok (exit code 0).
- Offline modda oyun tek oyunculu olarak eskisi gibi sorunsuz çalışmaktadır.

## 4. Belirsiz Kalanlar / Notlar
- İsim etiketlerinde şu an oyuncu ID'sinin ilk 6 karakteri gösterilmektedir. ROADMAP Parça 3.4 (kullanıcı profili ve takma ad) tamamlandığında buraya gerçek kullanıcı adı bağlanacaktır.
- Ağ interpolasyon tamponu ve 100 ms gecikme yerel ve orta düzey gecikmelerde oldukça yumuşak çalışmaktadır; ileride yüksek paket kaybı veya jitter olan bağlantılar için istemci taraflı ekstrapolasyon veya değişken tampon süresi (dead reckoning) düşünülebilir.
