package vn.apktachgoc

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/** APK operation metadata only. Never accepts a signing identity or password. */
object HistoryStore {
    private const val KEEP = 50
    private const val MAX_BYTES = 786432
    private fun folder(context: Context) = File(context.noBackupFilesDir, "history").apply { mkdirs() }
    private fun file(context: Context, id: String): AtomicFile {
        require(Regex("[0-9a-f-]{36}").matches(id)) { "Mã lịch sử không hợp lệ." }
        return AtomicFile(File(folder(context), "$id.json"))
    }
    @Synchronized fun begin(context: Context, operation: String, inputName: String = "", target: String = ""): String {
        val id = UUID.randomUUID().toString()
        val data = JSONObject().put("id", id).put("created", System.currentTimeMillis()).put("operation", operation)
            .put("status", "RUNNING").put("phase", "Chuẩn bị").put("percent", 0).put("inputName", inputName.take(300)).put("target", target.take(200))
            .put("toolVersion", context.packageManager.getPackageInfo(context.packageName, 0).versionName)
            .put("device", "${Build.MANUFACTURER} ${Build.MODEL}").put("android", "${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
            .put("abis", Build.SUPPORTED_ABIS.joinToString()).put("heapMb", context.getSystemService(ActivityManager::class.java).memoryClass)
            .put("events", JSONArray())
        write(context, data)
        list(context).drop(KEEP).forEach { file(context, it.getString("id")).delete() }
        return id
    }
    @Synchronized fun update(context: Context, id: String, fields: Map<String, Any>) {
        val data = read(context, id) ?: error("Không tìm thấy báo cáo $id.")
        fields.forEach { (key, value) -> data.put(key, if (value is String) value.take(110000) else value) }
        write(context, data)
    }
    @Synchronized fun step(context: Context, id: String, percent: Int, phase: String) {
        val data = read(context, id) ?: error("Không tìm thấy báo cáo $id.")
        val previous = data.optJSONArray("events") ?: JSONArray()
        val next = JSONArray()
        for (i in maxOf(0, previous.length() - 99) until previous.length()) next.put(previous.get(i))
        next.put(JSONObject().put("elapsed", System.currentTimeMillis() - data.getLong("created")).put("percent", percent).put("phase", phase.take(400)))
        data.put("events", next).put("percent", percent).put("phase", phase.take(400))
        write(context, data)
    }
    @Synchronized fun read(context: Context, id: String): JSONObject? = try {
        file(context, id).openRead().use { input ->
            val out = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) { val n = input.read(buffer); if (n < 0) break; require(out.size() + n <= MAX_BYTES); out.write(buffer, 0, n) }
            JSONObject(out.toString("UTF-8"))
        }
    } catch (_: Exception) { null }
    @Synchronized fun list(context: Context): List<JSONObject> = folder(context).listFiles().orEmpty()
        .map { it.name.removeSuffix(".bak").removeSuffix(".new") }.distinct()
        .filter { Regex("[0-9a-f-]{36}\\.json").matches(it) }
        .mapNotNull { read(context, it.removeSuffix(".json")) }.sortedByDescending { it.optLong("created") }
    private fun write(context: Context, data: JSONObject) {
        val bytes = data.toString().toByteArray(Charsets.UTF_8)
        require(bytes.size <= MAX_BYTES) { "Báo cáo vượt giới hạn lưu trữ." }
        val atomic = file(context, data.getString("id"))
        val stream = atomic.startWrite()
        try { stream.write(bytes); atomic.finishWrite(stream) }
        catch (e: Exception) { atomic.failWrite(stream); throw e }
    }
    private fun status(data: JSONObject) = when (data.optString("status")) {
        "SUCCESS" -> "Hoàn tất"; "CHECKED" -> "Đã quét: ${data.optInt("auditErrors")} lỗi chặn"; "FAILED" -> "Thất bại"; "TIMEOUT" -> "Bị Android dừng"; else -> "Chưa hoàn tất / đang xử lý"
    }
    private fun operation(data: JSONObject) = when (data.optString("operation")) {
        "INSPECT" -> "Đọc APK"; "AUDIT" -> "Kiểm tra toàn bộ"; "CLONE" -> "Tách gốc"; "RESIGN" -> "Ký lại"; else -> data.optString("operation")
    }
    fun summary(data: JSONObject): String = "${SimpleDateFormat("dd/MM HH:mm:ss", Locale.getDefault()).format(Date(data.optLong("created")))} • ${operation(data)} • ${status(data)}\n${data.optString("inputName").ifBlank { data.optString("package", "APK chưa rõ") }}"
    fun text(data: JSONObject): String = buildString {
        append("BÁO CÁO APK TÁCH GỐC ${data.optString("toolVersion")}\n")
        append("Mã phiên: ${data.optString("id")}\nThời gian: ${SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.ROOT).format(Date(data.optLong("created")))}\n")
        append("Thao tác: ${operation(data)}\nTrạng thái: ${status(data)}\nGiai đoạn cuối: ${data.optString("phase")} (${data.optInt("percent")}%)\n")
        append("\nAPK nguồn: ${data.optString("inputName", "chưa rõ")}\nTên ứng dụng: ${data.optString("appName", "chưa đọc được")}\nPackage: ${data.optString("package", "chưa đọc được")}\nPhiên bản: ${data.optString("version", "chưa đọc được")}\n")
        append("Kích thước: ${data.optLong("inputBytes")} byte\nSHA-256 nguồn: ${data.optString("inputSha256", "chưa tính được")}\nPackage đích: ${data.optString("target", "không áp dụng")}\n")
        append("\nMáy: ${data.optString("device")}\nAndroid: ${data.optString("android")}\nABI máy: ${data.optString("abis")}\nGiới hạn heap báo bởi Android: ${data.optInt("heapMb")} MB\n")
        if (data.has("error")) append("\nLỖI / PHẦN CẦN XỬ LÝ\n${data.optString("error")}\n${data.optString("exception")}\n")
        if (data.has("diagnostics")) append("\nKHẢO SÁT CẤU TRÚC APK\n${data.optString("diagnostics")}\n")
        if (data.has("audit")) append("\n${data.optString("audit")}\n")
        if (data.has("outputSha256")) append("\nKẾT QUẢ ĐÃ KIỂM TRA CẤU TRÚC / CHỮ KÝ\nPackage: ${data.optString("target")}\nSHA-256 APK: ${data.optString("outputSha256")}\n${data.optString("changes")}\nChưa xác nhận ứng dụng đích chạy được.\n")
        append("\nCÁC BƯỚC XỬ LÝ (tối đa 100 mốc gần nhất)\n")
        val events = data.optJSONArray("events") ?: JSONArray()
        for (i in 0 until events.length()) {
            val e = events.getJSONObject(i)
            append("+${e.optLong("elapsed") / 1000}s ${e.optInt("percent")}% ${e.optString("phase")}\n")
        }
        append("\nBáo cáo chỉ lưu cấu trúc APK và kết quả xử lý, không ghi khóa ký riêng, mật khẩu hoặc phiên đăng nhập. Lịch sử lưu tối đa 50 phiên trên máy; không tự gửi. APK đầu vào được giữ nguyên.\n")
    }
}
