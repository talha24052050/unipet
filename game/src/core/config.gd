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
