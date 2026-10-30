package vn.apktachgoc

import android.content.Context
import vn.apktachgoc.core.BuildReport
import vn.apktachgoc.core.Mode
import java.io.File

/** Pointer to the last successful result, never ownership of the APK itself. */
object ResultStore {
    fun clear(context: Context) = context.getSharedPreferences("last", Context.MODE_PRIVATE).edit().clear().commit()
    fun save(context: Context, report: BuildReport) = context.getSharedPreferences("last", Context.MODE_PRIVATE).edit()
        .putString("path", report.file.path).putString("package", report.packageName).putString("hash", report.sha256)
        .putString("cert", report.certificateSha256).putString("mode", report.mode.name)
        .putString("changes", report.changes.joinToString("\n")).commit()
    fun restore(context: Context): BuildReport? {
        val prefs = context.getSharedPreferences("last", Context.MODE_PRIVATE)
        val file = prefs.getString("path", null)?.let { File(it) } ?: return null
        if (!file.isFile || file.parentFile?.canonicalPath != File(context.filesDir, "results").canonicalPath) return null
        val hash = prefs.getString("hash", "").orEmpty()
        // Migrate 0.3.0: a newer failed/audit/read operation supersedes its cached
        // successful APK even when that old version left the pointer behind.
        val latest = HistoryStore.list(context).firstOrNull()
        if (latest != null && (latest.optString("status") != "SUCCESS" || latest.optString("outputSha256") != hash)) return null
        return BuildReport(file, prefs.getString("package", "").orEmpty(), hash,
            prefs.getString("changes", "").orEmpty().lines().filter { it.isNotBlank() }, prefs.getString("cert", "").orEmpty(),
            if (prefs.getString("mode", "RESIGN") == "CLONE") Mode.CLONE else Mode.RESIGN)
    }
}
