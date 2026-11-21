extends Node
## Oyun genelindeki ayarlar. Gizli anahtar BURAYA YAZILMAZ;
## Supabase/Nakama bilgileri ileride user://secrets.cfg veya export ayarından okunacak.

## Giriş izni verilen mail domainleri.
const ALLOWED_EMAIL_DOMAINS: PackedStringArray = ["std.yildiz.edu.tr"]

## Bir bölge odasının (kanal) maksimum oyuncu sayısı.
const ROOM_CAPACITY: int = 40

## Pozisyon senkron frekansı (saniyede gönderim).
const NET_TICK_RATE: int = 10

## Serbest chat şimdilik kapalı; altyapı hazır, açmak için true yapılır (+ filtre gerekli).
const FREE_CHAT_ENABLED: bool = false

## Aktif servis implementasyonları. Değiştirmek = bu satırı değiştirmek.
const NETWORK_BACKEND: String = "offline"  # "offline" | "nakama"
const AUTH_BACKEND: String = "mock"  # "mock" | "supabase"

## Oyuncu hareketi (metre/saniye, radyan/saniye).
const PLAYER_WALK_SPEED: float = 4.0
const PLAYER_ACCELERATION: float = 20.0
const PLAYER_TURN_SPEED: float = 10.0
## Yerden kopmadan inilebilecek basamak/eğim için yere yapışma mesafesi.
const PLAYER_FLOOR_SNAP: float = 0.3

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
