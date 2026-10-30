package vn.apktachgoc.nativesample

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

class MainActivity : Activity() {
    external fun nativeValue(): Int
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val value = nativeValue()
        check(value == 73) { "JNI trả về giá trị sai: $value" }
        setContentView(TextView(this).apply {
            setPadding(32, 80, 32, 32); textSize = 20f
            text = "THƯ VIỆN NATIVE ĐÃ CHẠY\nJNI nativeValue() = $value\nPackage: $packageName\nUID: ${android.os.Process.myUid()}\n\nĐây là APK mẫu dùng thư viện ELF/JNI thật, ABI x86_64."
        })
    }
    companion object { init { System.loadLibrary("nativefixture") } }
}
