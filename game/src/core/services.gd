extends Node
## Servis bulucu. Oyun kodu backend'leri asla doğrudan new'lemez;
## her zaman Services.net / Services.auth / Services.characters / Services.accessories üzerinden erişir.

const NetworkService := preload("res://src/net/network_service.gd")
const OfflineNetworkService := preload("res://src/net/offline_network_service.gd")
const NakamaNetworkService := preload("res://src/net/nakama_network_service.gd")
const AuthService := preload("res://src/auth/auth_service.gd")
const MockAuthService := preload("res://src/auth/mock_auth_service.gd")
const SupabaseAuthService := preload("res://src/auth/supabase_auth_service.gd")
const CharacterRegistry := preload("res://src/characters/character_registry.gd")
const AccessoryRegistry := preload("res://src/characters/accessory_registry.gd")
const ZoneCatalog := preload("res://src/world/zone_catalog.gd")
const ProfileSync := preload("res://src/net/profile_sync.gd")
const Feedback := preload("res://src/net/feedback.gd")

var net: NetworkService
var auth: AuthService
var characters: CharacterRegistry
var accessories: AccessoryRegistry
var zones: ZoneCatalog
## Profilin Supabase'e senkronu (sadece supabase girişinde etkin).
var profile_sync: ProfileSync
## Oyuncu geri bildirimi (Supabase `feedback`; geliştirmede cihaza).
var feedback: Feedback
## Oyuncunun bulunduğu bölge (ana sahne bunu yükler; harita ekranı değiştirir).
var current_zone: String = ""
## Haritadan ışınlanma hedefi (kampüs XZ). Oyuncu sahnesi bir kez kullanır ve sıfırlar.
var pending_teleport: Vector2 = Vector2.INF


func _ready() -> void:
	net = _make_network(Config.NETWORK_BACKEND)
	auth = _make_auth(Config.AUTH_BACKEND)
	characters = CharacterRegistry.new()
	characters.load_from_dir("res://data/characters")
	accessories = AccessoryRegistry.new()
	accessories.load_from_dir("res://data/accessories")
	zones = ZoneCatalog.load_default()
	current_zone = zones.default_id
	add_child(net)
	add_child(auth)
	profile_sync = ProfileSync.new()
	add_child(profile_sync)
	feedback = Feedback.new()
	add_child(feedback)


## Sunucu adresine göre ağ servisini seçer: {} → tek oyunculu (offline), {"host","port","ssl"} → Nakama.
## Giriş ekranı, oyun sahnesine geçmeden önce çağırır (sahneler eski servise bağlı kalmasın).
func use_server(address: Dictionary) -> void:
	var want_nakama: bool = not address.is_empty()
	var is_nakama: bool = net is NakamaNetworkService
	if want_nakama == is_nakama and not want_nakama:
		return
	if net != null:
		net.leave_zone()
		remove_child(net)
		net.queue_free()
	net = NakamaNetworkService.new() if want_nakama else OfflineNetworkService.new()
	add_child(net)
	if want_nakama:
		var n: NakamaNetworkService = net
		n.host = str(address["host"])
		n.port = int(address["port"])
		n.ssl = bool(address["ssl"])


func _make_network(kind: String) -> NetworkService:
	match kind:
		"offline":
			return OfflineNetworkService.new()
		"nakama":
			return NakamaNetworkService.new()
		_:
			push_error("Bilinmeyen network backend: %s, offline kullanılıyor" % kind)
			return OfflineNetworkService.new()


func _make_auth(kind: String) -> AuthService:
	match kind:
		"mock":
			return MockAuthService.new()
		"supabase":
			return SupabaseAuthService.new()
		_:
			push_error("Bilinmeyen auth backend: %s, mock kullanılıyor" % kind)
			return MockAuthService.new()
