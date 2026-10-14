extends Node3D
## Composition root. Geometry, input, presentation and case state remain separate.

const HOSPITAL := preload("res://scripts/world/hospital.gd")
const PLAYER := preload("res://scripts/player/player.gd")
const UI := preload("res://scripts/ui/game_ui.gd")
const ATMOSPHERE := preload("res://scripts/core/atmosphere.gd")
var hospital: Node3D
var player: Investigator
var ui: CanvasLayer
var atmosphere: Node3D
var _location_timer: float = 0.0
var _autosave_timer: float = 0.0
var _exiting: bool = false


func _ready() -> void:
	hospital = HOSPITAL.new()
	add_child(hospital)
	player = PLAYER.new()
	add_child(player)
	player.position = hospital.spawn_position
	player.rotation.y = hospital.spawn_yaw
	ui = UI.new()
	add_child(ui)
	ui.start_requested.connect(_start_session)
	ui.exit_requested.connect(_exit_game)
	ui.modal_changed.connect(_on_modal_changed)
	player.interact_requested.connect(ui.open_inspection)
	player.focus_changed.connect(ui.set_focus)
	player.flashlight_changed.connect(ui.set_flashlight)
	atmosphere = ATMOSPHERE.new()
	add_child(atmosphere)
	Settings.apply()
	ui.show_main_menu()
	player.set_enabled(false)
	get_tree().auto_accept_quit = false
	if "--play" in OS.get_cmdline_user_args():
		_start_session(false)
	if "--smoke" in OS.get_cmdline_user_args():
		_run_export_smoke.call_deferred()


func _start_session(resume: bool) -> void:
	if resume:
		if not GameState.load_progress():
			GameState.notification.emit("Không thể đọc hồ sơ lưu. Dữ liệu hiện tại được giữ nguyên.")
			return
	else:
		GameState.start_new()
	if not GameState.session_active:
		return
	player.global_position = GameState.player_position
	player.rotation.y = GameState.player_yaw
	player._pitch = 0.0
	player.get_camera().rotation = Vector3.ZERO
	ui.show_hud()
	ui.set_flashlight(player.flashlight_on)
	ui.set_location(hospital.get_location(player.global_position))
	player.set_enabled(true)
	_autosave_timer = 0.0


func _on_modal_changed(open: bool) -> void:
	player.set_enabled(GameState.session_active and not open)
	if open and GameState.session_active:
		GameState.save_progress()


func _process(delta: float) -> void:
	if not GameState.session_active:
		return
	_location_timer += delta
	_autosave_timer += delta
	if _location_timer >= 0.25:
		_location_timer = 0.0
		ui.set_location(hospital.get_location(player.global_position))
	if _autosave_timer >= 30.0:
		_autosave_timer = 0.0
		GameState.save_progress()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		if GameState.session_active and not ui.modal_open and not _exiting:
			ui.call_deferred("_open_pause")


func _exit_game() -> void:
	if _exiting:
		return
	_exiting = true
	player.set_enabled(false)
	if GameState.session_active:
		GameState.save_progress()
	GameState.session_active = false
	atmosphere.stop_audio()
	player.stop_audio()
	# Free the scene while the audio server is still running, then quit from a
	# SceneTree-owned timer. Waiting while players remain alive is insufficient on
	# some Dummy/audio-thread schedules.
	get_tree().create_timer(0.2).timeout.connect(get_tree().quit)
	queue_free()


func _run_export_smoke() -> void:
	_start_session(false)
	await get_tree().create_timer(1.0).timeout
	if not GameState.session_active or get_tree().get_nodes_in_group("evidence_objects").size() != 6:
		push_error("Export smoke: case data or evidence missing.")
		get_tree().quit(1)
		return
	ui.open_inspection("ward_clock")
	await get_tree().process_frame
	if not ui.modal_open or ui._inspection_id != "ward_clock":
		get_tree().quit(1)
		return
	print("SMOKE: bundled case, six physical clues and inspection UI loaded.")
	_exit_game()
