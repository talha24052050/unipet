extends Node
## Oyun genelindeki ayarlar. Gizli anahtar BURAYA YAZILMAZ;
## Supabase/Nakama bilgileri ileride user://secrets.cfg veya export ayarından okunacak.

## Okul maili zorunlu mu? Şimdilik kapalı (Talha, 2026-11-21): her geçerli mail girebilir.
## Açılırsa sunucuda da açılmalı: Nakama UNIPET_REQUIRE_SCHOOL_EMAIL=true + Supabase hook (docs/SUPABASE.md).
const REQUIRE_SCHOOL_EMAIL: bool = false
## Okul maili zorunluyken izin verilen domainler.
const ALLOWED_EMAIL_DOMAINS: PackedStringArray = ["std.yildiz.edu.tr"]

## Yasal sayfalar (GitHub Pages, site/ klasörü). Play Store'da da aynı adresler verilir.
const SITE_URL: String = "https://talha24052050.github.io/unipet"
const PRIVACY_URL: String = SITE_URL + "/gizlilik.html"
const TERMS_URL: String = SITE_URL + "/kosullar.html"
const ACCOUNT_DELETE_URL: String = SITE_URL + "/hesap-silme.html"

## Bir bölge odasının (kanal) maksimum oyuncu sayısı.
const ROOM_CAPACITY: int = 40

## Pozisyon senkron frekansı (saniyede gönderim).
const NET_TICK_RATE: int = 10

## Gerçek kampüs yer şekilleri (DEM yükseklik haritası). false yapılırsa tüm dünya düz y=0 olur.
const TERRAIN_ENABLED: bool = true

## Serbest yazılı sohbet (80 karakter sınırı + Türkçe argo/spam filtresi ile açık).
var FREE_CHAT_ENABLED: bool = true

## Aktif servis implementasyonları. Değiştirmek = bu satırı değiştirmek.
## Yayın derlemesi (export preset'inde custom feature "unipet_release"): gerçek giriş + sunucu.
## Geliştirme derlemesi: sahte giriş (000 / 000000) + tek oyunculu (sunucu adresi girilirse Nakama).
var IS_RELEASE: bool = OS.has_feature("unipet_release")
## Geliştirici modu (Ayarlar'dan açılıp kapanır; bkz. LocalSettings.dev_mode). Açık: sahte giriş, giriş ekranı yok.
var DEV_MODE: bool = false
var NETWORK_BACKEND: String = "nakama" if IS_RELEASE else "offline"  # "offline" | "nakama"
var AUTH_BACKEND: String = "supabase"  # "mock" | "supabase" — apply_dev_mode belirler


func _init() -> void:
	apply_dev_mode(preload("res://src/core/local_settings.gd").load_or_default().dev_mode)


## Modu uygular (Services.reload_auth ile birlikte kullanılır).
func apply_dev_mode(setting: int) -> void:
	DEV_MODE = preload("res://src/core/local_settings.gd").resolve_dev_mode(setting, IS_RELEASE, OS.has_feature("editor"))
	AUTH_BACKEND = "mock" if DEV_MODE else "supabase"

## Oyuncu hareketi (metre/saniye, radyan/saniye).
const PLAYER_WALK_SPEED: float = 4.6
const PLAYER_ACCELERATION: float = 20.0
const PLAYER_TURN_SPEED: float = 10.0
## Şimdilik koşu yok (hız tek); koşu eklenince run animasyonu bu hızda devreye girer.
const PLAYER_RUN_SPEED: float = 7.0
## Yerden kopmadan inilebilecek basamak/eğim için yere yapışma mesafesi.
const PLAYER_FLOOR_SNAP: float = 0.4

## Pet görünümü. Seçim ekranı (2.6) gelene kadar bu pet kullanılır.
const DEFAULT_PET_ID: StringName = &"mushnub"
## Bu hızın altı "duruyor" sayılır (m/s).
const PET_IDLE_SPEED: float = 0.2
## Animasyon geçiş süresi (saniye).
const PET_ANIM_BLEND: float = 0.15
## Model genişliğinin ne kadarı çarpışmaya girsin (yuvarlak blob'lar köşelerden sıkışmasın).
const PET_COLLISION_RADIUS_FACTOR: float = 0.8

## Kampüs keşfi: bir yere bu kadar yaklaşınca keşfedilir (m); ışınlandıktan sonra en az bu kadar yürümek gerekir (m).
const DISCOVER_RADIUS: float = 22.0
const DISCOVER_MIN_WALK: float = 30.0

## Sanal joystick (piksel; 720x1280 tasarım çözünürlüğüne göre).
const JOYSTICK_RADIUS: float = 110.0
const JOYSTICK_DEADZONE: float = 0.15
## Joystick'in dokunuş kabul ettiği bölge: ekranın sol-alt kısmı (oran).
const JOYSTICK_ZONE_WIDTH: float = 0.5
const JOYSTICK_ZONE_HEIGHT: float = 0.4

## Dokun-yürü: bu sınırların altındaki dokunuş "tıklama" sayılır (daha uzunu kamera sürüklemesi).
const TAP_MAX_MOVE_PX: float = 24.0
const TAP_MAX_DURATION_S: float = 0.35
## Raycast uzunluğu (metre).
const TAP_RAY_LENGTH: float = 200.0

## Takip kamerası (metre, derece; pitch negatif = yukarıdan bakış).
const CAMERA_DISTANCE_DEFAULT: float = 8.0
const CAMERA_DISTANCE_MIN: float = 3.5
const CAMERA_DISTANCE_MAX: float = 14.0
const CAMERA_PITCH_DEFAULT_DEG: float = -35.0
const CAMERA_PITCH_MIN_DEG: float = -75.0
const CAMERA_PITCH_MAX_DEG: float = -10.0
const CAMERA_TARGET_HEIGHT: float = 1.0
const CAMERA_FOLLOW_SHARPNESS: float = 10.0
## Radyan / piksel.
const CAMERA_ROTATE_SENSITIVITY: float = 0.006
const CAMERA_WHEEL_STEP: float = 0.8
