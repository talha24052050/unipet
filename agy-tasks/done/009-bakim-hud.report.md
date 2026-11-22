# 009 — Pet Bakımı Arayüzü (Care HUD) Görev Raporu

## 1. Neler Yapıldı?
- **Durum Çubukları (Sol Üst)**:
  - Mevcut "UniPet — Ortabahçe" başlığının altına, sağ üstteki "Pet" butonuyla çakışmayacak şekilde üç ince durum çubuğu eklendi: **Tokluk**, **Mutluluk**, **Enerji**.
  - İkon yerine kısa Türkçe etiket ve yüzde değeri (`Tokluk %80` vb.) gösterildi.
  - Değer aralıklarına göre dinamik renkler uygulandı: `> 50` yeşil, `20 - 50` sarı, `< 20` kırmızı.
  - Son gelen duruma göre her saniye `PetCareRules.decay` ile yerel azalma simülasyonu çalıştırıldı (sunucuya her saniye istek atılmaz).
- **Ruh Hali Uyarısı**:
  - Petin genel ruh hali (`PetCareRules.mood`) "sad" durumuna düştüğünde en düşük değere göre çubukların hemen üstünde küçük bir uyarı gösterildi ("Petin acıktı", "Petin yoruldu", "Petin sıkıldı").
- **Bakım Butonları (Sağ Alt)**:
  - Sağ alttaki sohbet (Chat) butonunun dikey olarak hemen üstüne üç buton yerleştirildi: **Ye**, **Dinlen**, **Oyna**.
  - **Ye Butonu**: Oyuncu yemek yerlerinden birine yakın değilse (`PetCareRules.near_spot("eat", pos)` false ise) soluk (`modulate.a = 0.45`) görünür. Dokunulduğunda ağa istek atmadan kısa toast uyarısı verir ("Yemek için Yemekhane, Hokka ya da Kayıntı'ya git"). Yemek alanındayken tam opak ve aktif hale gelir.
  - **Bekleme Süresi (Cooldown)**: Son başarılı eylemin yerel zamanından `PetCareRules.ACTIONS[action]["cooldown"]` ile hesaplanır. Bekleme sürerken buton pasif (`disabled = true`) kalır ve buton üzerinde kalan saniye (`Ye (540s)` vb.) gösterilir. Süre bitince tekrar aktifleşir.
  - **Eylem Gönderimi ve Geri Bildirim**: Butona basıldığında `Services.net.send_care_action` çağrılır. `care_updated` geldiğinde:
    - Başarılı (`ok = true`) ise: Ye/Oyna için `emote_dance`, Dinlen için `emote_yes` oynatılır (pette yoksa sessizce geçilir).
    - Başarısız (`ok = false`) ise: Gelen `reason` metni 2 saniye süreyle toast olarak ekranda gösterilir.
- **Mobil Ergonomi ve Kontroller**:
  - Butonlar ≥ 96 px (`custom_minimum_size = Vector2(96, 96)`).
  - Tüm yazılar ≥ 26 px (`font_size = 26`).
  - Dokunuşların 3D dünyaya ve tap-to-move'a sızmaması için buton ve panellerde `mouse_filter = MOUSE_FILTER_STOP` uygulandı.
  - Sol alttaki joystick ve sağ alttaki chat menüsüyle hiçbir çakışma yaşanmayacak şekilde yerleşim yapıldı.
- **Ekran Görüntüsü**:
  - Repo dışındaki harici bir GDScript betiği üzerinden `main.tscn` sahnesi çalıştırılarak `agy-tasks/done/009-bakim.png` ekran görüntüsü üretildi. Oyun koduna hiçbir görüntüleme kodu eklenmedi.

## 2. Dokunulan / Eklenen Dosyalar
- `game/src/ui/care_hud.gd` (yeni): Care HUD arayüz mantığı, çubuk güncellemeleri, buton durumları ve toast kontrolcüsü.
- `game/scenes/ui/care_hud.tscn` (yeni): Durum çubukları paneli, dikey Ye/Dinlen/Oyna butonları ve toast konteyneri.
- `game/tests/test_care_hud.gd` (yeni): HUD yüklenme, mobil boyut/font kuralları, çubuk renkleri, mood uyarıları, cooldown hesabı, yemek alanı kontrolü, eylem/emote akışı ve main.tscn entegrasyonu testleri.
- `game/scenes/main.tscn`: Sadece `UI` CanvasLayer'ı altına `CareHud` örneği eklendi.
- `agy-tasks/done/009-bakim.png` (yeni): Görevin görsel kabul kriterini belgeleyen ekran görüntüsü.
- `agy-tasks/done/009-bakim-hud.report.md` (yeni): Bu rapor dosyası.

## 3. Test Sonuçları
- `C:/Tools/Godot/godot --headless --path game --import`: Hatasız tamamlandı.
- `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd`:
  - **104 geçti, 0 başarısız** (Tüm mevcut testler + 7 yeni CareHud testi sorunsuz geçti, exit code 0).
- `C:/Tools/Godot/godot --headless --path game --quit-after 60`:
  - Çıktıda hiçbir `ERROR` veya `SCRIPT ERROR` bulunmuyor, exit code 0.

## 4. Belirsiz Kalanlar / Notlar
- Belirsiz kalan veya çözümsüz bir konu bulunmamaktadır. Tüm isterler ve kabul kriterleri eksiksiz karşılanmıştır.
