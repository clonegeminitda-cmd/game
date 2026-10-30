package vn.apktachgoc

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import vn.apktachgoc.core.*
import java.io.File

@RunWith(AndroidJUnit4::class)
class HistoryFlowTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val folder get() = File(context.getExternalFilesDir(null), "device-history-test").apply { mkdirs() }
    private fun fixture(asset: String, name: String): File = File(folder, name).also { file ->
        instrumentation.context.assets.open(asset).use { source -> file.outputStream().use { source.copyTo(it) } }
    }
    private fun service(action: String, uri: Uri? = null, target: String = "vn.apktachgoc.sample.tachgoc"): Set<String> {
        val previous = HistoryStore.list(context).map { it.getString("id") }.toSet()
        context.startForegroundService(Intent(context, ProcessingService::class.java).setAction(action)
            .putExtra("uri", uri?.toString()).putExtra("mode", "CLONE").putExtra("package", target).putExtra("label", "Mẫu tài nguyên • Bản riêng"))
        return previous
    }
    private fun awaitRecord(previous: Set<String>, operation: String, status: String, seconds: Int = 180): JSONObject {
        val end = System.currentTimeMillis() + seconds * 1000L
        while (System.currentTimeMillis() < end) {
            val row = HistoryStore.list(context).firstOrNull { it.optString("id") !in previous && it.optString("operation") == operation }
            if (row != null && row.optString("status") == status && !AppState.snapshot.busy) return row
            if (row != null && row.optString("status") == "FAILED" && status != "FAILED") fail(HistoryStore.text(row))
            Thread.sleep(350)
        }
        throw AssertionError("Timeout: $operation/$status; ${AppState.snapshot.status}; ${AppState.snapshot.error}")
    }
    private fun click(text: String) {
        val end = System.currentTimeMillis() + 20000
        while (System.currentTimeMillis() < end) {
            val root = instrumentation.uiAutomation.rootInActiveWindow
            val candidates = root?.findAccessibilityNodeInfosByText(text).orEmpty() + root?.findAccessibilityNodeInfosByText(text.uppercase()).orEmpty()
            val node = candidates.firstOrNull { it.text?.toString()?.equals(text, ignoreCase = true) == true }
            if (node != null) {
                var clickable: AccessibilityNodeInfo = node
                while (!clickable.isClickable) clickable = clickable.parent ?: break
                if (clickable.performAction(AccessibilityNodeInfo.ACTION_CLICK)) { Thread.sleep(400); return }
            }
            Thread.sleep(300)
        }
        throw AssertionError("Không tìm được nút: $text")
    }
    @Test fun collectsAllErrorsPersistsAndCopiesOneReport() {
        val input = fixture("multi-errors.apk", "history-multi-errors.apk")
        val hash = ApkEngine.sha256(input)
        val previous = service("INSPECT", Uri.fromFile(input))
        awaitRecord(previous, "INSPECT", "FAILED")
        assertTrue(AppState.snapshot.source?.isFile == true)
        val beforeAudit = service("AUDIT")
        val row = awaitRecord(beforeAudit, "AUDIT", "CHECKED")
        assertEquals(9, row.optInt("auditErrors"))
        assertEquals(hash, row.optString("inputSha256"))
        val id = row.getString("id")
        // Drop live state, then reload files and open the same persistent report.
        AppState.update { AppSnapshot() }
        val persisted = HistoryStore.read(context, id)!!
        assertEquals(HistoryStore.text(row), HistoryStore.text(persisted))
        val activity = instrumentation.startActivitySync(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        click("Lịch sử và báo cáo")
        click(HistoryStore.summary(persisted))
        click("Sao chép")
        lateinit var clipboard: String
        instrumentation.runOnMainSync { clipboard = context.getSystemService(ClipboardManager::class.java).primaryClip!!.getItemAt(0).coerceToText(context).toString() }
        assertEquals(HistoryStore.text(persisted), clipboard)
        listOf("sharedUserId", "split", "authenticator.xml", "config-one.json", "config-two.json", "libfirst.so", "libsecond.so", "libbroken.so").forEach { assertTrue(it, clipboard.contains(it, true)) }
        assertTrue(clipboard.contains(hash))
        assertFalse(clipboard.contains("BEGIN PRIVATE KEY"))
        File(folder, "report-copied.txt").writeText(clipboard)
        File(folder, "multi-error-result.txt").writeText("PASS: INSPECT thất bại vẫn giữ APK để quét; 9 lỗi độc lập trong một phiên; lịch sử đọc lại từ đĩa; nút Sao chép chứa đủ các lỗi.\nInput SHA256=$hash\nHistory id=$id\n")
        instrumentation.runOnMainSync { activity.finish() }
    }
    @Test fun buildsAccountResourceApkThroughServiceAndRecordsSuccess() {
        val input = fixture("sample-debug.apk", "account-source.apk")
        val previous = service("INSPECT", Uri.fromFile(input))
        awaitRecord(previous, "INSPECT", "SUCCESS")
        val beforeBuild = service("BUILD")
        val row = awaitRecord(beforeBuild, "CLONE", "SUCCESS")
        assertEquals(0, row.optInt("auditErrors"))
        assertTrue(row.optString("changes").contains("accountType"))
        val output = AppState.snapshot.report!!.file
        assertEquals("vn.apktachgoc.sample.tachgoc", ApkEngine.inspect(output).packageName)
        output.copyTo(File(folder, "account-clone.apk"), overwrite = true)
        assertEquals(row.getString("outputSha256"), ApkEngine.sha256(output))
        File(folder, "success-report.txt").writeText(HistoryStore.text(row))
        File(folder, "success-result.txt").writeText("PASS: service kiểm tra toàn bộ, sửa accountType qua @string/bí danh, tạo/ký/xác minh APK; lịch sử SUCCESS và auditErrors=0.\nOutput SHA256=${row.getString("outputSha256")}\n")
    }
}
