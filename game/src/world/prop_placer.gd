extends Node3D
## Ortabahçe ve kampüs prop verisini (tools/osm/place_props.py) okuyup sahneye kurar.
## Ağaçlar, çalılar, banklar, lambalar ve çöp kutuları 100m x 100m hücrelere bölünerek MultiMeshInstance3D ile çizilir.
## Ağaç, lamba, bank ve çöp kutusu için tek bir StaticBody3D altında çarpışma şekilleri açılır.
## NavigationRegion3D'nin çocuğu olmalı: _ready'de kurulur, sonraki karede navmesh'e dahil olur.

@export_file("*.json") var data_path: String = ""

const CELL_SIZE: float = 100.0
const TREE_VISIBILITY_END: float = 220.0
const PROP_VISIBILITY_END: float = 120.0
const VISIBILITY_RANGE_MARGIN: float = 20.0

const LampMeshScript := preload("res://src/world/lamp_mesh.gd")

const PROP_PATHS: Dictionary = {
	"tree_birch": "res://assets/props/tree_birch.glb",
	"tree_pine": "res://assets/props/tree_pine.glb",
	"tree_common": "res://assets/props/tree_common.glb",
	"bush_common": "res://assets/props/bush_common.glb",
	"bush_berries": "res://assets/props/bush_berries.glb",
	"bench": "res://assets/props/bench.glb",
	"lamp": "res://assets/props/lamp.glb",
	"trashcan": "res://assets/props/trashcan.glb",
}

## glb gerçek boyutlarını dengelemek için tür başına ölçek çarpanı:
## Ağaçlar 4-7 m, bank ~1.6 m genişlik, lamba 3-4 m yüksekliğe ayarlanır.
const TYPE_SCALES: Dictionary = {
	"tree_birch": 1.4,
	"tree_pine": 1.4,
	"tree_common": 1.1,
	"bush_common": 1.0,
	"bush_berries": 1.0,
	"bench": 2.4,
	"lamp": 1.0,
	"trashcan": 1.0,
}

## Çarpışma şekli boyutları
const CYLINDER_RADIUS: float = 0.3
const CYLINDER_HEIGHT: float = 3.0
const BENCH_BOX_SIZE: Vector3 = Vector3(1.6, 0.8, 0.6)
const TRASHCAN_BOX_SIZE: Vector3 = Vector3(0.6, 1.0, 0.6)

var prop_count: int = 0

## true ise data_path yerine Services.current_zone'un prop verisi kullanılır ("" = bu bölgede prop yok).
@export var follow_current_zone: bool = true


static func get_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floorf(pos.x / CELL_SIZE)), int(floorf(pos.y / CELL_SIZE)))


func _ready() -> void:
	if follow_current_zone and Services.zones != null and Services.zones.has(Services.current_zone):
		data_path = str(Services.zones.get_zone(Services.current_zone)["props"])
	if data_path.is_empty():
		return
	var data: Dictionary = load_data(data_path)
	if data.is_empty():
		return
	build_props(data)


func build_props(data: Dictionary) -> void:
	var prop_list: Array = data.get("props", [])
	if prop_list.is_empty():
		return
	prop_count = prop_list.size()

	# Tek bir StaticBody3D (tüm prop çarpışmaları için)
	var static_body := StaticBody3D.new()
	static_body.name = "PropsStaticBody"
	add_child(static_body)

	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = CYLINDER_RADIUS
	cylinder_shape.height = CYLINDER_HEIGHT

	var bench_shape := BoxShape3D.new()
	bench_shape.size = BENCH_BOX_SIZE

	var trashcan_shape := BoxShape3D.new()
	trashcan_shape.size = TRASHCAN_BOX_SIZE

	# (hücre, tür) şeklinde grupla
	var by_cell: Dictionary = {}
	for item_var: Variant in prop_list:
		if not item_var is Dictionary:
			continue
		var item: Dictionary = item_var
		var t: String = str(item.get("type", ""))
		var pos_arr: Array = item.get("pos", [0.0, 0.0])
		var px: float = float(pos_arr[0])
		var pz: float = float(pos_arr[1])
		var cell: Vector2i = get_cell(Vector2(px, pz))

		if not by_cell.has(cell):
			by_cell[cell] = {}
		if not by_cell[cell].has(t):
			by_cell[cell][t] = []
		by_cell[cell][t].append(item)

		# Çarpışma şekillerini kur (çalılara yok)
		var yaw: float = float(item.get("yaw", 0.0))
		match t:
			"tree_birch", "tree_pine", "tree_common", "lamp":
				var col := CollisionShape3D.new()
				col.shape = cylinder_shape
				col.position = Vector3(px, CYLINDER_HEIGHT * 0.5, pz)
				static_body.add_child(col)
			"bench":
				var col := CollisionShape3D.new()
				col.shape = bench_shape
				col.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(px, BENCH_BOX_SIZE.y * 0.5, pz))
				static_body.add_child(col)
			"trashcan":
				var col := CollisionShape3D.new()
				col.shape = trashcan_shape
				col.position = Vector3(px, TRASHCAN_BOX_SIZE.y * 0.5, pz)
				static_body.add_child(col)
			"bush_common", "bush_berries":
				pass

	# GLB modellerinden mesh verilerini bir kez çıkarıp önbelleğe al
	# "lamp" tipi için kodla üretilen fener mesh'i (LampMesh) kullanılır
	var mesh_cache: Dictionary = {}
	for type: String in PROP_PATHS.keys():
		if type == "lamp":
			var lamp_entries: Array[Dictionary] = [{"mesh": LampMeshScript.create_mesh(), "transform": Transform3D.IDENTITY}]
			mesh_cache["lamp"] = lamp_entries
			continue
		var glb_path: String = PROP_PATHS[type]
		var scene: PackedScene = load(glb_path)
		if scene == null:
			push_error("Prop modeli yüklenemedi: %s" % glb_path)
			continue
		var temp_node: Node = scene.instantiate()
		var mesh_entries: Array[Dictionary] = _extract_mesh_data(temp_node, Transform3D.IDENTITY)
		temp_node.free()
		mesh_cache[type] = mesh_entries

	# Her (hücre, tür) için MultiMeshInstance3D kur
	for cell: Vector2i in by_cell.keys():
		var types_in_cell: Dictionary = by_cell[cell]
		for type: String in types_in_cell.keys():
			if not mesh_cache.has(type):
				continue
			var items: Array = types_in_cell[type]
			var count: int = items.size()
			if count == 0:
				continue

			var mesh_entries: Array[Dictionary] = mesh_cache[type]
			var is_tree: bool = type.begins_with("tree_")
			var vis_range: float = TREE_VISIBILITY_END if is_tree else PROP_VISIBILITY_END

			for mesh_idx: int in range(mesh_entries.size()):
				var entry: Dictionary = mesh_entries[mesh_idx]
				var mesh: Mesh = entry["mesh"]
				var local_t: Transform3D = entry["transform"]

				var mmi := MultiMeshInstance3D.new()
				mmi.name = "%s_%d_%d_MultiMesh_%d" % [type, cell.x, cell.y, mesh_idx]
				mmi.visibility_range_end = vis_range
				mmi.visibility_range_end_margin = VISIBILITY_RANGE_MARGIN
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh
				mm.instance_count = count

				for i: int in range(count):
					var item: Dictionary = items[i]
					var pos_arr: Array = item.get("pos", [0.0, 0.0])
					var px: float = float(pos_arr[0])
					var pz: float = float(pos_arr[1])
					var yaw: float = float(item.get("yaw", 0.0))
					var s: float = float(item.get("scale", 1.0))
					var final_scale: float = s * float(TYPE_SCALES.get(type, 1.0))

					var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * final_scale)
					var prop_t := Transform3D(basis, Vector3(px, 0.0, pz))
					var final_mesh_t: Transform3D = prop_t * local_t
					mm.set_instance_transform(i, final_mesh_t)

				mmi.multimesh = mm
				add_child(mmi)


static func _extract_mesh_data(node: Node, parent_t: Transform3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var t: Transform3D = parent_t
	if node is Node3D:
		t = parent_t * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			result.append({"mesh": mi.mesh, "transform": t})
	for child: Node in node.get_children():
		result.append_array(_extract_mesh_data(child, t))
	return result


static func load_data(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Prop verisi okunamadı: %s" % path)
		return {}
	return parsed
