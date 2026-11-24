extends Node3D
## Kampüs kafelerinin kapı eşiği tetikleyicileri:
## Oyuncu bir kafenin kapısından içeri adım attığında (<= 5.6 m) o kafenin canlı sohbet salonuna bağlanır
## ve sohbet ekranı doğrudan o kafenin kanalında açılır; kapıdan uzaklaşınca (> 8.6 m) salondan ayrılır.

signal cafe_entered(cafe_id: String, cafe_name: String)
signal cafe_exited(cafe_id: String)

const ENTER_RADIUS: float = 5.6
const EXIT_RADIUS: float = 8.6
const WARMUP_SEC: float = 1.4

## Gerçek OSM/places.json kapı önü koordinatları (tüm binaların dışında doğrulandı).
const CAFES: Array[Dictionary] = [
	{"id": "hokka", "name": "Hokka Kafe", "door": Vector2(-69.0, -114.5)},
	{"id": "kayinti_kafe", "name": "Kayıntı Kafe", "door": Vector2(-87.4, -115.8)},
	{"id": "buyuk_ev", "name": "Büyük Ev Cafe", "door": Vector2(-36.2, -50.2)},
	{"id": "yemekhane", "name": "Yemekhane Salonu", "door": Vector2(-79.8, -74.5)},
	{"id": "yildiz_cafe", "name": "Yıldız Cafe", "door": Vector2(236.0, 3.8)},
	{"id": "eskafe", "name": "Eskafe", "door": Vector2(122.2, 353.7)},
	{"id": "academic_lounge", "name": "Academic Lounge", "door": Vector2(-51.1, 358.0)},
]

@export var player: Node3D
@export var chat_menu: Control

var active_cafe_id: String = ""
var active_cafe_name: String = ""
var _elapsed: float = 0.0


func _ready() -> void:
	if player == null and has_node("../Player"):
		player = get_node("../Player") as Node3D
	if chat_menu == null and has_node("../UI/ChatMenu"):
		chat_menu = get_node("../UI/ChatMenu") as Control
	_build_door_markers()


func _build_door_markers() -> void:
	# Tek birleşik ArrayMesh ile 7 kafe kapısı önüne zarif altın-turkuaz karşılama halkası (1 çizim çağrısı)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var col_outer: Color = Color(0.96, 0.72, 0.24).srgb_to_linear()
	var col_inner: Color = Color(0.14, 0.56, 0.64).srgb_to_linear()

	for c: Dictionary in CAFES:
		var d: Vector2 = c["door"]
		var by: float = TerrainHeight.active_height(d.x, d.y) + 0.145
		_add_ring(st, Vector3(d.x, by, d.y), 1.95, 2.35, 20, col_outer)
		_add_ring(st, Vector3(d.x, by + 0.005, d.y), 1.45, 1.78, 20, col_inner)

		var lbl: Label3D = Label3D.new()
		lbl.name = "CafeDoor_%s" % str(c["id"])
		lbl.text = "☕ %s\nSohbet Salonu" % str(c["name"])
		lbl.font_size = 26
		lbl.pixel_size = 0.0048
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(1.0, 0.94, 0.76)
		lbl.outline_size = 6
		lbl.outline_modulate = Color(0.08, 0.11, 0.16, 0.95)
		lbl.visibility_range_end = 52.0
		lbl.position = Vector3(d.x, by + 1.85, d.y)
		add_child(lbl)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CafeDoorRings"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _add_ring(st: SurfaceTool, center: Vector3, r_in: float, r_out: float, segs: int, col: Color) -> void:
	st.set_color(col)
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var i0: Vector3 = center + Vector3(cos(a0) * r_in, 0.0, sin(a0) * r_in)
		var i1: Vector3 = center + Vector3(cos(a1) * r_in, 0.0, sin(a1) * r_in)
		var o0: Vector3 = center + Vector3(cos(a0) * r_out, 0.0, sin(a0) * r_out)
		var o1: Vector3 = center + Vector3(cos(a1) * r_out, 0.0, sin(a1) * r_out)
		st.add_vertex(i0)
		st.add_vertex(o1)
		st.add_vertex(o0)
		st.add_vertex(i0)
		st.add_vertex(i1)
		st.add_vertex(o1)


static func cafe_name_for(cid: String) -> String:
	for c: Dictionary in CAFES:
		if str(c["id"]) == cid:
			return str(c["name"])
	return cid.capitalize()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < WARMUP_SEC or player == null:
		return
	var p_xz: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	check_position(p_xz)


func check_position(p_xz: Vector2) -> void:
	if not active_cafe_id.is_empty():
		var cur_door: Vector2 = _door_of(active_cafe_id)
		if p_xz.distance_to(cur_door) <= EXIT_RADIUS:
			return
		var prev_id: String = active_cafe_id
		active_cafe_id = ""
		active_cafe_name = ""
		if Services.net != null:
			Services.net.send_social({"act": "leave_cafe"})
		if chat_menu != null and chat_menu.has_method("on_cafe_exited"):
			chat_menu.call("on_cafe_exited", prev_id)
		cafe_exited.emit(prev_id)

	for c: Dictionary in CAFES:
		var d: Vector2 = c["door"]
		if p_xz.distance_to(d) <= ENTER_RADIUS:
			active_cafe_id = str(c["id"])
			active_cafe_name = str(c["name"])
			if Services.net != null:
				Services.net.send_social({"act": "enter_cafe", "cafe": active_cafe_id})
			if chat_menu != null and chat_menu.has_method("on_cafe_entered"):
				chat_menu.call("on_cafe_entered", active_cafe_id, active_cafe_name)
			cafe_entered.emit(active_cafe_id, active_cafe_name)
			return


static func _door_of(cid: String) -> Vector2:
	for c: Dictionary in CAFES:
		if str(c["id"]) == cid:
			return c["door"]
	return Vector2.INF
