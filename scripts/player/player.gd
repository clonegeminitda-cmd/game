class_name Investigator
extends CharacterBody3D
## Local first-person input adapter. Interaction requests do not mutate case state.

signal interact_requested(evidence_id: String)
signal focus_changed(text: String)
signal flashlight_changed(value: bool)

const WALK_SPEED: float = 2.8
const RUN_SPEED: float = 4.6
const CROUCH_SPEED: float = 1.4
const REACH: float = 2.8
var enabled: bool = false
var flashlight_on: bool = true
var _camera: Camera3D
var _flashlight: SpotLight3D
var _shape: CollisionShape3D
var _focus: EvidenceObject
var _pitch: float = 0.0
var _step_distance: float = 0.0
var _step_player: AudioStreamPlayer3D
var _crouched: bool = false


func _ready() -> void:
	name = "Investigator"
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 0.2
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.75
	_shape.shape = capsule
	_shape.position.y = 0.875
	add_child(_shape)
	_camera = Camera3D.new()
	_camera.position.y = 1.61
	_camera.fov = 75.0
	_camera.near = 0.06
	_camera.far = 70.0
	_camera.current = true
	add_child(_camera)
	_flashlight = SpotLight3D.new()
	_flashlight.position = Vector3(0.19, -0.16, -0.12)
	_flashlight.light_color = Color(0.92, 0.91, 0.78)
	_flashlight.light_energy = 3.0
	_flashlight.spot_range = 14.0
	_flashlight.spot_angle = 30.0
	_flashlight.spot_attenuation = 1.2
	_flashlight.shadow_enabled = false
	_camera.add_child(_flashlight)
	_step_player = AudioStreamPlayer3D.new()
	_step_player.stream = preload("res://assets/audio/footstep.wav")
	_step_player.volume_db = -15.0
	_step_player.max_distance = 10.0
	add_child(_step_player)


func get_camera() -> Camera3D:
	return _camera


func _exit_tree() -> void:
	stop_audio()


func stop_audio() -> void:
	if is_instance_valid(_step_player):
		_step_player.stop()
		_step_player.stream = null


func set_enabled(value: bool) -> void:
	enabled = value
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	if not enabled:
		_set_focus(null)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not GameState.session_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Settings.sensitivity)
		_pitch = clampf(_pitch - event.relative.y * Settings.sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
		_camera.rotation.x = _pitch
	if event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		_flashlight.visible = flashlight_on
		flashlight_changed.emit(flashlight_on)
	if event.is_action_pressed("interact") and is_instance_valid(_focus):
		interact_requested.emit(_focus.evidence_id)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not enabled or not GameState.session_active:
		return
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch != _crouched and (wants_crouch or _can_stand()):
		_crouched = wants_crouch
		(_shape.shape as CapsuleShape3D).height = 1.05 if _crouched else 1.75
		_shape.position.y = 0.525 if _crouched else 0.875
	_camera.position.y = move_toward(_camera.position.y, 0.94 if _crouched else 1.61, delta * 4.0)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_transform.basis * Vector3(input.x, 0.0, input.y)
	var speed := CROUCH_SPEED if _crouched else (RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 14.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 14.0)
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	else:
		velocity.y = -0.1
	var previous_position := global_position
	move_and_slide()
	_step_distance += Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z).length()
	if is_on_floor() and _step_distance > (0.85 if _crouched else 1.5):
		_step_distance = 0.0
		_step_player.pitch_scale = randf_range(0.9, 1.1)
		_step_player.play()
	GameState.player_position = global_position
	GameState.player_yaw = rotation.y
	_update_focus()


func _can_stand() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.85, 3)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_focus() -> void:
	var start := _camera.global_position
	var end := start - _camera.global_transform.basis.z * REACH
	var query := PhysicsRayQueryParameters3D.create(start, end, 3)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var candidate: EvidenceObject = null
	if not hit.is_empty() and hit.collider is EvidenceObject:
		candidate = hit.collider as EvidenceObject
	_set_focus(candidate)


func _set_focus(target: EvidenceObject) -> void:
	if target == _focus:
		return
	if is_instance_valid(_focus):
		_focus.set_focused(false)
	_focus = target
	var text := ""
	if is_instance_valid(_focus):
		_focus.set_focused(true)
		text = _focus.display_name
		if GameState.has_evidence(_focus.evidence_id):
			text += " · Đã ghi nhận"
	focus_changed.emit(text)
