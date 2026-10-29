package vn.apktachgoc

import android.app.*
import android.content.*
import android.net.Uri
import android.os.*
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import vn.apktachgoc.core.*
import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors

data class AppSnapshot(val busy: Boolean = false, val percent: Int = 0, val status: String = "Chọn APK để bắt đầu", val error: String? = null,
    val source: File? = null, val name: String = "", val info: ApkInfo? = null, val report: BuildReport? = null)
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
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("processing", "Xử lý APK", NotificationManager.IMPORTANCE_LOW))
    }
    private fun notification(percent: Int, text: String) = NotificationCompat.Builder(this, "processing")
        .setSmallIcon(R.drawable.ic_app).setContentTitle("APK Tách Gốc").setContentText(text).setOngoing(true)
        .setProgress(100, percent, percent == 0).setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)).build()
    private fun progress(percent: Int, text: String) {
        AppState.update { it.copy(percent = percent, status = text) }
        getSystemService(NotificationManager::class.java).notify(7, notification(percent, text))
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) { stopSelf(startId); return START_NOT_STICKY }
        if (AppState.snapshot.busy) return START_NOT_STICKY
        AppState.update { it.copy(busy = true, percent = 0, error = null, report = null) }
        if (Build.VERSION.SDK_INT >= 29) startForeground(7, notification(0, "Đang chuẩn bị"), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(7, notification(0, "Đang chuẩn bị"))
        wakeLock = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "apktachgoc:processing").apply { acquire(30 * 60 * 1000L) }
        worker.execute {
            try {
                when (intent.action) {
                    "INSPECT" -> inspect(Uri.parse(intent.getStringExtra("uri")))
                    "BUILD" -> build(intent)
                    else -> error("Lệnh xử lý không hợp lệ.")
                }
            } catch (e: OutOfMemoryError) {
                AppState.update { it.copy(error = "Không đủ RAM để xử lý APK này. Hãy chọn APK nhỏ hơn.", status = "Chưa tạo APK") }
            } catch (e: Exception) {
                AppState.update { it.copy(error = e.message ?: e.javaClass.simpleName, status = "Chưa tạo APK") }
            } finally {
                AppState.update { it.copy(busy = false) }
                if (wakeLock?.isHeld == true) wakeLock?.release()
                stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(startId)
            }
        }
        return START_NOT_STICKY
    }
    private fun inspect(uri: Uri) {
        AppState.update { AppSnapshot(busy = true, status = "Sao chép APK vào vùng làm việc") }
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
            progress(65, "Đọc manifest và nhận diện split APK")
            val info = ApkEngine.inspect(file)
            val archive = packageManager.getPackageArchiveInfo(file.path, 0)
            archive?.applicationInfo?.apply { sourceDir = file.path; publicSourceDir = file.path }
            val name = archive?.applicationInfo?.loadLabel(packageManager)?.toString() ?: info.packageName
            AppState.update { it.copy(source = file, info = info, name = name, percent = 100, status = "Đã đọc APK • ${(file.length() / 1048576.0).let { n -> "%.1f".format(n) }} MB") }
        } catch (e: Throwable) { file.delete(); throw e }
    }
    private fun build(intent: Intent) {
        val state = AppState.snapshot
        val input = state.source ?: error("Chưa chọn APK hợp lệ.")
        val info = state.info ?: error("Chưa đọc được thông tin APK.")
        val mode = Mode.valueOf(intent.getStringExtra("mode") ?: "RESIGN")
        val target = if (mode == Mode.CLONE) intent.getStringExtra("package") ?: "" else info.packageName
        progress(1, "Mở khóa ký cục bộ")
        val identity = KeyVault.get(this)
        val records = getSharedPreferences("signatures", MODE_PRIVATE)
        val previous = records.getString(target, null)
        require(previous == null || previous == identity.fingerprint) { "Package này đã được tạo bằng khóa khác. Hãy nhập đúng khóa cũ để cập nhật bản sao." }
        val output = File(File(filesDir, "results").apply { mkdirs() }, "$target-${System.currentTimeMillis()}.apk")
        val report = ApkEngine.build(input, output, mode, target, intent.getStringExtra("label") ?: "", identity, ::progress)
        records.edit().putString(target, identity.fingerprint).apply()
        getSharedPreferences("last", MODE_PRIVATE).edit().putString("path", output.path).putString("package", target).putString("hash", report.sha256).putString("cert", identity.fingerprint).apply()
        File(output.path + ".txt").writeText("APK Tách Gốc 0.1.0\nPackage: $target\nSHA-256: ${report.sha256}\nChứng chỉ: ${identity.fingerprint}\n\n${report.changes.joinToString("\n")}\n\nĐã kiểm tra chữ ký v2, manifest và CRC. Chưa xác nhận ứng dụng này chạy được; hãy cài thử.\n")
        AppState.update { it.copy(report = report, error = null, status = "Đã tạo APK và xác minh chữ ký", percent = 100) }
    }
    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
    override fun onTimeout(startId: Int, fgsType: Int) {
        AppState.update { it.copy(error = "Android đã giới hạn thời gian xử lý nền. Chưa có kết quả mới.", busy = false) }
        stopSelf(startId)
    }
}
