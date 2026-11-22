# 009 — Pet bakımı arayüzü: durum çubukları + Ye / Dinlen / Oyna (ROADMAP 5.5 UI)

## Amaç
Bakım sistemi hazır (kurallar `game/src/care/pet_care_rules.gd`, ağ: `Services.net`). Oyuncunun petinin
tokluk/mutluluk/enerji değerlerini görmesi ve eylem yapabilmesi için arayüz.

## Dokunabileceğin dosyalar
- `game/src/ui/care_hud.gd`, `game/scenes/ui/care_hud.tscn` (yeni)
- `game/tests/test_care_hud.gd` (yeni)
- `game/scenes/main.tscn` — SADECE `UI` altına CareHud eklemek için
- `agy-tasks/done/009-bakim-hud.report.md`
Başka dosyaya dokunma (özellikle `pet_care_rules.gd`, tüm `src/net/*`, `network_sync.gd`, `player.gd`, `pet_visual.gd`).

## Hazır API'ler (oku, değiştirme)
- `Services.net.care_updated(state: Dictionary, ok: bool, reason: String)` — state = `{"food", "joy", "energy", "t"}` (0..100)
- `Services.net.send_care_action("eat" | "rest" | "play")`
- `PetCareRules` (preload `res://src/care/pet_care_rules.gd`): `decay(state, now)`, `mood(state) -> &"happy"|&"ok"|&"sad"`,
  `ACTIONS[eylem]["cooldown"]`, `near_spot("eat", pos)`
- Yerel oyuncu: `main.tscn` → `Player` (`global_position`), `player.visual.play_emote(&"emote_dance")` vb.

## Yapılacaklar
1. Sol üstte (mevcut "UniPet — Ortabahçe" etiketinin altına, "Pet" butonuyla çakışmadan) üç ince çubuk: Tokluk, Mutluluk,
   Enerji; ikon yerine kısa Türkçe etiket + yüzde. Renk: > 50 yeşil, 20-50 sarı, < 20 kırmızı.
   Son gelen duruma göre her saniye `decay` ile yerelde güncelle (sunucuya her saniye sorma).
2. Sağ alttaki chat butonunun üstüne dikey üç buton: **Ye**, **Dinlen**, **Oyna**.
   - **Ye**: sadece oyuncu `near_spot("eat", pos)` iken aktif; değilse soluk ve dokununca kısa uyarı
     ("Yemek için Yemekhane, Hokka ya da Kayıntı'ya git").
   - Her butonda kalan bekleme süresi (saniye) görünür; bekleme bitene kadar pasif. Bekleme, son başarılı eylemin yerel
     zamanından `ACTIONS[...]["cooldown"]` ile hesaplanır.
   - Basınca `send_care_action`; `care_updated` gelince `ok` ise kısa olumlu animasyon (Ye/Oyna → `emote_dance`,
     Dinlen → `emote_yes`; pette yoksa sessizce geç), `ok` false ise `reason`'ı 2 sn toast olarak göster.
3. Petin ruh hali (`mood`) "sad" ise çubukların üstünde küçük bir uyarı ("Petin acıktı/yoruldu/sıkıldı" — en düşük değere göre).
4. Mobil: butonlar ≥ 96 px, yazılar ≥ 26 px; dokunuşlar oyuna geçmesin. Joystick (sol alt) ve chat (sağ alt) ile çakışma yok.
5. Test: sahne yükleniyor; sahte `care_updated` verince çubuk değerleri doğru; düşük değerde doğru uyarı;
   bekleme süresi hesabı; yemek yerinden uzakta Ye butonu pasif. Sahte ağ için `game/src/net/fake_network_service.gd`'yi
   kullanabilirsin (değiştirme; yetmiyorsa test içinde küçük bir sahte düğüm yaz).

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Ekran görüntüsü `agy-tasks/done/009-bakim.png` (görüntü kodu repo DIŞINDA)

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık. Sihirli sayılar `const`. Görüntü kodu oyun koduna konmaz. `Services._ready()` çağrılmaz.
- git commit/push YAPMA (runner yapar).
- Rapor: `agy-tasks/done/009-bakim-hud.report.md`, Türkçe.
