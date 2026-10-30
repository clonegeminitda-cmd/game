package vn.apktachgoc

import android.app.Activity
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import vn.apktachgoc.core.Mode
import java.io.File

@RunWith(AndroidJUnit4::class)
class ResultStateTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private fun send(action: String, mode: String, uri: Uri? = null, target: String = "", label: String = ""): Set<String> {
        val previous = HistoryStore.list(context).map { it.getString("id") }.toSet()
        context.startForegroundService(Intent(context, ProcessingService::class.java).setAction(action)
            .putExtra("mode", mode).putExtra("uri", uri?.toString()).putExtra("package", target).putExtra("label", label))
        return previous
    }
    private fun await(previous: Set<String>, operation: String, status: String): JSONObject {
        val end = System.currentTimeMillis() + 180000
        while (System.currentTimeMillis() < end) {
            val row = HistoryStore.list(context).firstOrNull { it.optString("id") !in previous && it.optString("operation") == operation }
            if (row != null && row.optString("status") == status && !AppState.snapshot.busy) return row
            if (row?.optString("status") == "FAILED" && status != "FAILED") fail(HistoryStore.text(row))
            Thread.sleep(350)
        }
        throw AssertionError("Timeout $operation/$status: ${AppState.snapshot.error}")
    }
    private fun views(view: View): List<View> = listOf(view) + if (view is ViewGroup) (0 until view.childCount).flatMap { views(view.getChildAt(it)) } else emptyList()
    private fun assertNoOldResult(activity: Activity, hash: String) {
        val all = views(activity.window.decorView)
        assertFalse(all.filterIsInstance<TextView>().any { it.text.toString().contains(hash) })
        for (caption in listOf("Lưu APK vào điện thoại", "Chia sẻ APK", "Cài APK kết quả")) {
            val button = all.filterIsInstance<TextView>().first { it.text.toString() == caption }
            assertFalse("Nút $caption phải bị vô hiệu hóa", button.isEnabled)
        }
    }
    @Test fun failedCloneCannotResurrectPreviousResignedApk() {
        val folder = File(context.getExternalFilesDir(null), "device-result-state-test").apply { mkdirs() }
        val input = File(folder, "sample.apk")
        instrumentation.context.assets.open("sample-debug.apk").use { source -> input.outputStream().use { source.copyTo(it) } }
        await(send("INSPECT", "RESIGN", Uri.fromFile(input)), "INSPECT", "SUCCESS")
        await(send("BUILD", "RESIGN"), "RESIGN", "SUCCESS")
        val old = AppState.snapshot.report!!
        assertEquals(Mode.RESIGN, old.mode)
        assertNotNull(ResultStore.restore(context))
        val key = KeyVault.get(context).fingerprint
        val activity = instrumentation.startActivitySync(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        instrumentation.runOnMainSync { assertTrue(views(activity.window.decorView).filterIsInstance<TextView>().any { it.text.toString().contains(old.sha256) }) }

        val failed = await(send("BUILD", "CLONE", target = "bad", label = ""), "CLONE", "FAILED")
        assertEquals(2, failed.getInt("auditErrors"))
        assertNull(AppState.snapshot.report)
        assertNull(ResultStore.restore(context))
        assertTrue(old.file.exists())
        assertEquals(key, KeyVault.get(context).fingerprint)
        instrumentation.waitForIdleSync()
        lateinit var copied: String
        instrumentation.runOnMainSync {
            assertNoOldResult(activity, old.sha256)
            val all = views(activity.window.decorView).filterIsInstance<TextView>()
            assertTrue(all.any { it.text.toString().contains("[Package đích]") && it.text.toString().contains("[Tên bản sao]") })
            val copy = all.first { it.text.toString() == "Sao chép báo cáo lỗi lần này" }
            assertEquals(View.VISIBLE, copy.visibility)
            assertTrue(copy.performClick())
            copied = context.getSystemService(ClipboardManager::class.java).primaryClip!!.getItemAt(0).coerceToText(context).toString()
        }
        assertEquals(HistoryStore.text(failed), copied)
        assertTrue(copied.contains("Lỗi chặn: 2"))
        // Simulate the stale pointer left by 0.3.0, then recreate with no live state.
        ResultStore.save(context, old)
        assertNull(ResultStore.restore(context))
        AppState.update { AppSnapshot() }
        instrumentation.runOnMainSync { activity.finish() }
        val reopened = instrumentation.startActivitySync(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        instrumentation.runOnMainSync { assertNoOldResult(reopened, old.sha256); reopened.finish() }
        File(folder, "failure-report.txt").writeText(copied)
        File(folder, "result.txt").writeText("PASS: ký lại thành công rồi tách gốc lỗi 2 điều kiện; không hiện/hash/cài kết quả cũ; hiện đúng 2 lỗi và nút sao chép trực tiếp; clipboard khớp báo cáo; mở lại vẫn không khôi phục kết quả cũ; giữ nguyên APK đã tạo và khóa ký.\nPrevious APK SHA256=${old.sha256}\n")
    }
}
