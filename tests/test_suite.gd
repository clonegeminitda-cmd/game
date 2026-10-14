extends SceneTree
## Behavior checks against the actual autoload, JSON case, save file and main scene.
## Run through tests/run.sh so user progress remains untouched.

const ANSWERS: Dictionary = {
	"door_thread": "staged_lock",
	"ward_clock": "add_offset",
	"cctv_log": "manual_gap",
	"medical_report": "window_not_knock",
	"maintenance_note": "timed_knock",
	"witness_statement": "contradiction_huy"
}
const WRONG_ANSWERS: Dictionary = {
	"door_thread": "inside_only",
	"ward_clock": "subtract_offset",
	"cctv_log": "storm_only",
	"medical_report": "minute_exact",
	"maintenance_note": "ghost_confirmed",
	"witness_statement": "trust_all"
}
const SAVE_PATH: String = "user://case_307_save.json"
var state: Node
var passed: int = 0
var failed: int = 0
var clue_events: int = 0
var scene: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("DARK_EVIDENCE_TEST_RUN") != "1" or not OS.get_environment("DARK_EVIDENCE_DATA_HOME").begins_with("/tmp/dark-evidence-tests."):
		printerr("Refusing to modify normal saves. Use: bash tests/run.sh")
		quit(2)
		return
	state = root.get_node_or_null("GameState")
	if not _expect(state != null, "Case autoload exists"):
		quit(1)
		return
	state.set_process(false)
	state.clue_collected.connect(func(_id: String) -> void: clue_events += 1)
	_test_case_schema()
	_test_investigation()
	_test_endings()
	_test_persistence()
	await _test_scene()
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _test_case_schema() -> void:
	_expect(state.case_data.get("id") == "room_307", "Bundled case loads from JSON")
	_expect(state.validate_case(state.case_data).is_empty(), "Bundled case satisfies schema and references")
	_expect(state.case_data.get("evidence", []).size() == 6, "Phase one case supplies all six distinct clues")
	var invalid: Dictionary = state.case_data.duplicate(true)
	invalid["evidence"][0]["correct_observation"] = "unlisted_answer"
	_expect(not state.validate_case(invalid).is_empty(), "Schema rejects an answer absent from observation choices")
	invalid = state.case_data.duplicate(true)
	invalid["evidence"][1]["id"] = "door_thread"
	_expect(not state.validate_case(invalid).is_empty(), "Schema rejects duplicate evidence identities")
	invalid = state.case_data.duplicate(true)
	invalid["solution"]["required_evidence"].append("absent_clue")
	_expect(not state.validate_case(invalid).is_empty(), "Schema rejects missing required evidence references")
	invalid = state.case_data.duplicate(true)
	invalid["solution"]["suspect_id"] = "unknown_person"
	_expect(not state.validate_case(invalid).is_empty(), "Schema rejects an unknown solution suspect")
	invalid = state.case_data.duplicate(true)
	invalid["evidence"][0]["observations"] = "invalid_list"
	_expect(not state.validate_case(invalid).is_empty(), "Schema rejects a malformed observations collection")
	invalid = state.case_data.duplicate(true)
	invalid["timeline"][0] = "invalid_event"
	_expect(not state.validate_case(invalid).is_empty(), "Schema rejects a malformed timeline entry")
	invalid = state.case_data.duplicate(true)
	invalid["evidence"][0]["related_evidence"].append("unknown_relation")
	_expect(not state.validate_case(invalid).is_empty(), "Schema rejects broken clue relationships")
	_expect(not state.validate_case({}).is_empty(), "Schema rejects an empty case without crashing")
	var detached: Dictionary = state.get_evidence("door_thread")
	detached["title"] = "tampered"
	_expect(state.get_evidence("door_thread").get("title") != "tampered", "Inspection data cannot mutate the source case by reference")


func _test_investigation() -> void:
	state.session_active = false
	_expect(not state.collect_evidence("door_thread", "staged_lock").get("ok", true), "Collection requires an active investigation")
	state.start_new()
	_expect(state.session_active and state.collected.is_empty() and state.outcome.is_empty(), "New investigation clears previous progress")
	_expect(not state.collect_evidence("missing_clue", "staged_lock").get("ok", true), "Unknown evidence cannot be collected")
	_expect(not state.collect_evidence("door_thread", "add_offset").get("ok", true), "Correct observation from another clue does not unlock this clue")
	for id: String in ANSWERS:
		var count_before: int = state.collected.size()
		var result: Dictionary = state.collect_evidence(id, WRONG_ANSWERS[id])
		_expect(not result.get("ok", true) and state.collected.size() == count_before, "Unsupported interpretation is rejected: " + id)
		result = state.collect_evidence(id, ANSWERS[id])
		_expect(result.get("ok", false) and state.has_evidence(id), "Supported interpretation records evidence: " + id)
		var record_before: Dictionary = state.collected[id].duplicate(true)
		var signal_count: int = clue_events
		state.collect_evidence(id, ANSWERS[id])
		_expect(state.collected.size() == count_before + 1 and state.collected[id] == record_before and clue_events == signal_count, "Repeated collection preserves one immutable record: " + id)
	_expect(state.collected.size() == 6 and clue_events == 6, "Six discoveries emit six collection events")
	_expect(not state.get_hint().is_empty(), "Investigation always supplies a usable hint")


func _test_endings() -> void:
	state.start_new()
	var ending: Dictionary = state.submit_conclusion("huy", "staged_room")
	_expect(ending.get("status") == "insufficient" and ending.get("missing_evidence", []).size() == 6, "Knowing the answer without evidence cannot complete the case")
	for id: String in ANSWERS:
		if id != "witness_statement":
			state.collect_evidence(id, ANSWERS[id])
	ending = state.submit_conclusion("huy", "staged_room")
	_expect(ending.get("status") == "insufficient" and ending.get("missing_evidence") == ["witness_statement"], "Five clues cannot substitute for the required sixth clue")
	state.collect_evidence("witness_statement", "contradiction_huy")
	_expect(state.outcome.is_empty(), "New evidence clears the stale assessment")
	ending = state.submit_conclusion("binh", "staged_room")
	_expect(ending.get("status") == "wrong", "Full evidence with the wrong suspect produces the wrong ending")
	ending = state.submit_conclusion("huy", "supernatural")
	_expect(ending.get("status") == "wrong", "Correct suspect with an unsupported mechanism remains wrong")
	ending = state.submit_conclusion("huy", "staged_room")
	_expect(ending.get("status") == "correct" and ending.get("score") == 100 and ending.get("missing_evidence", []).is_empty(), "Supported suspect and mechanism with all six clues completes the case")
	var stable_outcome: Dictionary = state.outcome.duplicate(true)
	ending = state.submit_conclusion("unlisted", "staged_room")
	_expect(not ending.get("ok", true) and state.outcome == stable_outcome, "Invalid report cannot overwrite a valid assessment")
	_expect(state.session_active, "All endings allow returning to the investigation")


func _test_persistence() -> void:
	state.notes = "Đồng hồ chậm 7 phút.\nTiếng gõ: 23:39 — kiểm tra T-04."
	state.player_position = Vector3(0.5, 0.05, 7.0)
	state.player_yaw = -0.75
	state.elapsed_seconds = 91.25
	var expected: Dictionary = _snapshot()
	if not _expect(state.save_progress() and state.has_save(), "Valid progress writes a real save file: " + state.last_error):
		printerr("Save failure: " + state.last_error)
		return
	var valid_json: String = FileAccess.get_file_as_string(SAVE_PATH)
	_expect(not FileAccess.file_exists(SAVE_PATH + ".tmp"), "Successful save leaves no pending temporary file")
	state.start_new()
	_expect(state.load_progress(), "Save file reloads after starting another session")
	_expect(_snapshot() == expected, "Save round trip restores Unicode notes, evidence, elapsed time, transform and ending")
	_write_save("{ broken json")
	_expect(not state.load_progress() and _snapshot() == expected, "Truncated JSON fails without changing the active investigation")
	var invalid: Dictionary = JSON.parse_string(valid_json)
	invalid["collected"]["door_thread"]["observation_id"] = "inside_only"
	_write_save(JSON.stringify(invalid))
	_expect(not state.load_progress() and _snapshot() == expected, "Forged evidence observation cannot be loaded or mutate progress")
	invalid = JSON.parse_string(valid_json)
	invalid["player_position"] = [500.0, -20.0, 800.0]
	_write_save(JSON.stringify(invalid))
	_expect(not state.load_progress() and _snapshot() == expected, "Out of bounds saved spawn is rejected without state loss")
	invalid = JSON.parse_string(valid_json)
	invalid["conclusion"]["score"] = 100
	_write_save(JSON.stringify(invalid))
	_expect(not state.load_progress() and _snapshot() == expected, "Saved conclusions cannot inject a score")
	invalid = JSON.parse_string(valid_json)
	invalid["version"] = 999
	_write_save(JSON.stringify(invalid))
	_expect(not state.load_progress() and _snapshot() == expected, "Unsupported save versions preserve current state")
	_write_save("x".repeat(262145))
	_expect(not state.load_progress() and _snapshot() == expected, "Oversized saves are rejected before parsing")
	_write_save(valid_json)
	state.notes = "x".repeat(16001)
	_expect(not state.save_progress() and FileAccess.get_file_as_string(SAVE_PATH) == valid_json, "Rejected write preserves the previous valid save")
	_expect(state.load_progress() and _snapshot() == expected, "Previous valid save remains recoverable after all failure cases")


func _test_scene() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if not _expect(packed != null, "Main scene resource loads"):
		return
	scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	_expect(scene.get("hospital") != null and scene.get("player") != null and scene.get("ui") != null, "Main scene composes hospital, investigator and UI")
	_expect(scene.ui.modal_open and not scene.player.enabled and not state.session_active, "Main menu gates movement and investigation commands")
	scene._start_session(false)
	for frame in range(20):
		await physics_frame
	_expect(scene.player.is_on_floor() and absf(scene.player.position.y) < 0.15, "Investigator settles on the physical floor")
	var start: Vector3 = scene.player.position
	Input.action_press("move_forward")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_forward")
	_expect(scene.player.position.z < start.z - 0.7, "WASD input moves the actual CharacterBody through the scene")
	Input.action_press("crouch")
	for frame in range(15):
		await physics_frame
	_expect(scene.player._crouched and scene.player.get_camera().position.y < 1.2, "Crouching lowers capsule and eye height")
	Input.action_release("crouch")
	for frame in range(15):
		await physics_frame
	_expect(not scene.player._crouched, "Standing returns when overhead space is clear")
	scene.player.set_enabled(false)
	scene.player.position = Vector3(2.3, 0.05, 0)
	scene.player.rotation.y = 0
	scene.player.get_camera().rotation = Vector3.ZERO
	scene.player.set_enabled(true)
	Input.action_press("move_right")
	for frame in range(45):
		await physics_frame
	Input.action_release("move_right")
	_expect(scene.player.position.x < 2.65, "Solid corridor wall blocks walking through it")
	scene.player.set_enabled(false)
	var evidence_nodes: Array[Node] = get_nodes_in_group("evidence_objects")
	_expect(evidence_nodes.size() == 6, "Scene contains six physical evidence targets")
	var stands: Dictionary = {
		"door_thread": Vector3(1.3, 0.05, -4.0),
		"ward_clock": Vector3(1.2, 0.05, 5.0),
		"cctv_log": Vector3(-7.65, 0.05, 2.65),
		"medical_report": Vector3(8.9, 0.05, -4.8),
		"maintenance_note": Vector3(-1.3, 0.05, -1.4),
		"witness_statement": Vector3(1.55, 0.05, 8.5)
	}
	for target: Node3D in evidence_nodes:
		scene.player.position = stands[target.evidence_id]
		scene.player.get_camera().position.y = 1.61
		scene.player.get_camera().look_at(target.global_position)
		await physics_frame
		scene.player._update_focus()
		_expect(scene.player._focus == target, "Player can aim at and reach clue: " + target.evidence_id)
	# A target behind the west wall must not be detectable through architecture.
	scene.player.position = Vector3(0, 0.05, 0)
	var remote: Node3D = scene.hospital.get_node("Evidence_cctv_log")
	var query := PhysicsRayQueryParameters3D.create(scene.player.get_camera().global_position, remote.global_position, 3)
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty() and hit.collider != remote and hit.collider.collision_layer == 1, "Interaction ray stops at the wall before distant evidence")
	# Traverse both real doorways under physics, rather than merely teleporting.
	await _walk_through_door(Vector3(1.0, 0.05, -5.0), "move_right", true)
	await _walk_through_door(Vector3(-1.0, 0.05, 3.0), "move_left", false)
	scene.ui.show_hud()
	scene.ui.open_inspection("ward_clock")
	await process_frame
	_expect(scene.ui.modal_open and not scene.player.enabled and scene.ui._modal_kind == "inspection", "Inspection disables movement and exposes an actual modal")
	var wrong: Button = _button_with_text(scene.ui._modal, "Tiếng gõ xảy ra vào khoảng 23:25")
	if _expect(wrong != null, "Inspection creates selectable observation buttons"):
		wrong.pressed.emit()
		_expect(not state.has_evidence("ward_clock"), "Wrong UI observation leaves the clue uncollected")
	var correct: Button = _button_with_text(scene.ui._modal, "Đồng hồ chậm 7 phút")
	if _expect(correct != null, "Correct observation is available in the inspection UI"):
		correct.pressed.emit()
		await process_frame
		_expect(state.has_evidence("ward_clock") and state.has_save(), "Correct UI observation records and saves the clue")
	scene.ui.show_hud()
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	scene.ui._input(key)
	_expect(scene.ui._modal_kind == "journal" and not scene.player.enabled, "Tab opens the journal and releases movement capture")
	scene.ui._open_journal("notes")
	await process_frame
	var edit: TextEdit = _find_text_edit(scene.ui._modal)
	if _expect(edit != null, "Journal supplies an editable notebook"):
		edit.text = "Ghi chú UI: 23:32 + 7 = 23:39."
		edit.text_changed.emit()
		scene.ui._open_journal("timeline")
		_expect(state.notes.contains("23:39") and not scene.ui._notes_dirty, "Switching journal tabs saves Unicode notes")
	scene.ui._open_map()
	_expect(scene.ui._modal_kind == "map", "Map screen opens from the live investigation")
	scene.ui.show_hud()
	_expect(scene.player.enabled and not scene.ui.modal_open, "Closing modal restores character input")
	key.keycode = KEY_F3
	var was_visible: bool = scene.ui._metrics.visible
	scene.ui._input(key)
	_expect(scene.ui._metrics.visible != was_visible, "F3 toggles performance metrics")
	var settings: Node = root.get_node("Settings")
	for quality in range(4):
		settings.set_quality(quality)
		_expect(settings.quality == quality and root.scaling_3d_scale > 0.0, "Graphics preset %d applies" % quality)
	settings.set_fps_limit(45)
	_expect(Engine.max_fps == 45, "Frame cap setting reaches the engine")
	settings.set_fps_limit(60)
	scene.ui.show_main_menu()
	_expect(not state.session_active and not scene.player.enabled, "Returning to menu stops active investigation input")
	scene.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout


func _walk_through_door(from: Vector3, action: String, east: bool) -> void:
	scene.player.position = from
	scene.player.rotation.y = 0.0
	scene.player.get_camera().rotation = Vector3.ZERO
	scene.player.set_enabled(true)
	Input.action_press(action)
	for frame in range(65):
		await physics_frame
	Input.action_release(action)
	scene.player.set_enabled(false)
	_expect(scene.player.position.x > 3.3 if east else scene.player.position.x < -3.3, "Doorway is physically traversable: " + ("room 307" if east else "camera room"))


func _button_with_text(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for child: Node in node.get_children():
		var found: Button = _button_with_text(child, prefix)
		if found != null:
			return found
	return null


func _find_text_edit(node: Node) -> TextEdit:
	if node is TextEdit:
		return node
	for child: Node in node.get_children():
		var found: TextEdit = _find_text_edit(child)
		if found != null:
			return found
	return null


func _snapshot() -> Dictionary:
	return {
		"collected": state.collected.duplicate(true),
		"notes": state.notes,
		"elapsed_seconds": state.elapsed_seconds,
		"player_position": state.player_position,
		"player_yaw": state.player_yaw,
		"outcome": state.outcome.duplicate(true),
		"session_active": state.session_active
	}


func _write_save(content: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _expect(condition: bool, message: String) -> bool:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		printerr("FAIL: " + message)
	return condition
