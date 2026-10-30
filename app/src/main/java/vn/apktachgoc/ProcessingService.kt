package vn.apktachgoc

import android.app.*
import android.content.*
import android.net.Uri
import android.os.*
import android.content.pm.ServiceInfo
import android.provider.OpenableColumns
import androidx.core.app.NotificationCompat
import vn.apktachgoc.core.*
import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors

data class AppSnapshot(val busy: Boolean = false, val percent: Int = 0, val status: String = "Chọn APK để bắt đầu", val error: String? = null,
    val source: File? = null, val name: String = "", val info: ApkInfo? = null, val report: BuildReport? = null,
    val inputName: String = "", val inputSha256: String = "", val diagnostics: String = "", val historyWarning: String? = null,
    val activeHistoryId: String? = null, val auditDetails: String = "")
object AppState {
    @Volatile var snapshot = AppSnapshot(); private set
    val listeners = CopyOnWriteArrayList<(AppSnapshot) -> Unit>()
    fun update(change: (AppSnapshot) -> AppSnapshot) {
        synchronized(this) { snapshot = change(snapshot) }
        Handler(Looper.getMainLooper()).post { val state = snapshot; listeners.forEach { it(state) } }
    }
}
class ProcessingService : Service() {
    private val worker = Executors.newSingleThreadExecutor()
    private var wakeLock: PowerManager.WakeLock? = null
    private var historyId: String? = null
    @Volatile private var timedOut = false
    private fun record(fields: Map<String, Any>) {
        val id = historyId ?: return
        try { HistoryStore.update(this, id, fields) }
        catch (e: Exception) { AppState.update { it.copy(historyWarning = "Không lưu được lịch sử: ${e.message}") } }
    }
    private fun recordFailure(error: String, exception: Throwable? = null) {
        val detail = exception?.let { e ->
            buildString { var cause: Throwable? = e; var depth = 0
                while (cause != null && depth++ < 5) { append("${cause.javaClass.name}: ${cause.message}\n"); cause.stackTrace.take(10).forEach { append("  $it\n") }; cause = cause.cause }
            }.take(6000)
        }.orEmpty()
        record(mapOf("status" to if (timedOut) "TIMEOUT" else "FAILED", "error" to error.take(6000), "exception" to detail))
    }
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("processing", "Xử lý APK", NotificationManager.IMPORTANCE_LOW))
    }
    private fun notification(percent: Int, text: String) = NotificationCompat.Builder(this, "processing")
        .setSmallIcon(R.drawable.ic_app).setContentTitle("APK Tách Gốc").setContentText(text).setOngoing(true)
        .setProgress(100, percent, percent == 0).setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)).build()
    private fun progress(percent: Int, text: String) {
        check(!timedOut) { "Android đã giới hạn thời gian xử lý; chưa có APK mới được công bố." }
        historyId?.let { id -> try { HistoryStore.step(this, id, percent, text) } catch (e: Exception) { AppState.update { it.copy(historyWarning = "Không lưu được tiến trình: ${e.message}") } } }
        AppState.update { it.copy(percent = percent, status = text) }
        getSystemService(NotificationManager::class.java).notify(7, notification(percent, text))
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) { stopSelf(startId); return START_NOT_STICKY }
        if (AppState.snapshot.busy) return START_NOT_STICKY
        timedOut = false; historyId = null
        ResultStore.clear(this)
        AppState.update { it.copy(busy = true, percent = 0, error = null, report = null, historyWarning = null, activeHistoryId = null, auditDetails = "") }
        if (Build.VERSION.SDK_INT >= 29) startForeground(7, notification(0, "Đang chuẩn bị"), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(7, notification(0, "Đang chuẩn bị"))
        wakeLock = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "apktachgoc:processing").apply { acquire(30 * 60 * 1000L) }
        worker.execute {
            try {
                val operation = if (intent.action == "BUILD") intent.getStringExtra("mode") ?: "RESIGN" else intent.action ?: "UNKNOWN"
                val inputName = if (intent.action == "INSPECT") displayName(Uri.parse(intent.getStringExtra("uri"))) else AppState.snapshot.inputName
                try {
                    val id = HistoryStore.begin(this, operation, inputName, intent.getStringExtra("package").orEmpty())
                    historyId = id
                    AppState.update { it.copy(activeHistoryId = id) }
                }
                catch (e: Exception) { AppState.update { it.copy(historyWarning = "Không tạo được lịch sử: ${e.message}") } }
                when (intent.action) {
                    "INSPECT" -> inspect(Uri.parse(intent.getStringExtra("uri")))
                    "BUILD" -> build(intent)
                    "AUDIT" -> audit(intent, false)
                    else -> error("Lệnh xử lý không hợp lệ.")
                }
                if (intent.action != "AUDIT") record(mapOf("status" to "SUCCESS"))
            } catch (e: OutOfMemoryError) {
                recordFailure("Không đủ RAM để hoàn tất toàn bộ phần kiểm tra/xử lý. Xem tiến trình cuối; các phần sau chưa được kiểm tra.")
                AppState.update { it.copy(error = "Không đủ RAM để xử lý APK này. Hãy chọn APK nhỏ hơn.", status = "Chưa tạo APK") }
            } catch (e: Exception) {
                recordFailure(e.message ?: e.javaClass.simpleName, e)
                AppState.update { it.copy(error = e.message ?: e.javaClass.simpleName, status = "Chưa tạo APK") }
            } finally {
                AppState.update { it.copy(busy = false) }
                if (wakeLock?.isHeld == true) wakeLock?.release()
                stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(startId)
            }
        }
        return START_NOT_STICKY
    }
    private fun displayName(uri: Uri): String = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
            ?: uri.lastPathSegment?.substringAfterLast('/') ?: "APK chưa rõ tên"
    } catch (_: Exception) { uri.lastPathSegment?.substringAfterLast('/') ?: "APK chưa rõ tên" }
    private fun recordInput() {
        val state = AppState.snapshot
        val fields = mutableMapOf<String, Any>("inputName" to state.inputName, "appName" to state.name, "inputSha256" to state.inputSha256, "diagnostics" to state.diagnostics)
        state.source?.let { fields["inputBytes"] = it.length() }
        state.info?.let { fields["package"] = it.packageName; fields["version"] = "${it.versionName} (${it.versionCode})" }
        record(fields)
    }
    private fun inspect(uri: Uri) {
        val inputName = displayName(uri)
        AppState.update { AppSnapshot(busy = true, status = "Sao chép APK vào vùng làm việc", inputName = inputName, historyWarning = it.historyWarning, activeHistoryId = it.activeHistoryId) }
        val dir = File(filesDir, "input").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val file = File(dir, "selected.apk")
        try {
            contentResolver.openInputStream(uri).use { input ->
                requireNotNull(input) { "Không mở được tệp đã chọn." }
                file.outputStream().use { out ->
                    val bytes = ByteArray(65536); var total = 0L
                    while (true) { val size = input.read(bytes); if (size < 0) break; total += size; require(total <= 512L * 1024 * 1024) { "Tệp lớn hơn 512 MB." }; out.write(bytes, 0, size) }
                }
            }
            AppState.update { it.copy(source = file) }
            progress(55, "Tính SHA-256 và khảo sát cấu trúc APK")
            val hash = ApkEngine.sha256(file)
            val diagnostics = ApkDiagnostics.describe(file)
            AppState.update { it.copy(inputSha256 = hash, diagnostics = diagnostics) }
            recordInput()
            progress(85, "Đọc manifest và nhận diện split APK")
            val info = ApkEngine.inspect(file)
            val archive = packageManager.getPackageArchiveInfo(file.path, 0)
            archive?.applicationInfo?.apply { sourceDir = file.path; publicSourceDir = file.path }
            val name = runCatching { archive?.applicationInfo?.loadLabel(packageManager)?.toString() }.getOrNull() ?: info.packageName
            AppState.update { it.copy(source = file, info = info, name = name, percent = 100, status = "Đã đọc APK • ${(file.length() / 1048576.0).let { n -> "%.1f".format(n) }} MB") }
            recordInput()
            progress(100, "Đã đọc APK; có thể kiểm tra toàn bộ trước khi tạo")
        } catch (e: Throwable) { if (AppState.snapshot.source == null) file.delete(); throw e }
    }
    private fun audit(intent: Intent, beforeBuild: Boolean): AuditReport {
        val state = AppState.snapshot
        val input = state.source ?: error("Chưa có tệp APK để kiểm tra.")
        recordInput()
        val mode = Mode.valueOf(intent.getStringExtra("mode") ?: "CLONE")
        val target = if (mode == Mode.RESIGN) state.info?.packageName.orEmpty() else intent.getStringExtra("package").orEmpty()
        record(mapOf("target" to target))
        val report = ApkAudit.scan(input, mode, target, intent.getStringExtra("label").orEmpty()) { percent, phase -> progress(if (beforeBuild) percent * 45 / 100 else percent, phase) }
        record(mapOf("audit" to report.text(), "auditErrors" to report.errors, "auditWarnings" to report.warnings))
        val blockers = report.issues.filter { !it.warning }.take(8)
        val details = blockers.mapIndexed { index, issue -> "${index + 1}. [${issue.location}] ${issue.message}" }.joinToString("\n") +
            if (report.errors > blockers.size) "\nCòn ${report.errors - blockers.size} lỗi; sao chép báo cáo để xem toàn bộ chi tiết được lưu." else ""
        AppState.update { it.copy(auditDetails = details) }
        if (!beforeBuild) {
            record(mapOf("status" to "CHECKED"))
            AppState.update { it.copy(status = "Đã kiểm tra: ${report.errors} lỗi chặn, ${report.warnings} cảnh báo. Mở Lịch sử để sao chép toàn bộ.", error = if (report.errors > 0) "Chưa đủ điều kiện tạo APK. Xem tất cả phát hiện trong Lịch sử và báo cáo." else null, percent = 100) }
        }
        return report
    }
    private fun build(intent: Intent) {
        val state = AppState.snapshot
        val input = state.source ?: error("Chưa chọn APK hợp lệ.")
        val info = state.info ?: error("Chưa đọc được thông tin APK.")
        val mode = Mode.valueOf(intent.getStringExtra("mode") ?: "RESIGN")
        val target = if (mode == Mode.CLONE) intent.getStringExtra("package") ?: "" else info.packageName
        val audit = audit(intent, true)
        require(audit.errors == 0) { "Đã quét toàn bộ: ${audit.errors} lỗi chặn. Chưa xuất APK; mở Lịch sử và báo cáo để sao chép mọi phát hiện trong một lần." }
        progress(46, "Mở khóa ký cục bộ")
        val identity = KeyVault.get(this)
        val records = getSharedPreferences("signatures", MODE_PRIVATE)
        val previous = records.getString(target, null)
        require(previous == null || previous == identity.fingerprint) { "Package này đã được tạo bằng khóa khác. Hãy nhập đúng khóa cũ để cập nhật bản sao." }
        val output = File(File(filesDir, "results").apply { mkdirs() }, "$target-${System.currentTimeMillis()}.apk")
        val report = ApkEngine.build(input, output, mode, target, intent.getStringExtra("label") ?: "", identity) { percent, phase -> progress(46 + percent * 54 / 100, phase) }
        record(mapOf("outputSha256" to report.sha256, "target" to target, "changes" to report.changes.joinToString("\n")))
        records.edit().putString(target, identity.fingerprint).apply()
        if (!ResultStore.save(this, report)) AppState.update { it.copy(historyWarning = "Không lưu được con trỏ kết quả gần nhất. Hãy xuất APK trước khi đóng công cụ.") }
        File(output.path + ".txt").writeText("APK Tách Gốc 0.3.1\nChế độ: ${mode.name}\nPackage: $target\nSHA-256: ${report.sha256}\nChứng chỉ: ${identity.fingerprint}\n\n${report.changes.joinToString("\n")}\n\nĐã kiểm tra chữ ký v2, manifest và CRC. Chưa xác nhận ứng dụng này chạy được; hãy cài thử.\n")
        AppState.update { it.copy(report = report, error = null, status = "Đã tạo APK và xác minh chữ ký", percent = 100) }
    }
    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
    override fun onTimeout(startId: Int, fgsType: Int) {
        timedOut = true
        recordFailure("Android đã giới hạn thời gian xử lý nền; xem giai đoạn cuối, phần còn lại chưa hoàn tất.")
        AppState.update { it.copy(error = "Android đã giới hạn thời gian xử lý nền. Chưa có kết quả mới.", busy = false) }
        stopSelf(startId)
    }
}
