extends CanvasLayer
## An offline investigation interface. The world keeps running behind every dossier.

signal start_requested(resume: bool)
signal exit_requested()
signal modal_changed(open: bool)

const INK := Color("101b20")
const PANEL := Color("142329")
const PANEL_LIGHT := Color("1b3036")
const PAPER := Color("eae7dc")
const MUTED := Color("97adad")
const AMBER := Color("e9b46a")
const TEAL := Color("70c9bb")
const LINE := Color("31464a")
const RED := Color("e59886")
const FONT := preload("res://assets/fonts/NotoSans-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/NotoSans-Bold.ttf")
const FONT_TITLE := preload("res://assets/fonts/LiberationSerif-Regular.ttf")

var modal_open: bool = true
var _root: Control
var _menu: Control
var _hud: Control
var _modal: Control
var _modal_kind: String = ""
var _modal_body: VBoxContainer
var _return_menu: bool = false
var _location: Label
var _task: Label
var _evidence_count: Label
var _flashlight: Label
var _focus: Label
var _metrics: Label
var _toast: Label
var _toast_left: float = 0.0
var _metrics_elapsed: float = 0.0
var _journal_section: String = "evidence"
var _inspection_id: String = ""
var _notes_dirty: bool = false
var _continue_button: Button


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "InvestigationInterface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_menu()
	_build_hud()
	GameState.changed.connect(_update_hud)
	GameState.notification.connect(_notify)
	show_main_menu()


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("66797c"))
	theme.set_stylebox("normal", "Button", _box(PANEL_LIGHT, LINE, 5, 17, 12))
	theme.set_stylebox("hover", "Button", _box(Color("254348"), TEAL, 5, 17, 12))
	theme.set_stylebox("pressed", "Button", _box(Color("355051"), AMBER, 5, 17, 12))
	theme.set_stylebox("disabled", "Button", _box(Color("142126"), Color("23373a"), 5, 17, 12))
	theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, AMBER, 5, 17, 12))
	theme.set_stylebox("normal", "OptionButton", _box(PANEL_LIGHT, LINE, 5, 15, 12))
	theme.set_stylebox("hover", "OptionButton", _box(Color("254348"), TEAL, 5, 15, 12))
	theme.set_stylebox("pressed", "OptionButton", _box(Color("254348"), AMBER, 5, 15, 12))
	theme.set_stylebox("focus", "OptionButton", _box(Color.TRANSPARENT, AMBER, 5, 15, 12))
	theme.set_color("font_color", "OptionButton", PAPER)
	theme.set_stylebox("panel", "PopupMenu", _box(INK, LINE, 5, 12, 10))
	theme.set_stylebox("hover", "PopupMenu", _box(PANEL_LIGHT, TEAL, 3, 8, 8))
	theme.set_color("font_color", "PopupMenu", PAPER)
	theme.set_stylebox("normal", "TextEdit", _box(Color("0c171c"), LINE, 5, 16, 14))
	theme.set_stylebox("focus", "TextEdit", _box(Color("0c171c"), AMBER, 5, 16, 14))
	theme.set_color("font_color", "TextEdit", PAPER)
	theme.set_color("font_placeholder_color", "TextEdit", MUTED)
	theme.set_color("caret_color", "TextEdit", AMBER)
	theme.set_color("selection_color", "TextEdit", Color("315655"))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("h_separation", "GridContainer", 16)
	theme.set_constant("v_separation", "GridContainer", 16)
	theme.set_stylebox("separator", "HSeparator", _box(LINE, Color.TRANSPARENT, 0, 0, 0))
	return theme


func _box(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 0, x_pad: int = 0, y_pad: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = x_pad
	box.content_margin_right = x_pad
	box.content_margin_top = y_pad
	box.content_margin_bottom = y_pad
	return box


func _label(text: String, size: int = 15, color: Color = PAPER, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _heading(text: String, size: int = 34) -> Label:
	var label := _label(text, size)
	label.add_theme_font_override("font", FONT_TITLE)
	return label


func _button(text: String, callback: Callable, prominent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	if prominent:
		button.add_theme_stylebox_override("normal", _box(AMBER, AMBER, 5, 18, 13))
		button.add_theme_stylebox_override("hover", _box(Color("f2c788"), Color("f2c788"), 5, 18, 13))
		button.add_theme_stylebox_override("pressed", _box(Color("d59b50"), Color("d59b50"), 5, 18, 13))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_font_override("font", FONT_BOLD)
	return button


func _margin(parent: Node, amount: int = 24) -> MarginContainer:
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, amount)
	parent.add_child(margin)
	return margin


func _card(parent: Node, fill: Color = PANEL_LIGHT) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(fill, LINE, 6, 21, 19))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	return content


func _eyebrow(parent: Node, text: String, color: Color = AMBER) -> void:
	var label := _label(text, 12, color)
	label.add_theme_font_override("font", FONT_BOLD)
	parent.add_child(label)


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_menu)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.025, 0.055, 0.065, 0.98))
	gradient.add_point(0.46, Color(0.025, 0.055, 0.065, 0.93))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.025, 0.055, 0.065, 0.20))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(1, 0)
	var shadow := TextureRect.new()
	shadow.texture = gradient_texture
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(shadow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_bottom", 26)
	_menu.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)
	var masthead := HBoxContainer.new()
	layout.add_child(masthead)
	var mark := _label("D E   /   CỤC ĐIỀU TRA HIỆN TƯỢNG", 11, TEAL)
	mark.add_theme_font_override("font", FONT_BOLD)
	masthead.add_child(mark)
	var build := _label("BẢN THỬ NGHIỆM   /   01", 11, MUTED, false)
	masthead.add_child(build)
	var rule := HSeparator.new()
	layout.add_child(rule)
	var center := HBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 12)
	scroll.add_child(left)
	_eyebrow(left, "MỌI DẤU VẾT ĐỀU ĐỂ LẠI MỘT CÂU CHUYỆN.")
	var title := _heading("DARK\nEVIDENCE", 73)
	title.add_theme_constant_override("line_spacing", -7)
	left.add_child(title)
	var subtitle := _label("H Ồ   S Ơ   B Ó N G   T Ố I", 15, AMBER)
	subtitle.add_theme_font_override("font", FONT_BOLD)
	left.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	left.add_child(gap)
	left.add_child(_label("Một căn phòng đóng kín. Sáu dấu vết bị bỏ lại.\nSự thật không nằm trong những lời đồn.", 16, MUTED))
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 330
	actions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	actions.add_theme_constant_override("separation", 8)
	left.add_child(actions)
	actions.add_child(_button("MỞ HỒ SƠ MỚI     →", _request_new, true))
	_continue_button = _button("Tiếp tục điều tra", _request_continue)
	actions.add_child(_continue_button)
	var options := HBoxContainer.new()
	actions.add_child(options)
	var settings := _button("Thiết lập", func() -> void: _open_settings(true))
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(settings)
	var quit := _button("Thoát", func() -> void: exit_requested.emit())
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(quit)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 320
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	center.add_child(right)
	var dossier := _card(right, Color(0.04, 0.10, 0.12, 0.87))
	_eyebrow(dossier, "HỒ SƠ ĐANG MỞ   /   307", TEAL)
	dossier.add_child(_heading("Tiếng gõ\nphòng 307", 34))
	dossier.add_child(_label("BỆNH VIỆN AN TĨNH\nKhu nội trú bỏ hoang · 23:40", 12, MUTED))
	dossier.add_child(HSeparator.new())
	dossier.add_child(_label("Quan sát. Đối chiếu. Kết luận.", 14, PAPER))
	layout.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	footer.add_child(_label("GIAI ĐOẠN 1 · CHƠI ĐƠN NGOẠI TUYẾN\nNguyên mẫu điều tra 3D · Chưa có co-op / AI đồng đội", 11, MUTED))
	var controls := _label("WASD  Di chuyển     E  Khám xét\nTAB  Hồ sơ     F  Đèn pin     ESC  Tạm nghỉ", 11, MUTED, false)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(controls)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 30)
	top.add_theme_constant_override("margin_right", 30)
	top.add_theme_constant_override("margin_top", 24)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	_eyebrow(left, "DARK EVIDENCE   /   HỒ SƠ 307", AMBER)
	_location = _heading("Hành lang khu nội trú", 26)
	left.add_child(_location)
	_task = _label("Khám sát hiện trường và thu thập dấu vết.", 13, PAPER)
	left.add_child(_task)
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	_evidence_count = _label("00 / 06   DẤU VẾT", 14, TEAL, false)
	_evidence_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_evidence_count)
	_flashlight = _label("F  ĐÈN PIN · BẬT", 11, MUTED, false)
	_flashlight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_flashlight)
	var dot := ColorRect.new()
	dot.color = Color(0.85, 0.93, 0.88, 0.82)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	dot.size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(dot)
	_focus = _label("", 16, PAPER, false)
	_focus.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_focus.offset_left = -340
	_focus.offset_right = 340
	_focus.offset_top = -146
	_focus.offset_bottom = -102
	_focus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus.add_theme_stylebox_override("normal", _box(Color(0.03, 0.07, 0.08, 0.84), LINE, 5, 18, 10))
	_hud.add_child(_focus)
	_focus.hide()
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -68
	bottom.add_theme_constant_override("margin_left", 30)
	bottom.add_theme_constant_override("margin_right", 30)
	bottom.add_theme_constant_override("margin_bottom", 18)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_row)
	bottom_row.add_child(_label("TAB  Hồ sơ     M  Sơ đồ     SHIFT  Chạy     ESC  Tạm nghỉ", 11, MUTED))
	_metrics = _label("", 10, MUTED, false)
	_metrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_row.add_child(_metrics)
	_toast = _label("", 14, TEAL)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -350
	_toast.offset_right = 350
	_toast.offset_top = -211
	_toast.offset_bottom = -158
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", _box(Color(0.03, 0.07, 0.08, 0.96), TEAL, 5, 16, 12))
	_root.add_child(_toast)
	_toast.hide()


func show_main_menu() -> void:
	_remove_modal()
	if GameState.session_active:
		GameState.save_progress()
		GameState.session_active = false
	_menu.show()
	_hud.hide()
	_continue_button.disabled = not GameState.has_save()
	_modal_kind = "menu"
	_set_modal(true)


func show_hud() -> void:
	_remove_modal()
	_menu.hide()
	_hud.show()
	_modal_kind = ""
	_set_modal(false)
	_update_hud()


func _request_new() -> void:
	if GameState.has_save():
		_open_modal("Mở hồ sơ mới", "BẮT ĐẦU LẠI", "confirm_new", true)
		_modal_body.add_child(_heading("Mở lại hồ sơ từ đầu?", 32))
		_modal_body.add_child(_label("Bản lưu hiện tại sẽ được thay bằng một cuộc điều tra mới. Ghi chú và những dấu vết đã thu thập sẽ được đặt lại.", 16, MUTED))
		_modal_body.add_child(_button("Bắt đầu cuộc điều tra mới", func() -> void: start_requested.emit(false), true))
		_modal_body.add_child(_button("Giữ bản lưu hiện tại", _close_modal))
	else:
		start_requested.emit(false)


func _request_continue() -> void:
	start_requested.emit(true)


func _set_modal(value: bool) -> void:
	modal_open = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	modal_changed.emit(value)


func _remove_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
		_modal = null
	if _notes_dirty:
		GameState.save_progress()
		_notes_dirty = false


func _close_modal() -> void:
	if _return_menu or _menu.visible:
		show_main_menu()
	else:
		show_hud()


func _open_modal(title: String, eyebrow: String, kind: String, return_menu: bool = false) -> void:
	_remove_modal()
	_return_menu = return_menu
	_modal_kind = kind
	_set_modal(true)
	_modal = Control.new()
	_modal.name = "Dossier_" + kind
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_modal)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.025, 0.03, 0.79)
	_modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.075
	panel.anchor_right = 0.925
	panel.anchor_top = 0.065
	panel.anchor_bottom = 0.935
	panel.add_theme_stylebox_override("panel", _box(INK, LINE, 8, 28, 24))
	_modal.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	top.add_child(title_stack)
	_eyebrow(title_stack, eyebrow)
	title_stack.add_child(_heading(title, 34))
	var close := _button("ĐÓNG  ×", _close_modal)
	close.tooltip_text = "Escape để đóng"
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(close)
	layout.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 18)
	scroll.add_child(_modal_body)
	var footer := _label("HỒ SƠ 307     /     QUAN SÁT TRƯỚC KHI KẾT LUẬN", 10, MUTED)
	layout.add_child(footer)


func open_inspection(id: String) -> void:
	var evidence: Dictionary = GameState.get_evidence(id)
	if evidence.is_empty():
		_notify("Không tìm thấy hồ sơ của dấu vết này.")
		return
	_inspection_id = id
	_open_modal(str(evidence.get("title", "Dấu vết")), "KHÁM XÉT HIỆN TRƯỜNG   /   " + str(evidence.get("location", "")), "inspection")
	var collected: bool = GameState.has_evidence(id)
	var lead := _card(_modal_body)
	_eyebrow(lead, "ĐÃ LƯU VÀO HỒ SƠ" if collected else "VẬT CHỨNG CHƯA ĐƯỢC GHI NHẬN", TEAL if collected else AMBER)
	lead.add_child(_label(str(evidence.get("description", "")), 18))
	var detail := _card(_modal_body, Color("0e1d22"))
	_eyebrow(detail, "QUAN SÁT CẬN CẢNH", MUTED)
	detail.add_child(_label(str(evidence.get("detail", "")), 16))
	detail.add_child(_label("Phương pháp: " + str(evidence.get("method", "Quan sát")), 12, MUTED))
	if collected:
		var analysis := _card(_modal_body)
		_eyebrow(analysis, "NHẬN ĐỊNH ĐÃ GHI", TEAL)
		analysis.add_child(_label(str(evidence.get("analysis", "")), 16))
		_modal_body.add_child(_button("Mở hồ sơ điều tra  →", func() -> void: _open_journal("evidence"), true))
	else:
		_eyebrow(_modal_body, "CHI TIẾT NÀO CÓ THỂ KIỂM CHỨNG TỪ QUAN SÁT TRÊN?")
		var feedback := _label("Chọn một nhận định để ghi nhận vật chứng.", 13, MUTED)
		for observation: Dictionary in evidence.get("observations", []):
			var choice := _button(str(observation.get("text", "")), _record_observation.bind(id, str(observation.get("id", "")), feedback))
			choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
			choice.custom_minimum_size.y = 60
			_modal_body.add_child(choice)
		_modal_body.add_child(feedback)


func _record_observation(id: String, observation_id: String, feedback: Label) -> void:
	var result: Dictionary = GameState.collect_evidence(id, observation_id)
	if bool(result.get("ok", false)):
		open_inspection(id)
	else:
		feedback.text = str(result.get("message", "Nhận định chưa phù hợp. Hãy đọc lại chi tiết và thử lại."))
		feedback.add_theme_color_override("font_color", RED)


func _open_journal(section: String = "evidence") -> void:
	_journal_section = section
	_open_modal("Hồ sơ điều tra", "TIẾNG GÕ PHÒNG 307   /   BỆNH VIỆN AN TĨNH", "journal")
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	_modal_body.add_child(tabs)
	for tab: Array in [["evidence", "Vật chứng"], ["statements", "Lời khai"], ["timeline", "Dòng thời gian"], ["notes", "Ghi chú"], ["conclusion", "Kết luận"]]:
		var button := _button(str(tab[1]), _open_journal.bind(str(tab[0])), section == str(tab[0]))
		tabs.add_child(button)
	match section:
		"evidence": _journal_evidence()
		"statements": _journal_statements()
		"timeline": _journal_timeline()
		"notes": _journal_notes()
		"conclusion": _journal_conclusion()


func _journal_evidence() -> void:
	_modal_body.add_child(_label(str(GameState.case_data.get("briefing", "")), 15, MUTED))
	var count: int = GameState.collected.size()
	var evidence_list: Array = GameState.case_data.get("evidence", [])
	_eyebrow(_modal_body, "VẬT CHỨNG ĐÃ ĐỐI CHIẾU   %02d / %02d" % [count, evidence_list.size()], TEAL)
	var grid := GridContainer.new()
	grid.columns = 3 if get_viewport().get_visible_rect().size.x >= 1100 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(grid)
	var index: int = 0
	for evidence: Dictionary in evidence_list:
		index += 1
		var id: String = str(evidence.get("id", ""))
		var found: bool = GameState.has_evidence(id)
		var card := _card(grid, PANEL_LIGHT if found else Color("132127"))
		card.custom_minimum_size.x = 190
		_eyebrow(card, "%02d   /   %s" % [index, "ĐÃ GHI NHẬN" if found else "CHƯA KHÁM XÉT"], TEAL if found else MUTED)
		card.add_child(_heading(str(evidence.get("title", "")) if found else "Dấu vết chưa rõ", 25))
		card.add_child(_label(str(evidence.get("location", "")), 12, MUTED))
		var description := _label(str(evidence.get("analysis", "")) if found else "Tìm vật khả nghi tại hiện trường. Quan sát cẩn thận trước khi ghi nhận.", 13, PAPER if found else MUTED)
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(description)
		var view := _button("Xem vật chứng  ↗" if found else "Cần khám xét tại hiện trường", open_inspection.bind(id))
		view.disabled = not found
		view.add_theme_font_size_override("font_size", 12)
		card.add_child(view)
	var hint := _card(_modal_body, Color("1d2929"))
	_eyebrow(hint, "CẦN MỘT HƯỚNG ĐI?")
	var hint_text := _label("Gợi ý là tùy chọn. Bạn có thể tự đối chiếu các dấu vết trong hồ sơ.", 13, MUTED)
	hint.add_child(hint_text)
	hint.add_child(_button("Xem gợi ý tiếp theo", func() -> void: hint_text.text = GameState.get_hint()))


func _journal_statements() -> void:
	_modal_body.add_child(_label("Lời khai có thể sai lệch. Hãy đối chiếu với vật chứng và mốc thời gian.", 15, MUTED))
	for suspect: Dictionary in GameState.case_data.get("suspects", []):
		var card := _card(_modal_body)
		_eyebrow(card, "NGƯỜI LIÊN QUAN", MUTED)
		card.add_child(_heading(str(suspect.get("name", "")), 27))
		if suspect.has("role"):
			card.add_child(_label(str(suspect["role"]), 12, TEAL))
		card.add_child(_label("“" + str(suspect.get("statement", "")) + "”", 16))


func _journal_timeline() -> void:
	_modal_body.add_child(_label("Các mốc chỉ xuất hiện khi có vật chứng hỗ trợ. Khoảng trống chưa đủ để khẳng định một giả thuyết.", 15, MUTED))
	var index: int = 0
	for entry: Dictionary in GameState.case_data.get("timeline", []):
		var required: Array = entry.get("requires", entry.get("evidence_ids", []))
		var unlocked: bool = required.is_empty()
		if not required.is_empty():
			unlocked = true
			for id: Variant in required:
				if not GameState.has_evidence(str(id)):
					unlocked = false
		if entry.has("evidence_id"):
			unlocked = GameState.has_evidence(str(entry["evidence_id"]))
		var card := _card(_modal_body, PANEL_LIGHT if unlocked else Color("132127"))
		_eyebrow(card, str(entry.get("time", "--:--")) if unlocked else "--:--   /   CHƯA XÁC MINH", TEAL if unlocked else MUTED)
		card.add_child(_label(str(entry.get("event", "")) if unlocked else "Thu thập và đối chiếu thêm vật chứng để xác minh mốc này.", 16, PAPER if unlocked else MUTED))
		index += 1
	if index == 0:
		_modal_body.add_child(_label("Chưa có mốc thời gian được ghi nhận.", 16, MUTED))


func _journal_notes() -> void:
	_eyebrow(_modal_body, "SỔ TAY CÁ NHÂN", TEAL)
	_modal_body.add_child(_label("Ghi lại mâu thuẫn, thời điểm và giả thuyết của bạn. Ghi chú được lưu khi đóng hồ sơ hoặc chuyển mục.", 15, MUTED))
	var edit := TextEdit.new()
	edit.text = GameState.notes
	edit.placeholder_text = "02:17 — Ai đã có mặt ở phòng 307?\nChi tiết cần đối chiếu: ..."
	edit.custom_minimum_size.y = 280
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text_changed.connect(func() -> void:
		if edit.text.length() > 16000:
			edit.text = edit.text.left(16000)
			_notify("Sổ tay lưu tối đa 16.000 ký tự.")
		GameState.notes = edit.text
		_notes_dirty = true
	)
	_modal_body.add_child(edit)
	_modal_body.add_child(_button("Lưu ghi chú", func() -> void:
		if GameState.save_progress():
			_notes_dirty = false
			_notify("Đã lưu ghi chú điều tra.")
	))


func _journal_conclusion() -> void:
	var card := _card(_modal_body)
	_eyebrow(card, "ĐỐI CHIẾU CUỐI CÙNG")
	card.add_child(_heading("Ai đứng sau tiếng gõ?", 31))
	card.add_child(_label("Chọn người chịu trách nhiệm và cách hiện trường được tạo ra. Một đáp án đúng vẫn cần đủ vật chứng để trở thành kết luận có cơ sở.", 16, MUTED))
	card.add_child(_label("Vật chứng đã ghi nhận: %d / %d" % [GameState.collected.size(), GameState.case_data.get("evidence", []).size()], 14, TEAL))
	_eyebrow(_modal_body, "01   NGƯỜI CHỊU TRÁCH NHIỆM", MUTED)
	var suspects := OptionButton.new()
	suspects.custom_minimum_size.y = 50
	suspects.add_item("Chọn người liên quan…")
	var suspect_data: Array = GameState.case_data.get("suspects", [])
	for suspect: Dictionary in suspect_data:
		suspects.add_item(str(suspect.get("name", "")))
	_modal_body.add_child(suspects)
	_eyebrow(_modal_body, "02   CƠ CHẾ GÂY RA HIỆN TƯỢNG", MUTED)
	var mechanisms := OptionButton.new()
	mechanisms.custom_minimum_size.y = 50
	mechanisms.clip_text = true
	mechanisms.add_item("Chọn giả thuyết…")
	var mechanism_data: Array = GameState.case_data.get("mechanisms", [])
	for mechanism: Dictionary in mechanism_data:
		mechanisms.add_item(str(mechanism.get("text", "")))
	_modal_body.add_child(mechanisms)
	var mechanism_detail := _label("", 14, MUTED)
	_modal_body.add_child(mechanism_detail)
	mechanisms.item_selected.connect(func(index: int) -> void:
		mechanism_detail.text = str(mechanism_data[index - 1].get("text", "")) if index > 0 else ""
	)
	var feedback := _label("Bạn có thể tiếp tục điều tra sau khi nhận đánh giá.", 13, MUTED)
	var submit := _button("GỬI KẾT LUẬN ĐIỀU TRA   →", func() -> void:
		if suspects.selected <= 0 or mechanisms.selected <= 0:
			feedback.text = "Hãy chọn cả người liên quan và cơ chế trước khi gửi."
			feedback.add_theme_color_override("font_color", RED)
			return
		var suspect_id: String = str(suspect_data[suspects.selected - 1].get("id", ""))
		var mechanism_id: String = str(mechanism_data[mechanisms.selected - 1].get("id", ""))
		_show_outcome(GameState.submit_conclusion(suspect_id, mechanism_id))
	, true)
	_modal_body.add_child(submit)
	_modal_body.add_child(feedback)


func _show_outcome(outcome: Dictionary) -> void:
	var status: String = str(outcome.get("status", "wrong"))
	_open_modal("Kết quả đối chiếu", "BIÊN BẢN ĐIỀU TRA   /   HỒ SƠ 307", "outcome")
	var color: Color = TEAL if status == "correct" else AMBER if status == "insufficient" else RED
	var stamp: String = "HỒ SƠ ĐÃ SÁNG TỎ" if status == "correct" else "CHƯA ĐỦ CĂN CỨ" if status == "insufficient" else "GIẢ THUYẾT BỊ BÁC BỎ"
	var card := _card(_modal_body)
	_eyebrow(card, stamp, color)
	card.add_child(_heading(str(outcome.get("title", stamp)), 37))
	card.add_child(_label(str(outcome.get("message", "Hãy đối chiếu lại hồ sơ.")), 18))
	if outcome.has("score"):
		card.add_child(_label("Độ hoàn thiện hồ sơ: %d / 100" % int(outcome.get("score", 0)), 14, color))
	if status == "insufficient":
		_modal_body.add_child(_label("Tiếp tục khám sát hiện trường để củng cố kết luận bằng vật chứng.", 15, MUTED))
	elif status == "wrong":
		_modal_body.add_child(_label("Xem lại lời khai, mốc thời gian và các nhận định đã ghi. Bạn có thể thử một kết luận khác.", 15, MUTED))
	else:
		_modal_body.add_child(_label("Bạn đã hoàn thành vụ án thử nghiệm ở giai đoạn 1. Có thể trở lại hiện trường để đọc lại vật chứng hoặc mở một hồ sơ mới.", 15, MUTED))
	_modal_body.add_child(_button("Trở lại hiện trường", show_hud, true))
	_modal_body.add_child(_button("Xem lại hồ sơ / thử kết luận khác", func() -> void: _open_journal("conclusion")))
	_modal_body.add_child(_button("Về màn hình chính", show_main_menu))


func _open_map() -> void:
	_open_modal("Sơ đồ khu nội trú", "BỆNH VIỆN AN TĨNH   /   TẦNG 03", "map")
	_modal_body.add_child(_label("Sơ đồ định hướng hiện trường. Các dấu vết chưa khám xét không được đánh dấu tự động.", 15, MUTED))
	var map := preload("res://scripts/ui/floor_map.gd").new()
	map.custom_minimum_size.y = 340
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(map)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 28)
	_modal_body.add_child(legend)
	legend.add_child(_label("●  Bạn đang ở đây", 13, AMBER, false))
	legend.add_child(_label("━━  Hành lang kết nối", 13, TEAL, false))
	_modal_body.add_child(_label("Phòng 307: phía đông, cuối hành lang. Phòng camera: phía tây, gần lối vào.\nM hoặc Escape để đóng sơ đồ.", 14, MUTED))


func _open_pause() -> void:
	_open_modal("Tạm nghỉ", "CUỘC ĐIỀU TRA ĐANG TIẾP DIỄN", "pause")
	_modal_body.add_child(_label("Tiến độ được lưu khi ghi nhận vật chứng và kết luận. Bạn cũng có thể lưu thủ công tại đây.", 15, MUTED))
	_modal_body.add_child(_button("Tiếp tục điều tra", show_hud, true))
	_modal_body.add_child(_button("Lưu tiến độ", func() -> void:
		if GameState.save_progress():
			_notify("Đã lưu tiến độ điều tra.")
	))
	_modal_body.add_child(_button("Thiết lập", func() -> void: _open_settings(false)))
	_modal_body.add_child(_button("Hướng dẫn điều khiển", _open_controls))
	_modal_body.add_child(_button("Lưu và về màn hình chính", func() -> void:
		GameState.save_progress()
		show_main_menu()
	))
	_modal_body.add_child(_button("Lưu và thoát", func() -> void:
		GameState.save_progress()
		exit_requested.emit()
	))


func _open_controls() -> void:
	_open_modal("Sổ tay điều tra viên", "HƯỚNG DẪN ĐIỀU KHIỂN", "controls")
	for entry: Array in [["W / A / S / D", "Di chuyển"], ["CHUỘT", "Quan sát xung quanh"], ["SHIFT / CTRL", "Chạy / cúi người"], ["E", "Khám xét vật chứng trước mặt"], ["F", "Bật / tắt đèn pin"], ["TAB", "Mở hồ sơ, lời khai và ghi chú"], ["M", "Mở sơ đồ bệnh viện"], ["F3", "Hiện / ẩn thông số hiệu năng"], ["ESC", "Đóng hồ sơ / tạm nghỉ"]]:
		var row := HBoxContainer.new()
		_modal_body.add_child(row)
		var key := _label(str(entry[0]), 14, AMBER, false)
		key.custom_minimum_size.x = 180
		row.add_child(key)
		row.add_child(_label(str(entry[1]), 15))
	_modal_body.add_child(HSeparator.new())
	_modal_body.add_child(_label("Hãy đọc mô tả cận cảnh trước khi chọn nhận định. Nhấn E chỉ mở vật chứng; bạn cần chọn nhận định có thể kiểm chứng để ghi vào hồ sơ.", 16, MUTED))
	_modal_body.add_child(_button("Bắt đầu quan sát", show_hud, true))


func _open_settings(from_menu: bool) -> void:
	_open_modal("Thiết lập", "HÌNH ẢNH   /   ĐIỀU KHIỂN   /   ÂM THANH", "settings", from_menu)
	_modal_body.add_child(_label("Thay đổi được áp dụng ngay và lưu trên máy này. Chọn mức Thấp nếu muốn ưu tiên tốc độ khung hình.", 15, MUTED))
	_eyebrow(_modal_body, "CHẤT LƯỢNG HÌNH ẢNH", TEAL)
	var quality := OptionButton.new()
	quality.custom_minimum_size.y = 50
	for name_text: String in ["Rất thấp · ưu tiên hiệu năng", "Thấp · tối ưu độ phân giải", "Trung bình · cân bằng", "Cao · độ nét và khử răng cưa"]:
		quality.add_item(name_text)
	quality.selected = clampi(Settings.quality, 0, 3)
	quality.item_selected.connect(func(index: int) -> void: Settings.set_quality(index))
	_modal_body.add_child(quality)
	_eyebrow(_modal_body, "GIỚI HẠN KHUNG HÌNH", MUTED)
	var caps: Array[int] = [30, 45, 60, 90]
	var fps := OptionButton.new()
	fps.custom_minimum_size.y = 50
	for cap: int in caps:
		fps.add_item("%d FPS" % cap)
	fps.selected = maxi(caps.find(Settings.fps_limit), 0)
	fps.item_selected.connect(func(index: int) -> void: Settings.set_fps_limit(caps[index]))
	_modal_body.add_child(fps)
	_eyebrow(_modal_body, "ĐỘ PHÂN GIẢI CỬA SỔ", MUTED)
	var sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
	var resolution := OptionButton.new()
	resolution.custom_minimum_size.y = 50
	for size: Vector2i in sizes:
		resolution.add_item("%d × %d" % [size.x, size.y])
	resolution.selected = maxi(sizes.find(Settings.resolution), 0)
	resolution.item_selected.connect(func(index: int) -> void: Settings.set_resolution(sizes[index]))
	_modal_body.add_child(resolution)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Toàn màn hình"
	fullscreen.button_pressed = Settings.fullscreen
	fullscreen.custom_minimum_size.y = 46
	fullscreen.toggled.connect(func(enabled: bool) -> void: Settings.set_fullscreen(enabled))
	_modal_body.add_child(fullscreen)
	_eyebrow(_modal_body, "ĐỘ NHẠY CHUỘT", TEAL)
	var sensitivity_label := _label("%.2f×" % (Settings.sensitivity / 0.0023), 14, MUTED)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0007
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = Settings.sensitivity
	sensitivity.custom_minimum_size.y = 30
	sensitivity.value_changed.connect(func(value: float) -> void:
		Settings.sensitivity = value
		Settings.apply()
		Settings.save_settings()
		sensitivity_label.text = "%.2f×" % (value / 0.0023)
	)
	_modal_body.add_child(sensitivity)
	_modal_body.add_child(sensitivity_label)
	_eyebrow(_modal_body, "ÂM LƯỢNG TỔNG", TEAL)
	var volume_label := _label("%d%%" % roundi(Settings.master_volume * 100.0), 14, MUTED)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = Settings.master_volume
	volume.custom_minimum_size.y = 30
	volume.value_changed.connect(func(value: float) -> void:
		Settings.master_volume = value
		Settings.apply()
		Settings.save_settings()
		volume_label.text = "%d%%" % roundi(value * 100.0)
	)
	_modal_body.add_child(volume)
	_modal_body.add_child(volume_label)
	_modal_body.add_child(_button("Xong", _close_modal, true))


func set_focus(text: String) -> void:
	_focus.text = "[ E ]   " + text
	_focus.visible = not text.is_empty()


func set_location(text: String) -> void:
	_location.text = text


func set_flashlight(value: bool) -> void:
	_flashlight.text = "F  ĐÈN PIN · " + ("BẬT" if value else "TẮT")
	_flashlight.add_theme_color_override("font_color", TEAL if value else MUTED)


func _update_hud() -> void:
	if not is_instance_valid(_evidence_count):
		return
	var count: int = GameState.collected.size()
	var total: int = GameState.case_data.get("evidence", []).size()
	_evidence_count.text = "%02d / %02d   DẤU VẾT" % [count, total]
	if count == 0:
		_task.text = "Khám sát hiện trường · E để quan sát vật chứng"
	elif count < total:
		_task.text = "Đối chiếu dấu vết · TAB để mở hồ sơ"
	else:
		_task.text = "Vật chứng đã đầy đủ · Mở TAB → Kết luận"


func _notify(message: String) -> void:
	if not is_instance_valid(_toast):
		return
	_toast.text = message
	_toast_left = 4.5
	_toast.show()
	_root.move_child(_toast, _root.get_child_count() - 1)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.hide()
	_metrics_elapsed += delta
	if _metrics_elapsed >= 0.5:
		_metrics_elapsed = 0.0
		var fps: float = Performance.get_monitor(Performance.TIME_FPS)
		var memory_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_metrics.text = "%d FPS · %.1f ms\nBộ nhớ engine %.0f MB · %d lệnh vẽ" % [int(fps), 1000.0 / maxf(fps, 1.0), memory_mb, draw_calls]


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F3:
		_metrics.visible = not _metrics.visible
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if _modal_kind == "menu":
			return
		if modal_open:
			_close_modal()
		elif GameState.session_active:
			_open_pause()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB and GameState.session_active and not _menu.visible:
		if _modal_kind == "journal":
			_close_modal()
		elif not modal_open:
			_open_journal(_journal_section)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M and GameState.session_active and not _menu.visible:
		if _modal_kind == "map":
			_close_modal()
		elif not modal_open:
			_open_map()
		get_viewport().set_input_as_handled()
