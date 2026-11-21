extends Node3D
## Bir CharacterDef'in modelini yükler ve MANTIKSAL animasyonları oynatır.
## Oyun kodu model dosyasını ya da gerçek animasyon adlarını bilmez; sadece:
##   set_character(def), set_locomotion(hız), play_emote(&"emote_wave"), equip(aksesuar)

signal emote_finished(logical: StringName)

## Boşta kalan pet ara sıra kendiliğinden hareket etsin (canlı görünsün).
const FIDGET_EMOTES: Array[StringName] = [&"emote_yes", &"emote_dance", &"emote_jump"]
const FIDGET_MIN_S: float = 12.0
const FIDGET_MAX_S: float = 25.0

const LOOPING: PackedStringArray = ["idle", "walk", "run"]
## Aksesuar sahneleri bu genişlikteki (metre) bir pete göre modellenir.
const ACCESSORY_REF_WIDTH: float = 0.9
## scarf.tscn halkasının iç yarıçapı (ref ölçekte).
const SCARF_REF_RADIUS: float = 0.42
## face/neck/back yüzeyinin varsayılan aranma yüksekliği (boyun oranı).
const DEFAULT_SLOT_HEIGHT: Dictionary = {&"face": 0.55, &"neck": 0.18, &"back": 0.45}

var definition: CharacterDef
var _model: Node3D
var _player: AnimationPlayer
var _current: StringName = &""
var _emote: StringName = &""
## slot -> {"def": AccessoryDef, "node": Node3D}
var _equipped: Dictionary = {}
var _verts_cache: PackedVector3Array = []
## false: kendiliğinden hareket yok (ör. uzak oyuncular — onların hareketi ağdan gelir).
var fidget_enabled: bool = true
var _idle_time: float = 0.0
var _next_fidget: float = 0.0


func set_character(def: CharacterDef) -> void:
	var keep: Array[AccessoryDef] = []
	for slot: StringName in _equipped:
		keep.append(_equipped[slot]["def"])
	_equipped.clear()
	_verts_cache = PackedVector3Array()
	if _model != null:
		_model.queue_free()
		_model = null
		_player = null
	definition = def
	_current = &""
	_emote = &""
	if def == null:
		return
	var scene: PackedScene = load(def.model_path)
	_model = scene.instantiate()
	_model.scale = Vector3.ONE * def.model_scale
	add_child(_model)
	var players: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0]
		_player.animation_finished.connect(_on_animation_finished)
		for logical: String in LOOPING:
			var anim: Animation = _player.get_animation(def.anim_name(logical)) if _player.has_animation(def.anim_name(logical)) else null
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
	_play(&"idle")
	# Pet değişse de takılı aksesuarlar kalsın.
	for acc: AccessoryDef in keep:
		equip(acc)


## Aksesuarı slotuna takar (aynı slottaki eskisi çıkar). Pet o slotu desteklemiyorsa false.
func equip(acc: AccessoryDef) -> bool:
	if definition == null or acc == null or _model == null:
		return false
	var bone_name: String = str(definition.accessory_bones.get(acc.slot, ""))
	var skeleton: Skeleton3D = _skeleton()
	if bone_name.is_empty() or skeleton == null:
		return false
	var bone: int = skeleton.find_bone(bone_name)
	if bone == -1:
		return false
	unequip(acc.slot)
	var attach: BoneAttachment3D = BoneAttachment3D.new()
	attach.name = "Accessory_%s" % acc.slot
	attach.bone_name = bone_name
	skeleton.add_child(attach)
	var item: Node3D = (load(acc.scene_path) as PackedScene).instantiate()
	attach.add_child(item)
	var bone_in_model: Transform3D = _xform_to_model(skeleton) * skeleton.get_bone_global_rest(bone)
	item.transform = bone_in_model.affine_inverse() * accessory_anchor(acc.slot)
	_equipped[acc.slot] = {"def": acc, "node": attach}
	return true


func unequip(slot: StringName) -> void:
	if not _equipped.has(slot):
		return
	var node: Node = _equipped[slot]["node"]
	node.queue_free()
	_equipped.erase(slot)


## slot -> aksesuar id
func equipped_ids() -> Dictionary:
	var out: Dictionary = {}
	for slot: StringName in _equipped:
		out[slot] = (_equipped[slot]["def"] as AccessoryDef).id
	return out


## Slotun model uzayındaki (ölçeksiz) yerleşimi: konum + aksesuarın petin boyuna göre ölçeği.
## Konum modelin YÜZEYİNDEN bulunur (kafanın orta sütununun tepesi, yüzün önü...);
## kutu (AABB) kullanılmaz çünkü kulak/diken/kılıç kutuyu büyütür.
## Pet başına ince ayar CharacterDef.accessory_offsets'ta:
##   {"slot": {"pos": Vector3 (metre), "rot": Vector3 (derece), "scale": float, "height": 0..1}}
## "height": face/neck/back için yüzeyin aranacağı yükseklik (boyun oranı).
func accessory_anchor(slot: StringName) -> Transform3D:
	var box: AABB = _model_aabb()
	var verts: PackedVector3Array = _model_vertices()
	var c: Vector3 = box.get_center()
	var h: float = box.size.y
	var w: float = minf(box.size.x, box.size.z)
	var tweak: Dictionary = definition.accessory_offsets.get(slot, {})
	var band_center: float = float(tweak.get("height", DEFAULT_SLOT_HEIGHT.get(slot, 0.5)))
	var y_band: float = box.position.y + h * band_center
	var p: Vector3 = c
	var size: float = w * definition.model_scale / ACCESSORY_REF_WIDTH
	match slot:
		&"head":
			var top: float = _extreme(verts, c, w * 0.15, -INF, INF, Vector3.UP, box.end.y)
			p = Vector3(c.x, top - h * 0.02, c.z)
		&"face":
			var front: float = _extreme(verts, c, w * 0.2, y_band - h * 0.08, y_band + h * 0.08, Vector3.BACK, box.end.z)
			# Burun/gaga en öndedir; gözlük biraz geride, gözlerin önünde dursun.
			p = Vector3(c.x, y_band, front - box.size.z * 0.06)
		&"back":
			var back: float = -_extreme(verts, c, w * 0.2, y_band - h * 0.1, y_band + h * 0.1, Vector3.FORWARD, -box.position.z)
			p = Vector3(c.x, y_band, back + box.size.z * 0.03)
		&"neck":
			p = Vector3(c.x, y_band, c.z)
			# Atkı halkası gövdenin o yükseklikteki yarıçapına otursun.
			var r: float = _radius_at(verts, c, y_band - h * 0.05, y_band + h * 0.05)
			if r > 0.0:
				size = r * definition.model_scale / SCARF_REF_RADIUS
	var ms: float = definition.model_scale
	var basis: Basis = Basis()
	if tweak.has("pos"):
		p += (tweak["pos"] as Vector3) / ms
	if tweak.has("rot"):
		var rot: Vector3 = tweak["rot"]
		basis = Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	size *= float(tweak.get("scale", 1.0))
	return Transform3D(basis.scaled(Vector3.ONE * (size / ms)), p)


## Merkez sütundaki (yatayda `radius` içinde, `y_min..y_max` arasında) köşelerin `dir` yönündeki
## en uç değeri. Hiç köşe yoksa `fallback`.
static func _extreme(verts: PackedVector3Array, c: Vector3, radius: float, y_min: float, y_max: float, dir: Vector3, fallback: float) -> float:
	var best: float = -INF
	for v: Vector3 in verts:
		if v.y < y_min or v.y > y_max:
			continue
		var off: float = absf(v.x - c.x) if dir.z != 0.0 else Vector2(v.x - c.x, v.z - c.z).length()
		if off > radius:
			continue
		best = maxf(best, v.dot(dir))
	return best if best > -INF else fallback


## `y_min..y_max` bandındaki köşelerin merkeze yatay uzaklığının medyanı (gövde yarıçapı).
static func _radius_at(verts: PackedVector3Array, c: Vector3, y_min: float, y_max: float) -> float:
	var ds: PackedFloat32Array = []
	for v: Vector3 in verts:
		if v.y >= y_min and v.y <= y_max:
			ds.append(Vector2(v.x - c.x, v.z - c.z).length())
	if ds.is_empty():
		return 0.0
	ds.sort()
	return ds[int(ds.size() * 0.8)]


## Modelin bağ pozundaki tüm köşeleri (model uzayında, ölçeksiz). Pet başına önbelleklenir.
func _model_vertices() -> PackedVector3Array:
	if not _verts_cache.is_empty():
		return _verts_cache
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if _is_accessory(mi):
			continue
		var xf: Transform3D = _xform_to_model(mi)
		for sidx: int in mi.mesh.get_surface_count():
			var arr: PackedVector3Array = mi.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in arr:
				_verts_cache.append(xf * v)
	return _verts_cache


func _process(delta: float) -> void:
	tick_fidget(delta)


## Boşta geçen süreyi sayar; süre dolunca petin desteklediği rastgele bir emote oynatır. Oynatılan ya da &"".
func tick_fidget(delta: float) -> StringName:
	if not fidget_enabled or definition == null or current_logical() != &"idle":
		_idle_time = 0.0
		return &""
	if _next_fidget <= 0.0:
		_next_fidget = randf_range(FIDGET_MIN_S, FIDGET_MAX_S)
	_idle_time += delta
	if _idle_time < _next_fidget:
		return &""
	_idle_time = 0.0
	_next_fidget = randf_range(FIDGET_MIN_S, FIDGET_MAX_S)
	var options: Array[StringName] = []
	for e: StringName in FIDGET_EMOTES:
		if not definition.anim_name(e).is_empty():
			options.append(e)
	if options.is_empty():
		return &""
	var pick: StringName = options[randi() % options.size()]
	play_emote(pick)
	return pick


## Yatay hıza göre idle / walk / run seçer. Hareket emote'u keser.
func set_locomotion(speed: float) -> void:
	if definition == null:
		return
	var moving: bool = speed > Config.PET_IDLE_SPEED
	if _emote != &"" and not moving:
		return
	_emote = &""
	var logical: StringName = locomotion_for(speed)
	_play(logical)
	if _player != null and logical != &"idle":
		# Ayak kaymasın diye oynatma hızı gerçek hıza oranlanır.
		var ref: float = Config.PLAYER_RUN_SPEED if logical == &"run" else Config.PLAYER_WALK_SPEED
		_player.speed_scale = definition.anim_speed(logical) * clampf(speed / ref, 0.5, 1.5)
	elif _player != null:
		_player.speed_scale = 1.0


## Tek seferlik emote (dans, zıplama...). Bitince ya da hareket edilince loco'ya döner.
func play_emote(logical: StringName) -> bool:
	if definition == null or definition.anim_name(logical).is_empty():
		return false
	_emote = logical
	_play(logical, true)
	return true


func current_logical() -> StringName:
	return _emote if _emote != &"" else _current


## Model boyutundan yaklaşık çarpışma yarıçapı ve boyu (metre, ölçek uygulanmış).
func footprint() -> Vector2:
	if _model == null:
		return Vector2(0.35, 1.2)
	var box: AABB = _model_aabb()
	var ms: float = definition.model_scale
	var radius: float = minf(box.size.x, box.size.z) * ms * 0.5 * Config.PET_COLLISION_RADIUS_FACTOR
	return Vector2(radius, box.size.y * ms)


## Modelin kendi (ölçeksiz) uzayında bağ pozundaki kutusu.
func _model_aabb() -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.get_parent() is BoneAttachment3D or _is_accessory(mi):
			continue
		var b: AABB = _xform_to_model(mi) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _is_accessory(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != _model:
		if p is BoneAttachment3D:
			return true
		p = p.get_parent()
	return false


func _skeleton() -> Skeleton3D:
	var found: Array[Node] = _model.find_children("*", "Skeleton3D", true, false)
	return found[0] if not found.is_empty() else null


static func locomotion_for(speed: float) -> StringName:
	if speed <= Config.PET_IDLE_SPEED:
		return &"idle"
	if speed >= Config.PLAYER_RUN_SPEED * 0.9:
		return &"run"
	return &"walk"


func _play(logical: StringName, restart: bool = false) -> void:
	if _player == null:
		return
	if logical == _current and not restart and _emote == &"":
		return
	var real: String = definition.anim_name(logical)
	if real.is_empty() or not _player.has_animation(real):
		return
	if logical != &"run" and logical != &"walk":
		_player.speed_scale = definition.anim_speed(logical)
	_player.play(real, Config.PET_ANIM_BLEND)
	if restart:
		_player.seek(0.0, true)
	if _emote == &"":
		_current = logical


func _on_animation_finished(_name: StringName) -> void:
	if _emote == &"":
		return
	var done: StringName = _emote
	_emote = &""
	_current = &""
	_play(&"idle")
	emote_finished.emit(done)


## Düğümün model köküne göre dönüşümü (model kökünün ölçeği hariç; ağaçta olmasa da çalışır).
func _xform_to_model(n: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D() if n == _model else n.transform
	var p: Node = n.get_parent()
	while p != null and p != _model and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
