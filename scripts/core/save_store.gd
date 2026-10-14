extends RefCounted
## JSON-only persistence. No object deserialization and no credentials in save files.

const MAX_SAVE_BYTES: int = 262144


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Chưa có bản lưu."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Không thể mở bản lưu."}
	var length: int = file.get_length()
	if length <= 0 or length > MAX_SAVE_BYTES:
		file.close()
		return {"ok": false, "error": "Kích thước bản lưu không hợp lệ."}
	var source: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(source) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "Bản lưu không phải JSON hợp lệ."}
	return {"ok": true, "data": parser.data}


static func write_json_atomic(path: String, data: Dictionary) -> Dictionary:
	var serialized: String = JSON.stringify(data, "\t", true, true)
	if serialized.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return {"ok": false, "error": "Bản lưu vượt giới hạn dung lượng."}
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Không thể tạo bản lưu tạm; bản cũ được giữ lại."}
	file.store_string(serialized)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"ok": false, "error": "Ghi bản lưu thất bại; bản cũ được giữ lại."}
	var verification: Dictionary = read_json(temporary)
	# JSON numbers are parsed as doubles; dictionary equality would incorrectly
	# reject valid integer fields (e.g. schema version). Verify the exact written
	# representation and successful parsing instead of comparing Variant types.
	if not verification.get("ok", false) or FileAccess.get_file_as_string(temporary) != serialized:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"ok": false, "error": "Không xác minh được bản lưu tạm; bản cũ được giữ lại."}
	# Same-directory rename replaces the destination only after the complete file is ready.
	# This protects against interrupted writes; it is not a guarantee against disk failure.
	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"ok": false, "error": "Không thể thay thế bản lưu; bản cũ được giữ lại."}
	return {"ok": true}
