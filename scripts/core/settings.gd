extends Node
## Local presentation settings. Never serialized into shared investigation state.

signal changed

const CONFIG_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Rất thấp", "Thấp", "Trung bình", "Cao"]
const FPS_CAPS := [30, 45, 60, 90]
const RESOLUTIONS := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var quality: int = 1
var fps_limit: int = 60
var sensitivity: float = 0.0023
var master_volume: float = 0.65
var fullscreen: bool = false
var resolution: Vector2i = Vector2i(1280, 720)


func _ready() -> void:
	_install_inputs()
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		quality = clampi(int(config.get_value("video", "quality", 1)), 0, 3)
		var cap := int(config.get_value("video", "fps_limit", 60))
		fps_limit = cap if cap in FPS_CAPS else 60
		sensitivity = clampf(float(config.get_value("controls", "sensitivity", 0.0023)), 0.0007, 0.006)
		master_volume = clampf(float(config.get_value("audio", "volume", 0.65)), 0.0, 1.0)
		fullscreen = bool(config.get_value("video", "fullscreen", false))
		var saved_resolution: Variant = config.get_value("video", "resolution", Vector2i(1280, 720))
		if saved_resolution is Vector2i and saved_resolution in RESOLUTIONS:
			resolution = saved_resolution
	apply()


func _install_inputs() -> void:
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
		"move_right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_CTRL,
		"interact": KEY_E, "flashlight": KEY_F, "journal": KEY_TAB,
		"map": KEY_M, "pause": KEY_ESCAPE, "performance": KEY_F3
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = keys[action]
			InputMap.action_add_event(action, key)


func apply() -> void:
	quality = clampi(quality, 0, 3)
	sensitivity = clampf(sensitivity, 0.0007, 0.006)
	master_volume = clampf(master_volume, 0.0, 1.0)
	Engine.max_fps = fps_limit
	var viewport := get_viewport()
	viewport.scaling_3d_scale = [0.60, 0.75, 0.85, 1.0][quality]
	# FXAA is unsupported by Godot's Compatibility renderer. Use MSAA instead.
	viewport.msaa_3d = Viewport.MSAA_4X if quality == 3 else (Viewport.MSAA_2X if quality == 2 else Viewport.MSAA_DISABLED)
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.mesh_lod_threshold = [4.0, 3.0, 2.0, 1.0][quality]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume == 0.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			DisplayServer.window_set_size(resolution)
	changed.emit()


func set_quality(value: int) -> void:
	quality = clampi(value, 0, 3)
	apply()
	save_settings()


func set_fps_limit(value: int) -> void:
	if value in FPS_CAPS:
		fps_limit = value
		apply()
		save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save_settings()


func set_resolution(value: Vector2i) -> void:
	if value in RESOLUTIONS:
		resolution = value
		apply()
		save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "quality", quality)
	config.set_value("video", "fps_limit", fps_limit)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "resolution", resolution)
	config.set_value("controls", "sensitivity", sensitivity)
	config.set_value("audio", "volume", master_volume)
	if config.save(CONFIG_PATH) != OK:
		push_warning("Không thể lưu cài đặt vào thư mục dữ liệu người dùng.")
