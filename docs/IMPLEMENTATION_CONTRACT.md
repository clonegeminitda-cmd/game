# Prototype contracts

Godot 4.6.3, GDScript, Compatibility renderer. This is phase 1, offline and single player. No online or AI companion functionality is claimed. The scene is `/scenes/main.tscn` with `/scripts/main.gd`. Runtime-built geometry and UI are deliberate editable prototypes.

## Shared data and signals

Autoload `GameState` at `scripts/core/game_state.gd` owns state. Signals: `changed()`, `clue_collected(evidence_id: String)`, `notification(message: String)`. Properties: `case_data: Dictionary`, `collected: Dictionary`, `notes: String`, `elapsed_seconds: float`, `session_active: bool`, `outcome: Dictionary`, `player_position: Vector3`, `player_yaw: float`.

Methods: `start_new()`, `get_evidence(id: String) -> Dictionary`, `collect_evidence(id: String, observation_id: String) -> Dictionary` (returns `{ok: bool, message: String}`), `has_evidence(id: String) -> bool`, `submit_conclusion(suspect_id: String, mechanism_id: String) -> Dictionary`, `save_progress() -> bool`, `load_progress() -> bool`, `has_save() -> bool`, `get_hint() -> String`, `validate_case(data: Dictionary) -> Array[String]`.

Case JSON: id, title, subtitle, briefing, evidence (array), suspects (array of id/name/statement), mechanisms (array id/text), solution (suspect_id/mechanism_id/required_evidence array), timeline (array of time/event), hints (array of strings). Evidence fields: id, title, location, description, detail, method, observations (array id/text), correct_observation, analysis. IDs: `door_thread`, `ward_clock`, `cctv_log`, `medical_report`, `maintenance_note`, `witness_statement`. Correct observations require interpreting a close-up description, not merely pressing E. Three outcomes: correct with evidence, correct but insufficient, wrong.

## World

`scripts/world/hospital.gd` extends Node3D; public `spawn_position = Vector3(0,0.1,8)`, `spawn_yaw = 0.0`, `get_location(position: Vector3) -> String`. Main instantiates hospital and player. Walkable corridor x=[-2.8,2.8], z=[-14,12]; room 307 on east x=[3,11], z=[-10,-2], open entrance x=3,z=-5; camera room west x=[-10,-3], z=[-1,7], open entrance x=-3,z=3. All geometry/colliders built by hospital. No external assets needed beyond licensed fonts.

`scripts/world/interactable.gd` extends StaticBody3D with `class_name EvidenceObject`, public `evidence_id: String`, `display_name: String`, `interaction_kind: String = "evidence"`, and `set_focused(value: bool)`. Collision layer 2; physical level geometry layer 1. Player ray mask 3, walks collision mask 3. Attach scripts to all six evidence objects; evidence remains inspectable after collection. World should not implement collection itself. Main connects player to UI; state changes update UI.

## Player and UI

`scripts/player/player.gd` class_name Investigator extends CharacterBody3D. Signals `interact_requested(evidence_id: String)`, `focus_changed(text: String)`. Methods `set_enabled(value: bool)`, `get_camera() -> Camera3D`; property `flashlight_on: bool`. Creates camera, capsule and flashlight; respects `GameState.session_active` and a separate enabled flag. Main manages menus without pausing tree globally.

`scripts/ui/game_ui.gd` extends CanvasLayer. Signals `start_requested(resume: bool)`, `exit_requested()`, `modal_changed(open: bool)`. Public `modal_open: bool`, `show_main_menu()`, `show_hud()`, `open_inspection(id: String)`, `set_focus(text: String)`, `set_location(text: String)`, `set_flashlight(value: bool)`. UI handles Tab journal, M map, Escape pause/close, settings, collection and conclusions. `show_hud()` closes modal and enables input via signal. Main handles start/exit and remembers position for saves. Render interactive investigation journal with evidence, statements, timeline, editable notes and a conclusion panel. Include a clear phase-1 scope note in main menu, no fake online buttons.

`Settings` autoload in `scripts/core/settings.gd` supplied by primary agent: `quality: int`, `fps_limit: int`, `sensitivity: float`, `master_volume: float`, `apply()`, `save_settings()`, `set_quality(value: int)`, `set_fps_limit(value: int)`, `set_fullscreen(value: bool)`. Quality names Vietnamese; four presets and 30/45/60/90 caps.

Use explicit typed variables where Godot cannot infer from Variant. Avoid warnings-as-errors. No source changes outside owned paths without coordination.
