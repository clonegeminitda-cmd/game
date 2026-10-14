extends Node
## Single owner of case progress. World objects and UI send commands here.
## Future online sessions must validate these commands on the authoritative host.

signal changed()
signal clue_collected(evidence_id: String)
signal notification(message: String)

const SaveStore = preload("res://scripts/core/save_store.gd")
const CASE_PATH: String = "res://data/cases/room_307.json"
const SAVE_PATH: String = "user://case_307_save.json"
const SAVE_VERSION: int = 1
const MAX_NOTES_LENGTH: int = 16000
const MAX_ELAPSED_SECONDS: float = 604800.0
const SPAWN_POSITION := Vector3(0.0, 0.1, 8.0)

var case_data: Dictionary = {}
var collected: Dictionary = {}
var notes: String = ""
var elapsed_seconds: float = 0.0
var session_active: bool = false
var outcome: Dictionary = {}
var player_position: Vector3 = SPAWN_POSITION
var player_yaw: float = 0.0
var last_error: String = ""
var _case_ready: bool = false


func _ready() -> void:
	var file := FileAccess.open(CASE_PATH, FileAccess.READ)
	if file == null:
		_fail("Không thể mở dữ liệu vụ án.")
		return
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		_fail("Dữ liệu vụ án không phải JSON hợp lệ.")
		return
	var candidate: Dictionary = parser.data
	var errors: Array[String] = validate_case(candidate)
	if not errors.is_empty():
		_fail("Dữ liệu vụ án không hợp lệ: " + "; ".join(errors))
		return
	case_data = candidate
	_case_ready = true


func _process(delta: float) -> void:
	if session_active:
		elapsed_seconds = minf(elapsed_seconds + delta, MAX_ELAPSED_SECONDS)


func start_new() -> void:
	if not _case_ready:
		_fail("Vụ án chưa sẵn sàng; hãy kiểm tra dữ liệu cài đặt.")
		return
	collected.clear()
	notes = ""
	elapsed_seconds = 0.0
	outcome.clear()
	player_position = SPAWN_POSITION
	player_yaw = 0.0
	session_active = true
	last_error = ""
	changed.emit()


func get_evidence(id: String) -> Dictionary:
	for item in case_data.get("evidence", []):
		if item["id"] == id:
			return item.duplicate(true)
	return {}


func has_evidence(id: String) -> bool:
	return collected.has(id)


func collect_evidence(id: String, observation_id: String) -> Dictionary:
	if not session_active:
		return {"ok": false, "message": "Hãy bắt đầu một phiên điều tra trước."}
	var evidence: Dictionary = get_evidence(id)
	if evidence.is_empty():
		return {"ok": false, "message": "Không tìm thấy vật chứng trong hồ sơ."}
	if collected.has(id):
		return {"ok": false, "message": "Vật chứng đã được ghi nhận; bạn vẫn có thể xem lại."}
	if observation_id != evidence["correct_observation"]:
		return {"ok": false, "message": "Nhận định chưa được dữ kiện hỗ trợ. Đọc lại chi tiết và phân biệt quan sát với suy đoán."}
	collected[id] = {
		"evidence_id": id,
		"observation_id": observation_id,
		"collector": "Điều tra viên",
		"collected_at": elapsed_seconds,
		"method": evidence["method"]
	}
	# A new piece of evidence invalidates the previous assessment, allowing a fresh report.
	outcome.clear()
	clue_collected.emit(id)
	changed.emit()
	var message: String = "Đã ghi nhận: " + str(evidence["title"])
	notification.emit(message)
	return {"ok": true, "message": message}


func submit_conclusion(suspect_id: String, mechanism_id: String) -> Dictionary:
	if not session_active or not _case_ready:
		return {"ok": false, "status": "invalid", "title": "Chưa có phiên điều tra", "message": "Hãy bắt đầu hoặc tiếp tục một vụ án."}
	if not _contains_id(case_data["suspects"], suspect_id) or not _contains_id(case_data["mechanisms"], mechanism_id):
		return {"ok": false, "status": "invalid", "title": "Thiếu lựa chọn", "message": "Hãy chọn một nghi phạm và một cơ chế hợp lệ."}
	outcome = _assess_conclusion(suspect_id, mechanism_id, collected)
	changed.emit()
	return outcome.duplicate(true)


func _assess_conclusion(suspect_id: String, mechanism_id: String, evidence_records: Dictionary) -> Dictionary:
	var solution: Dictionary = case_data["solution"]
	var missing: Array[String] = []
	for id in solution["required_evidence"]:
		if not evidence_records.has(id):
			missing.append(id)
	var correct: bool = suspect_id == solution["suspect_id"] and mechanism_id == solution["mechanism_id"]
	var evidence_fraction: float = float(solution["required_evidence"].size() - missing.size()) / float(solution["required_evidence"].size())
	var status: String = "wrong"
	var title: String = "Kết luận chưa đúng"
	var message: String = "Giả thuyết chưa giải thích đồng thời người liên quan, camera, cửa chốt và tiếng gõ. Hãy đối chiếu lại; bạn có thể điều tra và nộp lại mà không mất tiến độ."
	var score: int = roundi(20.0 * evidence_fraction)
	if correct and missing.is_empty():
		status = "correct"
		title = "Hồ sơ đã được làm sáng tỏ"
		message = "Sáu nguồn dữ kiện hỗ trợ kết luận: Huy tạo khoảng trống camera, dàn dựng cửa chốt và dùng T-04 tạo tiếng gõ lúc 23:39. Báo cáo ước tính tử vong 23:16–23:22; tiếng gõ không chứng minh Lan còn sống. Động cơ trong hồ sơ là che giấu hóa đơn sửa chữa trùng. Bạn có thể tiếp tục xem lại hiện trường."
		score = 100
	elif correct:
		status = "insufficient"
		title = "Đúng hướng, thiếu chứng cứ"
		message = "Người liên quan và cơ chế phù hợp lời giải, nhưng hồ sơ còn thiếu %d nguồn dữ kiện. Hãy hoàn tất kiểm tra rồi nộp lại." % missing.size()
		score = roundi(60.0 + 40.0 * evidence_fraction)
	return {
		"ok": true, "status": status, "title": title, "message": message,
		"suspect_id": suspect_id, "mechanism_id": mechanism_id,
		"missing_evidence": missing, "score": score
	}


func get_hint() -> String:
	if not _case_ready:
		return "Dữ liệu vụ án chưa sẵn sàng."
	var evidence_list: Array = case_data["evidence"]
	var hints: Array = case_data["hints"]
	for index in range(evidence_list.size()):
		if not collected.has(evidence_list[index]["id"]):
			return hints[mini(index, hints.size() - 1)]
	return hints.back()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_progress() -> bool:
	if not session_active or not _case_ready:
		return _fail("Chưa có phiên điều tra để lưu.")
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"case_id": case_data["id"],
		"collected": collected.duplicate(true),
		"notes": notes,
		"elapsed_seconds": elapsed_seconds,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"player_yaw": player_yaw,
		"conclusion": {} if outcome.is_empty() else {
			"suspect_id": outcome.get("suspect_id", ""),
			"mechanism_id": outcome.get("mechanism_id", "")
		}
	}
	var errors: Array[String] = validate_save(payload)
	if not errors.is_empty():
		return _fail("Không lưu dữ liệu không hợp lệ: " + "; ".join(errors))
	var result: Dictionary = SaveStore.write_json_atomic(SAVE_PATH, payload)
	if not result["ok"]:
		return _fail(result["error"])
	last_error = ""
	notification.emit("Đã lưu tiến độ điều tra.")
	return true


func load_progress() -> bool:
	if not _case_ready:
		return _fail("Vụ án chưa sẵn sàng để tải bản lưu.")
	var result: Dictionary = SaveStore.read_json(SAVE_PATH)
	if not result["ok"]:
		return _fail(result["error"])
	var payload: Dictionary = result["data"]
	var errors: Array[String] = validate_save(payload)
	if not errors.is_empty():
		return _fail("Bản lưu không hợp lệ; phiên hiện tại được giữ nguyên. " + "; ".join(errors))
	# Commit only after the entire candidate has passed validation.
	var position: Array = payload["player_position"]
	var candidate_outcome: Dictionary = {}
	var conclusion: Dictionary = payload["conclusion"]
	if not conclusion.is_empty():
		candidate_outcome = _assess_conclusion(conclusion["suspect_id"], conclusion["mechanism_id"], payload["collected"])
	collected = payload["collected"].duplicate(true)
	notes = payload["notes"]
	elapsed_seconds = float(payload["elapsed_seconds"])
	player_position = Vector3(float(position[0]), float(position[1]), float(position[2]))
	player_yaw = float(payload["player_yaw"])
	outcome = candidate_outcome
	session_active = true
	last_error = ""
	changed.emit()
	notification.emit("Đã khôi phục tiến độ điều tra.")
	return true


func validate_save(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _exact_keys(data, ["version", "case_id", "collected", "notes", "elapsed_seconds", "player_position", "player_yaw", "conclusion"]):
		errors.append("Cấu trúc bản lưu có trường thiếu hoặc không được hỗ trợ.")
		return errors
	if not _number(data["version"]) or float(data["version"]) != float(SAVE_VERSION):
		errors.append("Phiên bản bản lưu không được hỗ trợ.")
	if not data["case_id"] is String or data["case_id"] != case_data.get("id", ""):
		errors.append("Bản lưu thuộc vụ án khác.")
	if not data["notes"] is String or str(data["notes"]).length() > MAX_NOTES_LENGTH:
		errors.append("Ghi chú không hợp lệ hoặc quá dài.")
	var valid_elapsed: bool = _bounded_number(data["elapsed_seconds"], 0.0, MAX_ELAPSED_SECONDS)
	if not valid_elapsed:
		errors.append("Thời gian điều tra không hợp lệ.")
	if not _bounded_number(data["player_yaw"], -1000000.0, 1000000.0):
		errors.append("Hướng nhìn không hợp lệ.")
	if not _valid_position(data["player_position"]):
		errors.append("Vị trí người chơi nằm ngoài khu vực prototype.")
	if not data["collected"] is Dictionary:
		errors.append("Danh sách vật chứng không hợp lệ.")
	else:
		var records: Dictionary = data["collected"]
		for id in records:
			if not id is String:
				errors.append("Mã vật chứng phải là chuỗi.")
				continue
			var evidence: Dictionary = get_evidence(id)
			if evidence.is_empty():
				errors.append("Bản lưu chứa vật chứng không được hỗ trợ: " + id)
				continue
			if not records[id] is Dictionary:
				errors.append("Bản ghi vật chứng không hợp lệ: " + id)
				continue
			var record: Dictionary = records[id]
			if not _exact_keys(record, ["evidence_id", "observation_id", "collector", "collected_at", "method"]):
				errors.append("Bản ghi vật chứng có trường thiếu hoặc không được hỗ trợ: " + id)
				continue
			if record["evidence_id"] != id or record["observation_id"] != evidence["correct_observation"] or record["method"] != evidence["method"]:
				errors.append("Nội dung quan sát không hợp lệ: " + id)
			if record["collector"] != "Điều tra viên":
				errors.append("Người thu thập không thuộc phiên chơi đơn.")
			if not valid_elapsed or not _bounded_number(record["collected_at"], 0.0, float(data["elapsed_seconds"]) if valid_elapsed else 0.0):
				errors.append("Mốc thu thập không hợp lệ: " + id)
	if not data["conclusion"] is Dictionary:
		errors.append("Kết luận không hợp lệ.")
	else:
		var conclusion: Dictionary = data["conclusion"]
		if not conclusion.is_empty():
			if not _exact_keys(conclusion, ["suspect_id", "mechanism_id"]):
				errors.append("Cấu trúc kết luận không hợp lệ.")
			elif not _contains_id(case_data.get("suspects", []), conclusion["suspect_id"]) or not _contains_id(case_data.get("mechanisms", []), conclusion["mechanism_id"]):
				errors.append("Kết luận có nghi phạm hoặc cơ chế không được hỗ trợ.")
	return errors


func validate_case(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in ["id", "title", "subtitle", "briefing"]:
		if not _text(data.get(field)):
			errors.append("Thiếu chuỗi văn bản vụ án: " + field)
	if not _identifier(data.get("id")):
		errors.append("Mã vụ án không hợp lệ.")
	for field in ["evidence", "suspects", "mechanisms", "timeline", "hints"]:
		if not data.get(field) is Array or data.get(field, []).is_empty():
			errors.append("Danh sách thiếu hoặc rỗng: " + field)
	if not data.get("solution") is Dictionary:
		errors.append("Thiếu lời giải chính thức.")
	if not errors.is_empty():
		return errors
	var evidence_ids: Dictionary = {}
	for raw in data["evidence"]:
		if not raw is Dictionary:
			errors.append("Vật chứng phải là đối tượng.")
			continue
		var item: Dictionary = raw
		_register_id(item, evidence_ids, "vật chứng", errors)
		for field in ["title", "location", "description", "detail", "method", "correct_observation", "analysis"]:
			if not _text(item.get(field)):
				errors.append("Thiếu trường vật chứng: " + field)
		if not item.get("observations") is Array or item.get("observations", []).size() < 2:
			errors.append("Mỗi vật chứng cần ít nhất hai nhận định.")
		else:
			var observation_ids: Dictionary = {}
			for observation in item["observations"]:
				if not observation is Dictionary:
					errors.append("Nhận định không hợp lệ.")
					continue
				_register_id(observation, observation_ids, "nhận định", errors)
				if not _text(observation.get("text")):
					errors.append("Nhận định thiếu nội dung.")
			if not observation_ids.has(item.get("correct_observation")):
				errors.append("Đáp án quan sát không nằm trong các nhận định.")
	var suspect_ids: Dictionary = {}
	for item in data["suspects"]:
		if not item is Dictionary:
			errors.append("Nghi phạm không hợp lệ.")
			continue
		_register_id(item, suspect_ids, "nghi phạm", errors)
		if not _text(item.get("name")) or not _text(item.get("statement")):
			errors.append("Nghi phạm thiếu tên hoặc lời khai.")
	var mechanism_ids: Dictionary = {}
	for item in data["mechanisms"]:
		if not item is Dictionary:
			errors.append("Cơ chế không hợp lệ.")
			continue
		_register_id(item, mechanism_ids, "cơ chế", errors)
		if not _text(item.get("text")):
			errors.append("Cơ chế thiếu mô tả.")
	var solution: Dictionary = data["solution"]
	if not suspect_ids.has(solution.get("suspect_id")) or not mechanism_ids.has(solution.get("mechanism_id")):
		errors.append("Lời giải tham chiếu nghi phạm hoặc cơ chế không tồn tại.")
	if not solution.get("required_evidence") is Array or solution.get("required_evidence", []).is_empty():
		errors.append("Lời giải phải yêu cầu chứng cứ.")
	else:
		_check_references(solution["required_evidence"], evidence_ids, "lời giải", errors)
	for item in data["evidence"]:
		if item is Dictionary and item.has("related_evidence"):
			if not item["related_evidence"] is Array:
				errors.append("Quan hệ vật chứng phải là danh sách.")
			else:
				_check_references(item["related_evidence"], evidence_ids, "quan hệ vật chứng", errors)
	for event in data["timeline"]:
		if not event is Dictionary or not _text(event.get("time")) or not _text(event.get("event")):
			errors.append("Mốc thời gian không hợp lệ.")
		elif event.has("requires"):
			if not event["requires"] is Array:
				errors.append("Điều kiện mốc thời gian phải là danh sách.")
			else:
				_check_references(event["requires"], evidence_ids, "mốc thời gian", errors)
	for hint in data["hints"]:
		if not _text(hint):
			errors.append("Gợi ý không hợp lệ.")
	return errors


func _register_id(item: Dictionary, known: Dictionary, label: String, errors: Array[String]) -> void:
	var id: Variant = item.get("id")
	if not _identifier(id):
		errors.append("Mã " + label + " không hợp lệ.")
	elif known.has(id):
		errors.append("Mã " + label + " bị trùng: " + str(id))
	else:
		known[id] = true


func _check_references(ids: Array, known: Dictionary, label: String, errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for id in ids:
		if not id is String or not known.has(id):
			errors.append("Tham chiếu không tồn tại trong " + label + ".")
		elif seen.has(id):
			errors.append("Tham chiếu bị trùng trong " + label + ".")
		else:
			seen[id] = true


func _contains_id(items: Array, id: Variant) -> bool:
	if not id is String:
		return false
	for item in items:
		if item is Dictionary and item.get("id") == id:
			return true
	return false


func _identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64:
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return false
	return true


func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 16000


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _bounded_number(value: Variant, lower: float, upper: float) -> bool:
	return _number(value) and float(value) >= lower and float(value) <= upper


func _exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


func _valid_position(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not _number(component):
			return false
	var x: float = float(value[0])
	var y: float = float(value[1])
	var z: float = float(value[2])
	if y < -0.25 or y > 3.0:
		return false
	var corridor: bool = x >= -2.8 and x <= 2.8 and z >= -14.0 and z <= 12.0
	var room: bool = x >= 2.6 and x <= 11.0 and z >= -10.0 and z <= -2.0
	var control: bool = x >= -10.0 and x <= -2.6 and z >= -1.0 and z <= 7.0
	return corridor or room or control


func _fail(message: String) -> bool:
	last_error = message
	notification.emit(message)
	return false
