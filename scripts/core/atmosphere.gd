extends Node3D
## Original generated audio, spatial knocks, low-cost non-blocking ambience.

var _rain: AudioStreamPlayer
var _hum: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _timer: float = 0.0
var _knocked: bool = false


func _ready() -> void:
	_rain = AudioStreamPlayer.new()
	_rain.stream = preload("res://assets/audio/rain.wav")
	(_rain.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(_rain.stream as AudioStreamWAV).loop_end = 88200
	_rain.volume_db = -23.0
	add_child(_rain)
	_rain.play()
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = preload("res://assets/audio/electric.wav")
	(_hum.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(_hum.stream as AudioStreamWAV).loop_end = 22050
	_hum.volume_db = -26.0
	_hum.position = Vector3(0, 2.5, -3)
	_hum.max_distance = 14.0
	add_child(_hum)
	_hum.play()
	_knock = AudioStreamPlayer3D.new()
	_knock.stream = preload("res://assets/audio/knock.wav")
	_knock.position = Vector3(3, 1.4, -5)
	_knock.volume_db = -11.0
	_knock.max_distance = 22.0
	add_child(_knock)
	GameState.changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	if GameState.elapsed_seconds < 1.0:
		_timer = 0.0
		_knocked = false


func _process(delta: float) -> void:
	if not GameState.session_active:
		return
	_timer += delta
	if not _knocked and _timer > 24.0 and GameState.player_position.z < 1.0:
		_knocked = true
		_knock.play()
		GameState.notification.emit("Ba tiếng gõ. Âm thanh vọng từ phía phòng 307.")


func _exit_tree() -> void:
	stop_audio()


func stop_audio() -> void:
	# Release looping playback before the audio server shuts down (including the
	# Dummy backend used by automated scene teardown).
	for sound in [_rain, _hum, _knock]:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
