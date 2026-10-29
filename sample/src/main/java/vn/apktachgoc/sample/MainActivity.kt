package vn.apktachgoc.sample

import android.app.Activity
import android.os.Bundle
import android.content.*
import android.database.*
import android.net.Uri
import android.widget.*

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = getSharedPreferences("session", MODE_PRIVATE)
        check(packageName == BuildConfig.APPLICATION_ID) { "APPLICATION_ID chưa được ánh xạ đúng." }
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(40, 60, 40, 40) }
        setContentView(layout)
        val info = TextView(this).apply { textSize = 17f; layout.addView(this) }
        val login = EditText(this).apply { hint = "Tên đăng nhập mô phỏng"; setText(prefs.getString("marker", "")); layout.addView(this) }
        fun refresh() {
            val providerValue = contentResolver.query(Uri.parse("content://vn.apktachgoc.sample.notes/session"), null, null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else "rỗng" }
            val compiledId = Class.forName("vn.apktachgoc.sample.BuildConfig").getField("APPLICATION_ID").get(null)
            info.text = "${getString(resources.getIdentifier("app_name", "string", packageName))}\nPackage: $packageName\nBuildConfig: $compiledId\nUID: ${android.os.Process.myUid()}\nDữ liệu: ${prefs.getString("marker", "chưa đăng nhập")}\nProvider: $providerValue\nTài nguyên package: ${getString(R.string.own_package)}"
        }
        Button(this).apply { text = "Lưu phiên đăng nhập"; layout.addView(this); setOnClickListener { prefs.edit().putString("marker", login.text.toString()).commit(); refresh() } }
        Button(this).apply { text = "Đọc lại dữ liệu"; layout.addView(this); setOnClickListener { refresh() } }
        refresh()
    }
}
class NotesProvider : ContentProvider() {
    override fun onCreate() = true
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor = MatrixCursor(arrayOf("marker")).apply {
        addRow(arrayOf(context!!.getSharedPreferences("session", Context.MODE_PRIVATE).getString("marker", "chưa đăng nhập")))
    }
    override fun getType(uri: Uri) = "text/plain"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0
}
// Test-only receiver. This module is a disposable test fixture, not part of the tool APK.
class SessionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        intent.getStringExtra("marker")?.let { context.getSharedPreferences("session", Context.MODE_PRIVATE).edit().putString("marker", it).commit() }
        resultData = context.getSharedPreferences("session", Context.MODE_PRIVATE).getString("marker", "empty")
    }
}
