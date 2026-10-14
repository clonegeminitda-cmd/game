extends SceneTree
## Render actual game/UI through Xvfb. Captures are diagnostics, not GPU benchmarks.
var scene: Node3D
var output: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	output = OS.get_environment("DARK_EVIDENCE_CAPTURE_DIR")
	if output.is_empty():
		output = "/tmp/dark-evidence-captures"
	DirAccess.make_dir_recursive_absolute(output)
	var packed: PackedScene = load("res://scenes/main.tscn")
	scene = packed.instantiate()
	root.add_child(scene)
	root.get_node("Settings").set_resolution(Vector2i(1280, 720))
	root.get_node("Settings").set_quality(1)
	await _capture("01-menu")
	scene._start_session(false)
	scene.player.set_enabled(false)
	await _capture("02-corridor")
	scene.player.position = Vector3(4.8, 0.05, -4.1)
	scene.player.get_camera().look_at(Vector3(7.2, 1.25, -7.1))
	scene.ui.set_location("PHÒNG 307 · HIỆN TRƯỜNG")
	await _capture("03-room-307")
	scene.player.position = Vector3(-4.8, 0.05, 4.3)
	scene.player.get_camera().look_at(Vector3(-7, 1.2, 0.6))
	scene.ui.set_location("PHÒNG GIÁM SÁT · CAMERA")
	await _capture("04-camera-room")
	scene.ui.open_inspection("ward_clock")
	await _capture("05-inspection")
	var state: Node = root.get_node("GameState")
	for entry: Dictionary in state.case_data.evidence:
		state.collect_evidence(entry.id, entry.correct_observation)
	scene.ui._open_journal("evidence")
	await _capture("06-journal")
	scene.ui._open_map()
	await _capture("07-map")
	scene.ui._open_settings(false)
	await _capture("08-settings")
	scene.ui._show_outcome(state.submit_conclusion("huy", "staged_room"))
	await _capture("09-outcome")
	scene.ui.show_main_menu()
	root.get_node("Settings").set_resolution(Vector2i(960, 540))
	root.size = Vector2i(960, 540)
	await _capture("10-small-menu")
	scene._start_session(false)
	scene.ui.open_inspection("maintenance_note")
	await _capture("11-small-inspection")
	scene.queue_free()
	await process_frame
	quit()

func _capture(label: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var error: Error = frame.save_png(output.path_join(label + ".png"))
	if error != OK:
		printerr("Capture failed: " + label)
		quit(1)
	print("CAPTURE: " + output.path_join(label + ".png"))
