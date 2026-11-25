extends Node
## Ağ arayüzü (soyut). Oyun kodu sadece bunu bilir.
## Implementasyonlar: OfflineNetworkService (tek oyunculu), NakamaNetworkService (Config.NETWORK_BACKEND = "nakama").

signal connected
signal disconnected(reason: String)
signal room_joined(room_id: String)
signal player_joined(player_id: String, state: Dictionary)
signal player_left(player_id: String)
## state: {"pos": Vector3, "yaw": float, "anim": String}
signal player_state(player_id: String, state: Dictionary)
signal chat_received(message: ChatMessage)
## Başka oyuncunun profili: {"pet": StringName, "acc": {slot: id}, "name": String}
signal player_profile(player_id: String, profile: Dictionary)
## Yerel petin bakım durumu: state = {"food", "joy", "energy", "t"}; ok=false ise reason kullanıcıya gösterilir.
signal care_updated(state: Dictionary, ok: bool, reason: String)
## Sunucu: hesabın açık efsanevi petleri; fresh = bu girişte yeni açılanlar.
signal unlocks_received(pets: PackedStringArray, fresh: PackedStringArray)
## Yıldız tozu cüzdanı: {dust:int, owned:[ürün id], points:[bugün kalan nokta indeksleri], got:bool (az önce toplandı)}.
signal wallet_updated(wallet: Dictionary)
## Satın alma sonucu (reason boşsa başarılı).
signal purchase_finished(item: String, ok: bool, reason: String)
## Koşu yarışı durumu (RaceRules.view) ya da {"error": neden}.
signal race_updated(view: Dictionary)
## Sosyal durum (arkadaşlar, istek kutusu, kafe salonları, gruplar, bildirimler).
signal social_updated(data: Dictionary)

## Son bilinen cüzdan (ekranlar hemen okuyabilsin).
var wallet: Dictionary = {}
## Son bilinen sosyal durum: {friends:[], incoming:[], outgoing:[], cafes:{}, groups:[]}
var social_state: Dictionary = {"friends": [], "incoming": [], "outgoing": [], "cafes": {}, "groups": []}


func connect_to_server(_session_token: String) -> void:
	push_error("NetworkService.connect_to_server soyut")


func join_zone(_zone_id: String) -> void:
	push_error("NetworkService.join_zone soyut")


## Sunucu bağlantısını tamamen kapatır (çıkış / hesap değişimi). Varsayılan: odadan çık.
func disconnect_from_server() -> void:
	leave_zone()


func leave_zone() -> void:
	push_error("NetworkService.leave_zone soyut")


func send_state(_state: Dictionary) -> void:
	push_error("NetworkService.send_state soyut")


func send_chat(_message: ChatMessage) -> void:
	push_error("NetworkService.send_chat soyut")


## Yerel oyuncunun pet + aksesuar + kampüs kimliği bilgilerini odaya duyurur.
func send_profile(_pet_id: StringName, _accessories: Dictionary, _display_name: String = "", _extra: Dictionary = {}) -> void:
	pass


## Bakım eylemi iste: "eat" | "rest" | "play". Sonuç care_updated ile gelir.
func send_care_action(_action: String) -> void:
	pass


## Yıldız tozu topla (sunucu konuma göre doğrular) → wallet_updated.
func send_collect(_index: int) -> void:
	pass


## Cüzdanı iste (odada olmak gerekmez) → wallet_updated.
func request_wallet() -> void:
	pass


## Mini oyun bitti: sunucu skora göre yıldız tozu verir → wallet_updated (wallet.reward).
func send_minigame_result(_game: String, _score: int) -> void:
	pass


## Yarış: act = "join" | "leave" | "cp" (i = geçilen kontrol noktası).
func send_race(_act: String, _i: int = 0) -> void:
	pass


## Sosyal eylem gönder: enter_cafe, leave_cafe, create_group, join_group, leave_group, friend_req, friend_accept, friend_decline, friend_remove, sync.
func send_social(_payload: Dictionary) -> void:
	pass


func _apply_social_packet(d: Dictionary) -> void:
	if d.has("friends") and d["friends"] is Array:
		social_state["friends"] = d["friends"]
	if d.has("incoming") and d["incoming"] is Array:
		social_state["incoming"] = d["incoming"]
	if d.has("outgoing") and d["outgoing"] is Array:
		social_state["outgoing"] = d["outgoing"]
	if d.has("cafes") and d["cafes"] is Dictionary:
		social_state["cafes"] = d["cafes"]
	if d.has("groups") and d["groups"] is Array:
		social_state["groups"] = d["groups"]
	social_updated.emit(d)


## Dükkandan satın al → purchase_finished + wallet_updated.
func buy_item(item: String) -> void:
	purchase_finished.emit.call_deferred(item, false, "bağlantı yok")


func _set_wallet(w: Dictionary) -> void:
	wallet = w
	wallet_updated.emit(w)


func local_player_id() -> String:
	return ""


## Sunucudaki hesabı ve tüm verisini kalıcı siler (Play Store hesap silme şartı). "" = başarılı, aksi halde hata.
## session_token: Services.auth erişim anahtarı. Tek oyunculu modda sunucuda veri yok: hemen başarılı.
func delete_account(_session_token: String) -> String:
	await Engine.get_main_loop().process_frame
	return ""
