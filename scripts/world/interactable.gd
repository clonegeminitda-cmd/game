extends StaticBody3D
class_name EvidenceObject

## A physical clue target. Reading/collecting it belongs to the investigation UI.
@export var evidence_id: String = ""
@export var display_name: String = ""
@export var interaction_kind: String = "evidence"
var _focused: bool = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("evidence_objects")
	set_focused(false)

func set_focused(value: bool) -> void:
	_focused = value
	var outline: Node3D = get_node_or_null("FocusOutline") as Node3D
	if outline:
		outline.visible = value
