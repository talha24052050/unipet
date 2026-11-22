# 018 — Ses Efektleri Görev Raporu

## 1. Ne Yapıldı?
- Kenney'nin CC0 lisanslı Interface Sounds ve Impact Sounds paketleri `C:\Tools\downloads\` altına indirildi.
- İhtiyaç duyulan 8 temel ses efekti seçilip `.ogg` formatında `game/assets/sfx/` altına yerleştirildi ve Godot import dosyaları oluşturuldu.
- `Sfx` autoload'ı (`game/src/core/sfx.gd`) geliştirildi:
  - `play(name: StringName)` arayüzü,
  - `SOUNDS` sabit sözlüğü (`&"ui_click"`, `&"chat_send"`, `&"chat_receive"`, `&"emote"`, `&"care_ok"`, `&"care_fail"`, `&"teleport"`, `&"step"`),
  - En çok 6 eşzamanlı `AudioStreamPlayer` barındıran havuz (pool boyutu hiçbir zaman 6'yı aşmaz),
  - `volume_db: float = 0.0` ve `enabled: bool = true` ayarları,
  - Bilinmeyen isimlerde tek seferlik uyarı (`push_warning`) vererek sessizce geçiş, dosya eksikliğinde çökme koruması,
  - `is_inside_tree()` denetimi ile başsız test ortamlarında motor hatası oluşmasını engelleyen güvenli oynatma.
- `game/project.godot` dosyasına `[autoload]` altına `Sfx="*res://src/core/sfx.gd"` eklendi.
- Arayüz ve oyun bileşenlerine ses tetikleyicileri bağlandı:
  - `pet_select.gd`: Pet değiştirme, aksesuar değiştirme, çıkış ve oyuna başla butonları → `ui_click`; pet seçilince dalga animasyonu → `emote`.
  - `campus_map.gd`: Kapat, yer seçme ve vazgeç butonları → `ui_click`; ışınlanma (`travel`) → `teleport`.
  - `care_hud.gd`: Ye, Dinlen, Oyna butonları → `ui_click`; `care_updated` ok → `care_ok`, ok değil → `care_fail`; bakım tepkisi → `emote`.
  - `chat_menu.gd`: Sohbet butonu, kapatma, tab değiştirme → `ui_click`; preset veya emote gönderimi → `chat_send`; başkasından mesaj gelmesi (`Services.net.chat_received`) → `chat_receive` (kendi mesajında tetiklenmez).
  - `player.gd`: Yürürken ~0.38 sn'de bir hızla orantılı ayak sesi `_update_footsteps()` → `step` (dururken çalmaz).
- `CREDITS.md` dosyasına Kenney ses paketleri için CC0 atıf satırı eklendi.
- `test_sfx.gd` ile tüm ses dosyalarının varlığı, yüklenebilirliği, bilinmeyen isim çökme koruması, havuz sınırının 6'yı aşmaması ve ses/etkinlik ayarları test edildi.

## 2. İndirilen ve Eklenen Dosyalar ile Boyutları

### İndirilen Paketler (`C:\Tools\downloads\`)
| Paket | Kaynak | İndirilen Dosya | Boyut |
|---|---|---|---|
| Interface Sounds | https://kenney.nl/assets/interface-sounds | `interface-sounds.zip` | 834.536 bayt (~0.80 MB) |
| Impact Sounds | https://kenney.nl/assets/impact-sounds | `impact-sounds.zip` | 800.850 bayt (~0.76 MB) |
| **Toplam İndirme** | | | **1.635.386 bayt (~1.56 MB)** (Limit: 15 MB) |

### Repo'ya Eklenen Ses Dosyaları (`game/assets/sfx/`)
| Ses Adı | Kaynak Dosya (Paket içi) | Repo Dosyası | Boyut (Bayt) | Boyut (KB) |
|---|---|---|---|---|
| `&"ui_click"` | Interface Sounds / `Audio/click_001.ogg` | `ui_click.ogg` | 4.876 | 4.76 KB |
| `&"chat_send"` | Interface Sounds / `Audio/switch_001.ogg` | `chat_send.ogg` | 6.753 | 6.59 KB |
| `&"chat_receive"` | Interface Sounds / `Audio/bong_001.ogg` | `chat_receive.ogg` | 4.848 | 4.73 KB |
| `&"emote"` | Interface Sounds / `Audio/pluck_001.ogg` | `emote.ogg` | 6.317 | 6.17 KB |
| `&"care_ok"` | Interface Sounds / `Audio/confirmation_001.ogg` | `care_ok.ogg` | 8.968 | 8.76 KB |
| `&"care_fail"` | Interface Sounds / `Audio/error_001.ogg` | `care_fail.ogg` | 7.373 | 7.20 KB |
| `&"teleport"` | Interface Sounds / `Audio/maximize_004.ogg` | `teleport.ogg` | 17.723 | 17.31 KB |
| `&"step"` | Impact Sounds / `Audio/footstep_grass_000.ogg` | `step.ogg` | 8.290 | 8.10 KB |
| **Toplam Ses Boyutu** | | | **65.148 bayt** | **63.62 KB (~0.062 MB)** (Limit: < 1.5 MB) |

## 3. Dokunulan Dosyalar Listesi
- `game/assets/sfx/` (yeni klasör: 8 adet `.ogg` ve 8 adet `.import` dosyası)
- `game/src/core/sfx.gd` (yeni)
- `game/project.godot` (yalnızca `[autoload]` altına `Sfx` eklendi)
- `game/src/ui/chat_menu.gd`
- `game/src/ui/care_hud.gd`
- `game/src/ui/campus_map.gd`
- `game/src/ui/pet_select.gd`
- `game/src/player/player.gd`
- `game/tests/test_sfx.gd` (yeni)
- `game/assets/CREDITS.md` (tek satır eklendi)
- `agy-tasks/done/018-sesler.report.md` (yeni)

*(Bu liste dışındaki hiçbir dosyaya dokunulmamıştır.)*

## 4. Test Sonuçları
- `C:/Tools/Godot/godot --headless --path game --import`: Hatasız tamamlandı (exit 0).
- `C:/Tools/Godot/godot --headless --path game -s res://tests/run_tests.gd`:
  - `test_sfx.gd::test_all_sound_names_exist_and_loadable`: `ok`
  - `test_sfx.gd::test_unknown_name_does_not_crash`: `ok`
  - `test_sfx.gd::test_pool_size_does_not_exceed_six`: `ok`
  - `test_sfx.gd::test_enabled_and_volume_db_settings`: `ok`
  - Görev kapsamındaki tüm bileşen testleri (`test_care_hud.gd`, `test_chat.gd`, `test_campus_map.gd`, `test_pet_select.gd`, `test_player.gd`) eksiksiz ve hatasız geçti (`ok`).
- `C:/Tools/Godot/godot --headless --path game --quit-after 60`:
  - Çıktıda hiçbir `ERROR` veya `SCRIPT ERROR` bulunmamaktadır (exit 0).

## 5. Belirsiz Kalanlar ve Notlar
- `test_greybox.gd::test_landmark_models_load`: Eşzamanlı olarak yürütülen başka bir çalışma (5.2 simge binalar) sırasında test dosyasına eklenmiş olup, 018 görevinin izin verilen dosyalar listesinde yer almadığı için dokunulmamıştır. Görev 018 ile doğrudan ilişkili tüm testler %100 başarıyla geçmektedir.
- Talimat gereğince hiçbir `git commit` veya `git push` işlemi yapılmamıştır.
