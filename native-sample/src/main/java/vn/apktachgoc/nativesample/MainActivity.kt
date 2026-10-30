package vn.apktachgoc.nativesample

import android.app.Activity
import android.os.Bundle
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.*

class MainActivity : Activity() {
    external fun nativeValue(): Int
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val value = nativeValue()
        check(value == 73) { "JNI trả về giá trị sai: $value" }
        val prefs = getSharedPreferences("session", MODE_PRIVATE)
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(28, 44, 28, 24) }
        setContentView(layout)
        val info = TextView(this).apply { textSize = 18f; layout.addView(this) }
        val login = EditText(this).apply { hint = "Phiên đăng nhập mô phỏng"; setText(prefs.getString("marker", "")); layout.addView(this) }
        fun refresh() {
            info.text = "THƯ VIỆN NATIVE ĐÃ CHẠY\nJNI nativeValue() = $value\nPackage: $packageName\nUID: ${android.os.Process.myUid()}\nDữ liệu: ${prefs.getString("marker", "chưa đăng nhập")}\n\nELF/JNI thật; FindClass dùng namespace gốc; ABI x86_64."
        }
        Button(this).apply { text = "Lưu phiên"; layout.addView(this); setOnClickListener { prefs.edit().putString("marker", login.text.toString()).commit(); refresh() } }
        refresh()
    }
    companion object { init { System.loadLibrary("nativefixture") } }
}
// Disposable fixture only; not included in the tool APK.
class SessionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        intent.getStringExtra("marker")?.let { context.getSharedPreferences("session", Context.MODE_PRIVATE).edit().putString("marker", it).commit() }
        resultData = context.getSharedPreferences("session", Context.MODE_PRIVATE).getString("marker", "empty")
    }
}
