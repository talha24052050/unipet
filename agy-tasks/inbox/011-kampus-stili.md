# 011 — Kampüs görsel stili: bina türü renkleri, kiremit çatılar, pencere şeritleri

## Amaç
Greybox binaları YTÜ'nün resmi kampüs haritasındaki çizim diline yaklaştırmak (referans, sadece stil için:
https://tanitim.yildiz.edu.tr/images/kampusler/harita-davutpasa.jpg — görseli KOPYALAMA/GÖMME, sadece renk ve tarz):
- Tarihi binalar (Kışla/Taşbina, Sanat ve Tasarım, Otağ-ı Hümayun, Sancak Köşkü, Tarihi Hamam, Mescit/Cami):
  krem duvar (#EFE3C8 civarı), kiremit kırmızısı kırma (hip) çatı (#B9473A civarı), beyaz pencere çerçeveleri.
- Modern fakülte/idari binalar: açık gri/beyaz duvar, koyu mavi-gri yatay pencere şeritleri, düz çatı (açık gri).
- Yurt/lojman (çok katlı): beyaz-krem, düzenli pencere ızgarası; bazılarında tuğla rengi vurgu.
- Zemin: çim canlı yeşil (#7DBA4F civarı), araç yolu (service) koyu gri (#4A4F55), yaya yolu krem/açık gri.
Mobil bütçe: ek doku dosyası YOK ya da en fazla 1 küçük (≤ 256px) doku; pencereler shader ile çizilir.

## Dokunabileceğin dosyalar
- `game/src/world/greybox_builder.gd` (sadece görünüm: malzeme seçimi, çatı mesh'i; çarpışma/geçit/zemin mantığına DOKUNMA)
- `game/src/world/building_style.gd` (yeni) — bina adı/kat/boyuttan stil seçimi (saf fonksiyonlar)
- `game/assets/shaders/building_wall.gdshader` (yeni) — dünya koordinatından pencere şeritleri/ızgara
- `game/tests/test_building_style.gd` (yeni)
- `agy-tasks/done/011-kampus-stili.report.md`
Başka dosyaya dokunma.

## Yapılacaklar
1. `building_style.gd`: `style_for(name: String, height: float, footprint_area: float) -> StringName` →
   `&"historic"` (isim listesi: Kışla, Taşbina, Sanat ve Tasarım, Otağ, Sancak, Hamam, Mescit, Cami — Türkçe karakter/büyük-küçük
   duyarsız eşleşme), `&"dorm"` (isimde Yurt/Blok harf+rakam kalıbı ve ≥ 4 kat ya da Lojman), `&"modern"` (diğer adlı ya da ≥ 2 kat),
   `&"small"` (adsız ve küçük: kulübe/depo — sade gri). Stil başına renk sabitleri burada.
2. `building_wall.gdshader` (spatial, `render_mode` mobil uyumlu, unshaded DEĞİL): duvar rengi + `world` Y ile kat çizgileri
   (kat yüksekliği 3.5 m) ve yatay konumla pencere aralıkları; uniform'lar: `wall_color`, `window_color`, `frame_color`,
   `style` (0 pencere şeridi, 1 pencere ızgarası, 2 tarihi: kemerli hissi için dikdörtgen + çerçeve). Çatı yüzeylerinde pencere
   çizilmesin (normal.y > 0.5 ise düz renk). Zemin katta kapı aralıklarına gerek yok.
3. Tarihi binalara kırma çatı: mevcut düz çatının üstüne, taban çokgeninin her kenarından içe doğru eğimli yüzeyler.
   Basit yöntem kabul: çokgenin içe ofsetini (Geometry2D.offset_polygon, -çatı derinliği) üst kenar olarak kullan, iki halka
   arasını üçgenle, iç halkayı düz kapat. Çatı yüksekliği 2-3 m. Çokgen ofseti başarısızsa düz çatıda kal (çökme yok).
   Halka şekilli binalarda (Kışla) da çalışmalı — test et.
4. Zemin/yol/çim renklerini yukarıdaki palete çek (`GreyboxBuilder`'daki renk sabitleri).
5. Test: `style_for` örnekleri (Kışla→historic, "C1 Blok" 5 kat→dorm, "Elektrik Elektronik Fakültesi"→modern, adsız 3 kat küçük→small);
   tüm bölgelerin (`game/data/zones/zones.json`) greybox'ı kurulunca SCRIPT ERROR yok ve tarihi binaların çatı mesh'i üretiliyor;
   shader derleniyor (ShaderMaterial ile bir MeshInstance oluşturup bir kare çiz).

## Kabul kriterleri
- [ ] `C:/Tools/Godot/godot --headless --path game --import` hatasız
- [ ] `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd` exit 0, çıktıda `SCRIPT ERROR` yok
- [ ] `C:/Tools/Godot/godot --headless --path game --quit-after 60` çıktısında `ERROR`/`SCRIPT ERROR` yok
- [ ] Ekran görüntüleri (kod repo DIŞINDA, `%TEMP%`): `agy-tasks/done/011-kisla.png` (Kışla'yı yukarıdan-eğik gören kamera),
      `agy-tasks/done/011-fef.png` (fef bölgesi). Zor gelirse atla, rapora yaz.

## Kurallar
- CLAUDE.md'ye uy. GDScript tipler açık. Sihirli sayılar `const`. `Services._ready()` çağırma.
- git commit/push YAPMA (runner yapar).
- Raporu iş bitmese de MUTLAKA yaz: `agy-tasks/done/011-kampus-stili.report.md` (Türkçe).
