extends Node
## Profil (takma ad, pet, aksesuarlar) ↔ Supabase `profiles` tablosu (ROADMAP 3.4; şema: server/supabase/001_schema.sql).
## Sadece Config.AUTH_BACKEND == "supabase" ve oturum açıkken çalışır; değilse hiçbir şey yapmaz (yerel kayıt yeter).
## RLS: herkes okuyabilir, sadece kendi satırını yazabilir.

const LocalProfile := preload("res://src/core/local_profile.gd")
const SECRETS_PATH: String = "res://secrets.cfg"

signal pulled(profile: RefCounted)
signal push_failed(reason: String)

var _url: String = ""
var _anon_key: String = ""


func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SECRETS_PATH) == OK:
		_url = str(cfg.get_value("supabase", "url", "")).trim_suffix("/")
		_anon_key = str(cfg.get_value("supabase", "anon_key", ""))


func is_active() -> bool:
	return Config.AUTH_BACKEND == "supabase" and not _url.is_empty() and Services.auth.is_signed_in()


## Yerel profili sunucuya yazar (upsert). Sunucu adı/pet'i kendi kurallarıyla da doğrular.
func push(profile: RefCounted) -> void:
	if not is_active():
		return
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/rest/v1/profiles?on_conflict=id",
		["Prefer: resolution=merge-duplicates,return=minimal"], [to_row(profile, Services.auth.get_user_id())])
	if not res["ok"]:
		push_failed.emit("Profil kaydedilemedi (%d)." % res["code"])


## Sunucudaki profili yerel kayda uygular (yeni telefonda seçimler geri gelsin).
func pull() -> void:
	if not is_active():
		return
	var id: String = Services.auth.get_user_id()
	var res: Dictionary = await _request(HTTPClient.METHOD_GET, "/rest/v1/profiles?id=eq.%s&select=*" % id.uri_encode(), [], null)
	if not res["ok"] or not (res["body"] is Array) or (res["body"] as Array).is_empty():
		return
	var p: RefCounted = from_row((res["body"] as Array)[0], LocalProfile.load_or_default())
	p.save()
	pulled.emit(p)


## LocalProfile → tablo satırı.
static func to_row(profile: RefCounted, user_id: String) -> Dictionary:
	var acc: Dictionary = {}
	for slot: StringName in profile.accessories:
		acc[str(slot)] = str(profile.accessories[slot])
	var row: Dictionary = {"id": user_id, "pet_id": str(profile.pet_id), "accessories": acc}
	var name: String = LocalProfile.clean_name(profile.display_name)
	if name.length() >= 3:
		row["username"] = name.replace(" ", "_")
	return row


## Tablo satırı → LocalProfile (base'in üstüne yazar; eksik alanlar korunur).
static func from_row(row: Dictionary, base: RefCounted) -> RefCounted:
	if not str(row.get("pet_id", "")).is_empty():
		base.pet_id = StringName(str(row["pet_id"]))
	var acc: Variant = row.get("accessories", {})
	if acc is Dictionary:
		base.accessories = {}
		for slot: String in acc:
			base.accessories[StringName(slot)] = StringName(str(acc[slot]))
	if row.get("username") != null and not str(row["username"]).is_empty():
		base.display_name = LocalProfile.clean_name(str(row["username"]).replace("_", " "))
	return base


func _request(method: int, path: String, extra_headers: PackedStringArray, body: Variant) -> Dictionary:
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var headers: PackedStringArray = ["apikey: " + _anon_key, "Authorization: Bearer " + Services.auth.get_access_token(),
		"Content-Type: application/json"]
	headers.append_array(extra_headers)
	var err: Error = req.request(_url + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": null}
	var result: Array = await req.request_completed
	req.queue_free()
	var code: int = result[1] if result[0] == HTTPRequest.RESULT_SUCCESS else 0
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": code >= 200 and code < 300, "code": code, "body": JSON.parse_string(text) if not text.is_empty() else null}
