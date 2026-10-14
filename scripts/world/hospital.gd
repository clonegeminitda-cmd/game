extends Node3D

## An original, procedural hospital wing: every asset is generated locally.
## Units are meters. Layers: 1 = solid architecture; 2 = inspectable evidence.
const EvidenceScript = preload("res://scripts/world/interactable.gd")
const FONT = preload("res://assets/fonts/NotoSans-Regular.ttf")
const FONT_BOLD = preload("res://assets/fonts/NotoSans-Bold.ttf")
var spawn_position: Vector3 = Vector3(0, 0.1, 8)
var spawn_yaw: float = 0.0
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _flicker_light: OmniLight3D
var _light_time: float = 0.0

func _ready() -> void:
	name = "HospitalWing"
	_rng.seed = 3072217
	_create_materials()
	_environment()
	_architecture()
	_corridor_details()
	_room_307()
	_control_room()
	_evidence()

func get_location(at: Vector3) -> String:
	if at.x > 3.0 and at.z > -10.2 and at.z < -1.8:
		return "PHÒNG 307 · HIỆN TRƯỜNG"
	if at.x < -3.0 and at.z > -1.2 and at.z < 7.2:
		return "PHÒNG GIÁM SÁT · CAMERA"
	if at.z > 7.0:
		return "TẦNG 3 · BÀN TRỰC"
	return "TẦNG 3 · HÀNH LANG KHU C"

func _process(delta: float) -> void:
	_light_time += delta
	# Slow, restrained variation, with no flashing/strobe effect.
	if is_instance_valid(_flicker_light):
		_flicker_light.light_energy = 1.0 + 0.045 * sin(_light_time * 1.71) + 0.025 * sin(_light_time * 2.3)

func _create_materials() -> void:
	_mat("wall", Color("9ca49e"), 0.95)
	_mat("green", Color("355b58"), 0.86)
	_mat("trim", Color("253e3e"), 0.7)
	_mat("ceiling", Color("717f7c"), 1.0)
	_mat("metal", Color("667c7a"), 0.47, 0.65)
	_mat("dark_metal", Color("182b2d"), 0.65, 0.45)
	_mat("wood", Color("594f41"), 0.83)
	_mat("door", Color("3c5250"), 0.87)
	_mat("ivory", Color("c9c8af"), 0.9)
	_mat("paper", Color("d2cab1"), 1.0)
	_mat("ink", Color("344447"), 0.95)
	_mat("amber", Color("b58a43"), 0.8)
	_mat("rust", Color("58483e"), 0.95)
	_mat("black", Color("0c181a"), 0.9)
	_mat("stain", Color("485855"), 1.0)
	_mat("fabric", Color("afb8ad"), 1.0)
	_mat("red", Color("793e37"), 0.92)
	_mat("light_white", Color("d7e8d8"), 0.7, 0.0, 1.6)
	_mat("light_amber", Color("f4ca7e"), 0.7, 0.0, 1.7)
	_mat("light_green", Color("65b59c"), 0.7, 0.0, 1.5)
	_mat("light_red", Color("9f493a"), 0.8, 0.0, 0.8)
	_mat("focus", Color("e7c37b"), 0.7, 0.0, 1.7)
	# A seamless, deterministic terrazzo tile pattern, with actual grout in the texture.
	var tile_image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var grout: bool = x % 128 < 2 or y % 128 < 2
			var alternate: bool = (int(x / 128) + int(y / 128)) % 2 == 0
			var tone: float = (0.43 if alternate else 0.39) + _rng.randf_range(-0.023, 0.023)
			if grout:
				tone = 0.25
			tile_image.set_pixel(x, y, Color(tone * 0.94, tone, tone * 0.96))
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_texture = ImageTexture.create_from_image(tile_image)
	floor_material.roughness = 0.63
	floor_material.metallic = 0.12
	_materials["floor"] = floor_material
	var wall_image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			var tone: float = _rng.randf_range(0.91, 1.0)
			wall_image.set_pixel(x, y, Color(tone, tone, tone))
	var wall_texture := ImageTexture.create_from_image(wall_image)
	for material_name in ["wall", "green", "ceiling"]:
		var material: StandardMaterial3D = _materials[material_name]
		material.albedo_texture = wall_texture
		material.uv1_triplanar = true
		material.uv1_scale = Vector3(0.7, 0.7, 0.7)

func _mat(key: String, color: Color, roughness: float, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_materials[key] = material
	return material

func _environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a141a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("829ba2")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.fog_enabled = true
	environment.fog_light_color = Color("1b2a2d")
	environment.fog_light_energy = 0.5
	environment.fog_density = 0.012
	world.environment = environment
	add_child(world)

func _architecture() -> void:
	_floor(Vector3(0, 0, -1), Vector2(6, 26))
	_floor(Vector3(7, 0, -6), Vector2(8, 8))
	_floor(Vector3(-6.5, 0, 3), Vector2(7, 8))
	_box(Vector3(0, 3.65, -1), Vector3(6.3, 0.18, 26.3), "ceiling", true)
	_box(Vector3(7, 3.65, -6), Vector3(8.2, 0.18, 8.2), "ceiling", true)
	_box(Vector3(-6.5, 3.65, 3), Vector3(7.2, 0.18, 8.2), "ceiling", true)
	# Open east doorway at z=-5, open west doorway at z=3.
	_wall_x(3.0, -14.0, -6.2)
	_wall_x(3.0, -3.8, 12.0)
	_wall_x(-3.0, -14.0, 1.8)
	_wall_x(-3.0, 4.2, 12.0)
	_box(Vector3(3, 3.18, -5), Vector3(0.28, 0.95, 2.4), "wall", true)
	_box(Vector3(-3, 3.18, 3), Vector3(0.28, 0.95, 2.4), "wall", true)
	_wall_z(-14.0, -3.0, 3.0)
	_wall_z(12.0, -3.0, 3.0)
	_wall_z(-10.0, 3.0, 11.0)
	_wall_z(-2.0, 3.0, 11.0)
	# The room 307 window is set into a properly colliding outside wall.
	_wall_x(11.0, -10.0, -8.4)
	_wall_x(11.0, -3.6, -2.0)
	_box(Vector3(11, 0.65, -6), Vector3(0.28, 1.3, 4.8), "green", true)
	_box(Vector3(11, 3.34, -6), Vector3(0.28, 0.62, 4.8), "wall", true)
	_box(Vector3(11, 2.16, -6), Vector3(0.08, 1.72, 4.8), "black", true)
	_rain_window()
	_wall_x(-10.0, -1.0, 7.0)
	_wall_z(-1.0, -10.0, -3.0)
	_wall_z(7.0, -10.0, -3.0)
	# Lightweight beams and suspended ceiling joins establish perspective.
	for z in [-11.5, -7.0, -2.5, 2.0, 6.5, 11.0]:
		_box(Vector3(0, 3.52, z), Vector3(5.85, 0.12, 0.10), "trim")
	for x in [-1.5, 1.5]:
		_box(Vector3(x, 3.54, -1), Vector3(0.035, 0.05, 26), "trim")

func _wall_x(x: float, start: float, end: float) -> void:
	var length: float = end - start
	var z: float = (start + end) * 0.5
	_box(Vector3(x, 1.8, z), Vector3(0.28, 3.6, length), "wall", true)
	_box(Vector3(x, 0.72, z), Vector3(0.3, 1.44, length), "green")
	_box(Vector3(x, 1.47, z), Vector3(0.34, 0.065, length), "ivory")
	_box(Vector3(x, 0.14, z), Vector3(0.34, 0.28, length), "trim")
	_box(Vector3(x, 0.92, z), Vector3(0.40, 0.09, length), "wood")

func _wall_z(z: float, start: float, end: float) -> void:
	var length: float = end - start
	var x: float = (start + end) * 0.5
	_box(Vector3(x, 1.8, z), Vector3(length, 3.6, 0.28), "wall", true)
	_box(Vector3(x, 0.72, z), Vector3(length, 1.44, 0.30), "green")
	_box(Vector3(x, 1.47, z), Vector3(length, 0.065, 0.34), "ivory")
	_box(Vector3(x, 0.14, z), Vector3(length, 0.28, 0.34), "trim")

func _floor(at: Vector3, size: Vector2) -> void:
	_box(at + Vector3(0, -0.14, 0), Vector3(size.x, 0.28, size.y), "trim", true)
	var plane := PlaneMesh.new()
	plane.size = size
	var material: StandardMaterial3D = _materials["floor"].duplicate()
	material.uv1_scale = Vector3(size.x / 2.4, size.y / 2.4, 1)
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = material
	instance.position = at + Vector3(0, 0.008, 0)
	add_child(instance)

func _corridor_details() -> void:
	for z in [-10.3, -4.7, 1.3, 7.6]:
		_ceiling_lamp(Vector3(0, 3.39, z), z == -4.7)
	# An amber bedside corridor light acts as a clear point of interest.
	_light(Vector3(2.2, 2.3, -4.7), Color("f0ba70"), 1.1, 5.3)
	_door_frame(Vector3(2.82, 0, -5), -PI / 2, "307", "PHÒNG BỆNH")
	_door_frame(Vector3(-2.82, 0, 3), PI / 2, "C / 03", "PHÒNG GIÁM SÁT")
	_closed_door(Vector3(2.81, 0, 2.0), -PI / 2, "308")
	_closed_door(Vector3(2.81, 0, 7.0), -PI / 2, "309")
	_closed_door(Vector3(-2.81, 0, -6.5), PI / 2, "306")
	_closed_door(Vector3(-2.81, 0, -10.7), PI / 2, "305")
	# Fire doors at the vanishing point, locked in this first playable wing.
	_box(Vector3(0, 1.42, -13.78), Vector3(2.5, 2.84, 0.12), "door")
	_box(Vector3(0, 1.43, -13.68), Vector3(0.045, 2.85, 0.035), "dark_metal")
	for x in [-0.64, 0.64]:
		_box(Vector3(x, 1.86, -13.69), Vector3(0.66, 0.58, 0.025), "black")
		_box(Vector3(x, 1.03, -13.61), Vector3(0.85, 0.07, 0.09), "metal")
	_label("LỐI THOÁT HIỂM", Vector3(0, 3.10, -13.62), 27, Color("a5dcc4"), 0, 0.011)
	_box(Vector3(0, 3.10, -13.70), Vector3(2.2, 0.42, 0.09), "trim")
	_light(Vector3(0, 2.85, -12.9), Color("70b2a2"), 0.7, 4.4)
	_box(Vector3(1.7, 2.63, -13.69), Vector3(0.16, 0.22, 0.10), "light_red")
	# Directional sign suspended above the central line of sight.
	_box(Vector3(0, 2.93, -1.7), Vector3(2.8, 0.53, 0.10), "trim")
	_label("KHU ĐIỀU TRỊ C   /   TẦNG 3", Vector3(0, 2.98, -1.63), 24, Color("d4dacc"), 0, 0.0068)
	_label("← GIÁM SÁT             PHÒNG 307 →", Vector3(0, 2.80, -1.63), 20, Color("b6bfaf"), 0, 0.0057)
	for x in [-1.08, 1.08]:
		_box(Vector3(x, 3.30, -1.7), Vector3(0.018, 0.45, 0.018), "metal")
	# Chairs, fire extinguisher and an abandoned trolley are all physical.
	_bench(Vector3(-2.17, 0, 8.7), PI / 2)
	_bench(Vector3(2.16, 0, -10.6), -PI / 2)
	_trolley(Vector3(-2.10, 0, -3.9))
	_box(Vector3(-2.80, 1.3, 5.85), Vector3(0.12, 0.58, 0.36), "red")
	_cylinder(Vector3(-2.62, 0.93, 5.85), 0.15, 0.48, "red")
	_label("PCCC", Vector3(-2.68, 1.73, 5.85), 22, Color("dfcfb8"), PI / 2, 0.007)
	# Scuffed, localized damp marks and a handful of loose paper sheets.
	for i in range(16):
		var z: float = _rng.randf_range(-12.8, 10.7)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		if (side > 0 and z > -6.4 and z < -3.5) or (side < 0 and z > 1.5 and z < 4.5):
			continue
		_box(Vector3(side * 2.842, _rng.randf_range(0.25, 0.55), z), Vector3(0.008, _rng.randf_range(0.12, 0.35), _rng.randf_range(0.12, 0.62)), "stain")
	for at in [Vector3(-1.75, 0.018, 5.4), Vector3(1.3, 0.019, -7.2), Vector3(-1.3, 0.021, -2.7)]:
		var sheet: MeshInstance3D = _box(at, Vector3(0.25, 0.006, 0.34), "paper")
		sheet.rotation.y = _rng.randf_range(-0.8, 0.8)
	# Reception at the player's back is the witness statement location.
	_box(Vector3(1.55, 0.52, 10), Vector3(2.15, 1.04, 1.12), "wood", true)
	_box(Vector3(1.55, 1.06, 10), Vector3(2.28, 0.09, 1.25), "ivory", true)
	_box(Vector3(2.04, 1.27, 10.34), Vector3(0.39, 0.32, 0.12), "dark_metal")
	_label("BÀN TRỰC", Vector3(1.55, 0.71, 9.425), 28, Color("d4c8ab"), PI, 0.009)
	_box(Vector3(0, 2.3, 11.82), Vector3(2.4, 0.88, 0.035), "trim")
	_label("BỆNH VIỆN AN TĨNH\nKHOA ĐIỀU TRỊ NỘI TRÚ", Vector3(0, 2.3, 11.79), 28, Color("c2cbbb"), PI, 0.009)
	_light(Vector3(0.9, 2.7, 9.3), Color("d6c18f"), 0.9, 5.0)

func _room_307() -> void:
	# The open door sits flat against the north side of the doorway.
	_box(Vector3(3.9, 1.36, -6.12), Vector3(1.52, 2.72, 0.12), "door", true)
	_box(Vector3(3.9, 1.94, -6.04), Vector3(0.55, 0.58, 0.035), "black")
	_box(Vector3(4.52, 1.03, -6.00), Vector3(0.22, 0.055, 0.09), "metal")
	_label("307", Vector3(3.9, 2.45, -6.025), 36, Color("c6cdbd"), 0, 0.008)
	_ceiling_lamp(Vector3(7.1, 3.38, -5.8), false)
	_light(Vector3(10.1, 2.4, -6), Color("79abc0"), 1.4, 6.0)
	# Bed, rails and an unidentifiable covered form: no gore or graphic content.
	_box(Vector3(7.15, 0.59, -7.4), Vector3(1.7, 0.24, 2.7), "metal", true)
	_box(Vector3(7.15, 0.84, -7.4), Vector3(1.58, 0.27, 2.48), "ivory", true)
	_box(Vector3(7.15, 1.19, -8.75), Vector3(1.72, 0.9, 0.12), "metal", true)
	_box(Vector3(7.15, 0.86, -6.02), Vector3(1.72, 0.64, 0.12), "metal", true)
	for x in [6.49, 7.81]:
		for z in [-8.45, -6.38]:
			_cylinder(Vector3(x, 0.32, z), 0.045, 0.48, "metal")
			var wheel: MeshInstance3D = _cylinder(Vector3(x, 0.13, z), 0.11, 0.065, "black")
			wheel.rotation.z = PI / 2
	for x in [6.25, 8.05]:
		_box(Vector3(x, 1.08, -7.45), Vector3(0.045, 0.05, 1.65), "metal")
		for z in [-8.2, -6.7]:
			_box(Vector3(x, 0.88, z), Vector3(0.04, 0.42, 0.04), "metal")
	_box(Vector3(7.15, 1.01, -8.23), Vector3(0.85, 0.15, 0.46), "fabric")
	_covered_form(Vector3(7.14, 0.98, -7.45))
	_box(Vector3(8.92, 0.49, -6.2), Vector3(1.1, 0.98, 0.87), "ivory", true)
	_box(Vector3(8.92, 1.0, -6.2), Vector3(1.2, 0.055, 0.94), "metal", true)
	for y in [0.34, 0.69]:
		_box(Vector3(8.92, y, -5.757), Vector3(0.85, 0.025, 0.018), "trim")
		_box(Vector3(8.92, y + 0.12, -5.72), Vector3(0.24, 0.025, 0.05), "metal")
	# An IV stand and an analog bedside monitor keep the scene clinical.
	_cylinder(Vector3(5.62, 1.19, -8.1), 0.024, 2.22, "metal")
	_box(Vector3(5.62, 2.31, -8.1), Vector3(0.48, 0.03, 0.03), "metal")
	_box(Vector3(5.80, 2.08, -8.1), Vector3(0.18, 0.29, 0.07), "ivory")
	for rotation_value in [0.0, PI / 3.0, -PI / 3.0]:
		var foot: MeshInstance3D = _box(Vector3(5.62, 0.09, -8.1), Vector3(0.66, 0.035, 0.035), "metal")
		foot.rotation.y = rotation_value
	_box(Vector3(4.35, 0.51, -8.63), Vector3(0.9, 1.02, 0.8), "ivory", true)
	_box(Vector3(4.35, 1.31, -8.63), Vector3(0.8, 0.54, 0.36), "dark_metal", true)
	_box(Vector3(4.35, 1.34, -8.435), Vector3(0.63, 0.34, 0.015), "black")
	_label("—  —  —", Vector3(4.35, 1.34, -8.42), 24, Color("5c9986"), 0, 0.006)
	_label("AN TĨNH\n307 / KHU C", Vector3(8.85, 2.58, -9.82), 26, Color("c4ccbc"), 0, 0.008)
	_box(Vector3(4.4, 1.05, -2.5), Vector3(1.5, 2.1, 0.62), "green", true)
	_box(Vector3(4.4, 1.07, -2.175), Vector3(0.025, 2.03, 0.025), "trim")
	for x in [4.25, 4.55]:
		_box(Vector3(x, 1.1, -2.14), Vector3(0.035, 0.22, 0.05), "metal")
	# A strip of barrier tape beside the opening leaves the passage unobstructed.
	var tape: MeshInstance3D = _box(Vector3(2.81, 1.98, -3.0), Vector3(0.025, 0.16, 1.37), "amber")
	tape.rotation.x = -0.13
	_label("NIÊM PHONG", Vector3(2.79, 1.98, -3.0), 22, Color("192b2d"), -PI / 2, 0.006)

func _covered_form(at: Vector3) -> void:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var across: int = 12
	var along: int = 18
	for z in range(along + 1):
		for x in range(across + 1):
			var px: float = (float(x) / across - 0.5) * 1.46
			var pz: float = (float(z) / along - 0.5) * 2.12
			var width: float = 0.39 + 0.1 * cos(pz * 2.0)
			var height: float = 0.21 * exp(-pow(px / width, 2.0)) * (0.65 + 0.35 * cos(pz * 2.0))
			height += 0.018 * sin(px * 19.0 + pz * 5.0)
			vertices.append(Vector3(px, height, pz))
			normals.append(Vector3.UP)
			uvs.append(Vector2(float(x) / across, float(z) / along))
	for z in range(along):
		for x in range(across):
			var i: int = z * (across + 1) + x
			indices.append_array(PackedInt32Array([i, i + 1, i + across + 1, i + 1, i + across + 2, i + across + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _materials["fabric"]
	instance.position = at
	add_child(instance)

func _control_room() -> void:
	_ceiling_lamp(Vector3(-6.9, 3.38, 3.5), true)
	_light(Vector3(-6.8, 1.8, 1.2), Color("5cbdad"), 0.65, 4.3)
	_box(Vector3(-6.9, 0.74, 0.8), Vector3(4.5, 0.12, 1.35), "wood", true)
	for x in [-8.9, -4.9]:
		_box(Vector3(x, 0.36, 0.8), Vector3(0.1, 0.72, 1.13), "dark_metal", true)
	for x in [-8.15, -6.85, -5.55]:
		_box(Vector3(x, 0.95, 0.62), Vector3(0.09, 0.36, 0.12), "dark_metal")
		_box(Vector3(x, 1.41, 0.52), Vector3(1.15, 0.79, 0.18), "dark_metal", true)
		_screen(Vector3(x, 1.42, 0.622), Vector2(1.02, 0.63), x > -6.0)
	_box(Vector3(-5.5, 0.85, 1.13), Vector3(0.85, 0.07, 0.27), "dark_metal")
	for i in range(9):
		_box(Vector3(-5.82 + i * 0.08, 0.893, 1.13), Vector3(0.043, 0.006, 0.16), "trim")
	_label("GIÁM SÁT   /   C-03", Vector3(-6.9, 2.64, -0.81), 28, Color("c6cfbd"), 0, 0.009)
	_box(Vector3(-9.25, 1.19, 5.63), Vector3(1.12, 2.38, 1.0), "dark_metal", true)
	for y in [0.4, 0.75, 1.1, 1.45, 1.8, 2.15]:
		_box(Vector3(-9.25, y, 5.10), Vector3(0.94, 0.23, 0.05), "trim")
		_box(Vector3(-8.91, y, 5.06), Vector3(0.025, 0.025, 0.018), "light_green")
	var chair := Node3D.new()
	add_child(chair)
	chair.position = Vector3(-6.9, 0, 2.65)
	chair.rotation.y = 0.18
	_box(Vector3(0, 0.54, 0), Vector3(0.65, 0.12, 0.65), "green", true, chair)
	_box(Vector3(0, 0.98, 0.27), Vector3(0.65, 0.75, 0.11), "green", true, chair)
	_box(Vector3(0, 0.27, 0), Vector3(0.08, 0.5, 0.08), "metal", false, chair)
	_box(Vector3(0, 0.07, 0), Vector3(0.75, 0.06, 0.08), "metal", false, chair)
	_box(Vector3(0, 0.07, 0), Vector3(0.08, 0.06, 0.75), "metal", false, chair)
	# An empty cork notice board and utility cabinet provide contextual detail.
	_box(Vector3(-9.82, 1.96, 1.7), Vector3(0.09, 1.25, 2.05), "wood")
	for z in [1.2, 1.9, 2.25]:
		_box(Vector3(-9.76, 1.99, z), Vector3(0.018, 0.50, 0.30), "paper")
	_label("CA TRỰC ĐÊM", Vector3(-9.75, 2.8, 1.7), 28, Color("c8cebf"), PI / 2, 0.009)

func _evidence() -> void:
	# Thread on the latch: local X/Y is always the inspectable front plane.
	var thread := _clue("door_thread", "Sợi cước tại chốt cửa", Vector3(2.76, 1.37, -3.98), Vector3(0.42, 0.54, 0.07), -PI / 2)
	_box(Vector3.ZERO, Vector3(0.32, 0.43, 0.065), "metal", false, thread)
	_box(Vector3(0, 0.03, 0.055), Vector3(0.22, 0.055, 0.065), "dark_metal", false, thread)
	var thread_mesh: MeshInstance3D = _box(Vector3(0.045, -0.05, 0.095), Vector3(0.012, 0.27, 0.009), "red", false, thread)
	thread_mesh.rotation.z = -0.19
	_marker(Vector3(2.70, 1.0, -3.7), "01", -PI / 2)
	var clock := _clue("ward_clock", "Đồng hồ hành lang", Vector3(2.76, 2.25, 5.0), Vector3(0.68, 0.68, 0.11), -PI / 2)
	var clock_rim: MeshInstance3D = _cylinder(Vector3.ZERO, 0.34, 0.10, "dark_metal", clock)
	clock_rim.rotation.x = PI / 2
	var clock_face: MeshInstance3D = _cylinder(Vector3(0, 0, 0.061), 0.301, 0.018, "ivory", clock)
	clock_face.rotation.x = PI / 2
	for i in range(12):
		var angle: float = i * TAU / 12.0
		var tick: MeshInstance3D = _box(Vector3(sin(angle) * 0.249, cos(angle) * 0.249, 0.074), Vector3(0.013, 0.041, 0.007), "ink", false, clock)
		tick.rotation.z = -angle
	_clock_hand(clock, -11.55 * TAU / 12.0, 0.135, 0.02) # 23:33, seven minutes slow
	_clock_hand(clock, -33.0 * TAU / 60.0, 0.207, 0.011)
	_label("AN TĨNH", Vector3(0, -0.12, 0.084), 18, Color("47524a"), 0, 0.0038, clock)
	_marker(Vector3(2.73, 1.81, 5.0), "02", -PI / 2)
	var cctv := _clue("cctv_log", "Nhật ký camera", Vector3(-7.65, 1.02, 1.24), Vector3(0.83, 0.64, 0.08))
	cctv.rotation.x = -0.65
	_paper_details(cctv, "CCTV / 307", "23:17 — 23:28", Vector2(0.73, 0.54))
	_marker(Vector3(-8.22, 0.90, 1.35), "03")
	var report := _clue("medical_report", "Báo cáo khám nghiệm", Vector3(8.9, 1.06, -6.2), Vector3(0.49, 0.66, 0.05))
	report.rotation.x = -PI / 2
	_paper_details(report, "HỒ SƠ 307", "THỜI ĐIỂM TỬ VONG", Vector2(0.45, 0.62))
	_marker(Vector3(9.33, 1.13, -5.98), "04")
	var maintenance := _clue("maintenance_note", "Phiếu bảo trì", Vector3(-2.77, 1.68, -1.40), Vector3(0.56, 0.79, 0.07), PI / 2)
	_paper_details(maintenance, "BẢO TRÌ", "THIẾT BỊ T-04", Vector2(0.50, 0.72))
	_marker(Vector3(-2.73, 1.17, -1.40), "05", PI / 2)
	var witness := _clue("witness_statement", "Biên bản nhân chứng", Vector3(1.55, 1.13, 9.77), Vector3(0.62, 0.74, 0.05))
	witness.rotation.x = -PI / 2
	witness.rotation.z = 0.08
	_paper_details(witness, "LỜI KHAI", "NHÂN CHỨNG / CA ĐÊM", Vector2(0.58, 0.69))
	_marker(Vector3(0.89, 1.21, 9.65), "06", PI)

func _clue(id: String, title: String, at: Vector3, size: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var evidence: StaticBody3D = EvidenceScript.new()
	evidence.name = "Evidence_" + id
	evidence.evidence_id = id
	evidence.display_name = title
	evidence.collision_layer = 2
	evidence.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	evidence.add_child(collision)
	var outline := Node3D.new()
	outline.name = "FocusOutline"
	outline.visible = false
	evidence.add_child(outline)
	var front: float = size.z * 0.5 + 0.045
	for x in [-size.x * 0.54, size.x * 0.54]:
		_box(Vector3(x, 0, front), Vector3(0.012, size.y * 1.08, 0.012), "focus", false, outline)
	for y in [-size.y * 0.54, size.y * 0.54]:
		_box(Vector3(0, y, front), Vector3(size.x * 1.08, 0.012, 0.012), "focus", false, outline)
	add_child(evidence)
	evidence.position = at
	evidence.rotation.y = yaw
	return evidence

func _paper_details(parent: Node3D, title: String, subtitle: String, size: Vector2) -> void:
	_box(Vector3.ZERO, Vector3(size.x + 0.04, size.y + 0.04, 0.035), "wood", false, parent)
	_box(Vector3(0, 0, 0.026), Vector3(size.x, size.y, 0.012), "paper", false, parent)
	_box(Vector3(0, size.y * 0.48, 0.045), Vector3(size.x * 0.40, 0.055, 0.018), "metal", false, parent)
	_label(title, Vector3(0, size.y * 0.29, 0.037), 28, Color("354749"), 0, 0.0038, parent)
	_label(subtitle, Vector3(0, size.y * 0.11, 0.037), 19, Color("65706a"), 0, 0.0025, parent)
	for i in range(5):
		var width: float = size.x * (0.75 - 0.1 * (i % 3))
		_box(Vector3(-size.x * 0.37 + width * 0.5, -size.y * 0.04 - i * size.y * 0.072, 0.038), Vector3(width, 0.007, 0.002), "ink", false, parent)
	_box(Vector3(size.x * 0.24, -size.y * 0.35, 0.039), Vector3(size.x * 0.20, 0.046, 0.003), "red", false, parent)

func _clock_hand(parent: Node3D, angle: float, length: float, width: float) -> void:
	var hand: MeshInstance3D = _box(Vector3(-sin(angle) * length * 0.5, cos(angle) * length * 0.5, 0.089), Vector3(width, length, 0.008), "ink", false, parent)
	hand.rotation.z = angle

func _marker(at: Vector3, number: String, yaw: float = 0.0) -> void:
	var marker := Node3D.new()
	add_child(marker)
	marker.position = at
	marker.rotation.y = yaw
	_box(Vector3.ZERO, Vector3(0.14, 0.17, 0.025), "amber", false, marker)
	_label(number, Vector3(0, 0, 0.02), 28, Color("142829"), 0, 0.004, marker)

func _door_frame(at: Vector3, yaw: float, number: String, title: String) -> void:
	var frame := Node3D.new()
	add_child(frame)
	frame.position = at
	frame.rotation.y = yaw
	for x in [-1.18, 1.18]:
		_box(Vector3(x, 1.37, 0), Vector3(0.10, 2.74, 0.14), "ivory", false, frame)
	_box(Vector3(0, 2.77, 0), Vector3(2.46, 0.12, 0.14), "ivory", false, frame)
	_box(Vector3(0, 3.13, 0.025), Vector3(1.56, 0.42, 0.06), "trim", false, frame)
	_label(number + "   /   " + title, Vector3(0, 3.13, 0.068), 25, Color("d3d4b8"), 0, 0.0055, frame)

func _closed_door(at: Vector3, yaw: float, number: String) -> void:
	var door := Node3D.new()
	add_child(door)
	door.position = at
	door.rotation.y = yaw
	_box(Vector3(0, 1.35, 0), Vector3(1.48, 2.7, 0.065), "door", false, door)
	for x in [-0.8, 0.8]:
		_box(Vector3(x, 1.39, 0.055), Vector3(0.08, 2.78, 0.09), "trim", false, door)
	_box(Vector3(0, 2.78, 0.055), Vector3(1.68, 0.1, 0.09), "trim", false, door)
	_box(Vector3(0, 1.95, 0.054), Vector3(0.54, 0.61, 0.025), "black", false, door)
	_box(Vector3(0, 1.95, 0.072), Vector3(0.49, 0.56, 0.01), "green", false, door)
	_box(Vector3(-0.52, 1.08, 0.10), Vector3(0.21, 0.045, 0.09), "metal", false, door)
	_label(number, Vector3(0, 2.47, 0.052), 35, Color("c1c8b6"), 0, 0.007, door)
	_label("KHÔNG PHẬN SỰ", Vector3(0, 1.47, 0.052), 20, Color("85968a"), 0, 0.0047, door)

func _ceiling_lamp(at: Vector3, amber: bool) -> void:
	_box(at, Vector3(1.52, 0.11, 0.42), "dark_metal")
	_box(at + Vector3(0, -0.065, 0), Vector3(1.35, 0.026, 0.30), "light_amber" if amber else "light_white")
	for x in [-0.53, 0.0, 0.53]:
		_box(at + Vector3(x, -0.085, 0), Vector3(0.022, 0.012, 0.31), "metal")
	var light: OmniLight3D = _light(at + Vector3(0, -0.36, 0), Color("e5c18c") if amber else Color("b2d5c9"), 1.05 if amber else 1.17, 6.4)
	if at.z < -4 and at.x == 0:
		_flicker_light = light

func _bench(at: Vector3, yaw: float) -> void:
	var bench := Node3D.new()
	add_child(bench)
	bench.position = at
	bench.rotation.y = yaw
	_box(Vector3(0, 0.49, 0), Vector3(1.8, 0.12, 0.59), "green", true, bench)
	_box(Vector3(0, 0.91, -0.23), Vector3(1.8, 0.72, 0.11), "green", true, bench)
	for x in [-0.65, 0.65]:
		_box(Vector3(x, 0.24, 0), Vector3(0.07, 0.48, 0.48), "metal", false, bench)
	for x in [-0.31, 0.31]:
		_box(Vector3(x, 0.79, 0.04), Vector3(0.045, 0.04, 0.49), "metal", false, bench)

func _trolley(at: Vector3) -> void:
	var trolley := Node3D.new()
	add_child(trolley)
	trolley.position = at
	trolley.rotation.y = 0.12
	for y in [0.29, 0.91]:
		_box(Vector3(0, y, 0), Vector3(0.75, 0.055, 0.53), "metal", true, trolley)
	for x in [-0.33, 0.33]:
		for z in [-0.22, 0.22]:
			_box(Vector3(x, 0.56, z), Vector3(0.035, 0.89, 0.035), "metal", false, trolley)
			_box(Vector3(x, 0.10, z), Vector3(0.09, 0.12, 0.06), "black", false, trolley)
	_box(Vector3(0.12, 1.03, 0.05), Vector3(0.32, 0.2, 0.25), "ivory", false, trolley)

func _screen(at: Vector3, size: Vector2, offline: bool) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
uniform bool offline = false;
void fragment() {
 vec2 p = UV;
 float lines = 0.90 + 0.10 * sin(p.y * 380.0);
 float flicker = 0.96 + 0.04 * sin(TIME * 2.7);
 vec3 c = vec3(0.035, 0.12, 0.11);
 if (!offline) {
  float corridor = step(abs(p.x - 0.5), 0.15 + 0.36 * p.y);
  c += corridor * vec3(0.025, 0.13, 0.115);
  float vanishing = abs(abs(p.x - 0.5) - (0.15 + 0.36 * p.y));
  c += (1.0 - smoothstep(0.0, 0.014, vanishing)) * vec3(0.15, 0.25, 0.19);
  c += step(0.92, p.y) * vec3(0.08, 0.12, 0.10);
 }
 ALBEDO = c * lines * flicker;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("offline", offline)
	var mesh := QuadMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	_label("CAM 307 · MẤT HÌNH" if offline else "CAM C-03 · 23:40:06", at + Vector3(0, -size.y * 0.35, 0.005), 19, Color("9ac4ad"), 0, 0.0035)

func _rain_window() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
void fragment() {
 vec2 p = UV;
 float horizon = smoothstep(0.4, 0.95, p.y);
 vec3 c = mix(vec3(0.055, 0.12, 0.16), vec3(0.014, 0.033, 0.044), horizon);
 float buildings = step(0.58 + 0.11 * sin(floor(p.x * 19.0) * 2.3), p.y);
 c *= 1.0 - buildings * 0.6;
 float lane = floor(p.x * 108.0);
 float speed = 0.15 + fract(sin(lane * 12.71) * 4311.1) * 0.18;
 float drop = pow(max(0.0, 1.0 - abs(fract(p.x * 108.0) - 0.5) * 9.0), 2.0);
 float tail = pow(fract(p.y * 3.0 - TIME * speed + lane * 0.37), 18.0);
 c += drop * tail * vec3(0.15, 0.24, 0.27);
 ALBEDO = c;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2(4.66, 1.7)
	var pane := MeshInstance3D.new()
	pane.mesh = quad
	pane.material_override = material
	pane.position = Vector3(10.93, 2.16, -6.0)
	pane.rotation.y = -PI / 2
	add_child(pane)
	for z in [-8.4, -6.8, -5.2, -3.6]:
		_box(Vector3(10.88, 2.18, z), Vector3(0.10, 1.84, 0.065), "trim")
	for y in [1.27, 2.18, 3.09]:
		_box(Vector3(10.88, y, -6), Vector3(0.10, 0.065, 4.87), "trim")
	_box(Vector3(10.76, 1.25, -6), Vector3(0.45, 0.10, 5.0), "ivory", true)

func _box(at: Vector3, size: Vector3, material_name: String, solid: bool = false, parent: Node3D = null) -> MeshInstance3D:
	var target: Node3D = parent if parent else self
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _materials[material_name]
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		body.position = at
		target.add_child(body)
	return instance

func _cylinder(at: Vector3, radius: float, height: float, material_name: String, parent: Node3D = null) -> MeshInstance3D:
	var target: Node3D = parent if parent else self
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _materials[material_name]
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(instance)
	return instance

func _label(value: String, at: Vector3, size: int, color: Color, yaw: float = 0.0, pixel_scale: float = 0.01, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font = FONT
	label.font_size = size
	label.pixel_size = pixel_scale
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = false
	label.position = at
	label.rotation.y = yaw
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var target: Node3D = parent if parent else self
	target.add_child(label)
	return label

func _light(at: Vector3, color: Color, energy: float, distance: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.omni_attenuation = 1.45
	light.shadow_enabled = false
	add_child(light)
	return light
