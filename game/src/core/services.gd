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

var net: NetworkService
var auth: AuthService
var characters: CharacterRegistry
var accessories: AccessoryRegistry


func _ready() -> void:
	net = _make_network(Config.NETWORK_BACKEND)
	auth = _make_auth(Config.AUTH_BACKEND)
	characters = CharacterRegistry.new()
	characters.load_from_dir("res://data/characters")
	accessories = AccessoryRegistry.new()
	accessories.load_from_dir("res://data/accessories")
	add_child(net)
	add_child(auth)


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
