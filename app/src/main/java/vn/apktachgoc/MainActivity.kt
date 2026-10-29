package vn.apktachgoc

import android.Manifest
import android.app.*
import android.content.*
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.text.InputType
import android.view.*
import android.widget.*
import androidx.core.content.FileProvider
import vn.apktachgoc.core.*
import java.io.File
import java.util.concurrent.Executors

class MainActivity : Activity() {
    private val green = Color.rgb(19, 120, 92)
    private val ink = Color.rgb(24, 45, 39)
    private val muted = Color.rgb(92, 110, 102)
    private lateinit var content: LinearLayout
    private lateinit var screenRoot: LinearLayout
    private lateinit var metadata: TextView
    private lateinit var status: TextView
    private lateinit var error: TextView
    private lateinit var progress: ProgressBar
    private lateinit var result: TextView
    private lateinit var keyInfo: TextView
    private lateinit var label: EditText
    private lateinit var packageNameField: EditText
    private lateinit var cloneFields: LinearLayout
    private lateinit var modes: RadioGroup
    private lateinit var signRadio: RadioButton
    private lateinit var cloneRadio: RadioButton
    private lateinit var buildButton: Button
    private val inputs = mutableListOf<View>()
    private val outputButtons = mutableListOf<Button>()
    private val worker = Executors.newSingleThreadExecutor()
    private var uiBusy = false
    private var seenInput: File? = null
    private var pendingKey: ByteArray? = null
    private var currentReport: BuildReport? = null
    private val listener: (AppSnapshot) -> Unit = { render(it) }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun shape(color: Int, radius: Int = 18) = GradientDrawable().apply { setColor(color); cornerRadius = dp(radius).toFloat() }
    private fun text(parent: LinearLayout, value: String, size: Float = 15f, color: Int = ink): TextView = TextView(this).apply {
        text = value; textSize = size; setTextColor(color); setLineSpacing(dp(3).toFloat(), 1f)
        parent.addView(this, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(9) })
    }
    private fun title(parent: LinearLayout, value: String) = text(parent, value, 19f).apply { setTypeface(typeface, Typeface.BOLD) }
    private fun button(parent: LinearLayout, value: String, primary: Boolean = false, action: () -> Unit): Button = Button(this).apply {
        text = value; isAllCaps = false; textSize = 15f; minHeight = dp(50)
        setTextColor(if (primary) Color.WHITE else green)
        backgroundTintList = android.content.res.ColorStateList.valueOf(if (primary) green else Color.rgb(229, 241, 234))
        parent.addView(this, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(4) })
        setOnClickListener { action() }
    }
    private fun card(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL; setPadding(dp(18), dp(18), dp(18), dp(14)); background = shape(Color.WHITE)
        content.addView(this, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(14) })
    }
    private fun field(parent: LinearLayout, hintText: String): EditText = EditText(this).apply {
        hint = hintText; textSize = 16f; setTextColor(ink); setSingleLine(true); minHeight = dp(52)
        parent.addView(this, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(9) }); inputs += this
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val frame = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; isFocusableInTouchMode = true; setBackgroundColor(Color.rgb(243, 246, 243)) }
        screenRoot = frame
        frame.setOnApplyWindowInsetsListener { v, insets -> v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom); insets }
        setContentView(frame)
        val header = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(22), dp(23), dp(22), dp(18)); setBackgroundColor(Color.rgb(16, 43, 38)); frame.addView(this) }
        text(header, "CÔNG CỤ NGOẠI TUYẾN • 0.1.0", 11f, Color.rgb(154, 206, 181))
        text(header, "APK Tách Gốc", 29f, Color.WHITE).setTypeface(null, Typeface.BOLD)
        text(header, "Ký lại. Tạo bản sao độc lập. Không cần root.", 14f, Color.rgb(206, 224, 214))
        val scroll = ScrollView(this).apply { isFillViewport = true; frame.addView(this, LinearLayout.LayoutParams(-1, 0, 1f)) }
        content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(16), dp(18), dp(16), dp(22)); scroll.addView(this) }
        card().also { c ->
            title(c, "1. APK đầu vào")
            metadata = text(c, "Chưa chọn tệp\nChọn APK đơn đầy đủ từ điện thoại.", 14f, muted).apply { setTextIsSelectable(true) }
            inputs += button(c, "Chọn file APK") { chooseApk() }
            text(c, "Tệp gốc được giữ nguyên. APKS, XAPK và APK cần split chưa được hỗ trợ.", 12f, muted)
        }
        card().also { c ->
            title(c, "2. Chế độ xử lý")
            modes = RadioGroup(this).apply { c.addView(this) }
            signRadio = RadioButton(this).apply { id = View.generateViewId(); text = "Ký lại APK"; minHeight = dp(48); modes.addView(this); inputs += this }
            cloneRadio = RadioButton(this).apply { id = View.generateViewId(); text = "Tạo bản tách gốc"; minHeight = dp(48); modes.addView(this); inputs += this }
            cloneFields = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; c.addView(this) }
            text(cloneFields, "Tên ứng dụng mới", 13f, muted)
            label = field(cloneFields, "Ví dụ: Ghi chú • Bản riêng")
            text(cloneFields, "Package name riêng", 13f, muted)
            packageNameField = field(cloneFields, "vn.ungdung.banrieng").apply { inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD }
            text(cloneFields, "Giữ đúng package và khóa ký khi tạo bản cập nhật. Mỗi package có dữ liệu và phiên đăng nhập riêng.", 12f, muted)
            val modeNote = text(c, "", 12f, muted)
            modes.setOnCheckedChangeListener { _, checked ->
                cloneFields.visibility = if (checked == cloneRadio.id) View.VISIBLE else View.GONE
                modeNote.text = if (checked == cloneRadio.id) "Bản sao là APK cài độc lập, không dùng không gian ảo. Bản đầu chưa tách ứng dụng có mã native (.so)." else "Ký lại giữ package cũ, không tạo bản cài song song. Không thể cập nhật bản gốc có chữ ký khác."
            }
            modes.check(cloneRadio.id)
            inputs += button(c, "Hỗ trợ và giới hạn") { showLimits() }
        }
        card().also { c ->
            title(c, "3. Tạo APK")
            buildButton = button(c, "Tạo và ký APK", true) { startBuild() }
            status = text(c, "Chọn APK để bắt đầu", 14f, muted).apply { accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE }
            progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply { max = 100; c.addView(this, LinearLayout.LayoutParams(-1, dp(10))) }
            error = text(c, "", 14f, Color.rgb(164, 44, 39)).apply { visibility = View.GONE; setTextIsSelectable(true) }
            result = text(c, "", 12f, muted).apply { visibility = View.GONE; setTextIsSelectable(true) }
            outputButtons += button(c, "Lưu APK vào điện thoại") { currentReport?.let { createDocument(101, it.file.name, "application/vnd.android.package-archive") } }
            outputButtons += button(c, "Chia sẻ APK") { shareOutput() }
            outputButtons += button(c, "Mở trình cài đặt Android") { installOutput() }
        }
        card().also { c ->
            title(c, "Khóa ký trên máy")
            keyInfo = text(c, "Khóa RSA được tạo khi sử dụng, mã hóa bằng Android Keystore. Không gửi lên máy chủ.", 13f, muted)
            inputs += button(c, "Xem mã nhận diện khóa") { localWork("Đang mở khóa ký…") { val id = KeyVault.get(this); runOnUiThread { keyInfo.text = "SHA-256 chứng chỉ:\n${id.fingerprint}" } } }
            inputs += button(c, "Xuất khóa có mật khẩu (.p12)") { passwordDialog("Xuất khóa ký", true) { password ->
                localWork("Đang mã hóa khóa xuất…") {
                    try { pendingKey?.fill(0); pendingKey = SigningKeys.export(KeyVault.get(this), password); runOnUiThread { createDocument(102, "apk-tach-goc-key.p12", "application/x-pkcs12") } }
                    finally { password.fill('\u0000') }
                }
            } }
            inputs += button(c, "Nhập khóa có mật khẩu (.p12)") {
                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply { type = "*/*"; addCategory(Intent.CATEGORY_OPENABLE) }, 103)
            }
            text(c, "Hãy xuất khóa và cất mật khẩu trước khi gỡ công cụ. APK đã cài vẫn tồn tại; khóa bị mất sẽ khiến bạn không thể cập nhật bản sao cũ.", 12f, muted)
        }
        text(content, "Xử lý hoàn toàn trên điện thoại • Android 8.0 trở lên\nViệc ký lại có thể làm hỏng xác thực Google, DRM hoặc kiểm tra chữ ký của ứng dụng.", 12f, muted)
        savedInstanceState?.let { label.setText(it.getString("label")); packageNameField.setText(it.getString("package")); modes.check(if (it.getBoolean("clone", true)) cloneRadio.id else signRadio.id) }
        screenRoot.requestFocus()
        restoreLastResult()
        render(AppState.snapshot)
    }
    override fun onStart() { super.onStart(); AppState.listeners += listener; render(AppState.snapshot) }
    override fun onStop() { AppState.listeners -= listener; super.onStop() }
    override fun onSaveInstanceState(out: Bundle) { out.putString("label", label.text.toString()); out.putString("package", packageNameField.text.toString()); out.putBoolean("clone", modes.checkedRadioButtonId == cloneRadio.id); super.onSaveInstanceState(out) }
    private fun render(state: AppSnapshot) {
        if (isFinishing || !::status.isInitialized) return
        val busy = state.busy || uiBusy
        inputs.forEach { it.isEnabled = !busy }
        buildButton.isEnabled = !busy && state.source != null && state.info != null
        if (state.source != null && state.info != null) {
            metadata.text = "${state.name}\nPhiên bản ${state.info.versionName} (${state.info.versionCode})\n${state.info.packageName}" + if (state.info.nativeCode) "\nCó mã native • chỉ ký lại ở bản đầu" else ""
            if (seenInput !== state.source) {
                if (seenInput != null || label.text.isBlank()) label.setText("${state.name} • Bản riêng".take(80))
                if (seenInput != null || packageNameField.text.isBlank()) packageNameField.setText(state.info.packageName.lowercase() + ".tachgoc")
                seenInput = state.source
            }
        } else metadata.text = "Chưa chọn APK hợp lệ\nChọn APK đơn đầy đủ từ điện thoại."
        if (!uiBusy) status.text = (if (state.busy) "${state.percent}% • " else "") + state.status
        progress.progress = state.percent
        error.text = state.error ?: ""; error.visibility = if (state.error != null) View.VISIBLE else View.GONE
        if (state.report != null) currentReport = state.report
        outputButtons.forEach { it.isEnabled = !busy && currentReport?.file?.exists() == true }
        currentReport?.let { report ->
            result.visibility = View.VISIBLE
            result.text = "APK đã xác minh: ${report.packageName}\n${"%.1f".format(report.file.length() / 1048576.0)} MB\nSHA-256: ${report.sha256}\n\nĐã kiểm tra chữ ký, manifest và CRC. Hãy cài thử để kiểm tra ứng dụng.\n" + report.changes.joinToString("\n")
        }
    }
    private fun chooseApk() = startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
        type = "*/*"; addCategory(Intent.CATEGORY_OPENABLE)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }, 100)
    private fun runService(intent: Intent) {
        focusScreen()
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 200)
        try { startForegroundService(intent) } catch (e: Exception) { message("Không khởi chạy được xử lý", e.message ?: "Lỗi Android") }
    }
    private fun startBuild() {
        val clone = modes.checkedRadioButtonId == cloneRadio.id
        val pkg = packageNameField.text.toString().trim()
        if (clone && (!ApkEngine.validPackage(pkg) || pkg == AppState.snapshot.info?.packageName)) { packageNameField.error = "Nhập package hợp lệ, khác bản gốc"; return }
        if (clone && label.text.isBlank()) { label.error = "Nhập tên bản sao"; return }
        currentReport = null; result.visibility = View.GONE
        runService(Intent(this, ProcessingService::class.java).setAction("BUILD").putExtra("mode", if (clone) "CLONE" else "RESIGN").putExtra("package", pkg).putExtra("label", label.text.toString().trim()))
    }
    private fun createDocument(code: Int, name: String, mime: String) {
        try { startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply { type = mime; addCategory(Intent.CATEGORY_OPENABLE); putExtra(Intent.EXTRA_TITLE, name) }, code) }
        catch (e: Exception) { pendingKey?.fill(0); pendingKey = null; message("Không mở được nơi lưu", e.message ?: "Thiếu ứng dụng chọn tệp") }
    }
    @Deprecated("Legacy Activity result API remains supported")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 104) { if (packageManager.canRequestPackageInstalls()) installOutput(); return }
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { if (requestCode == 102) { pendingKey?.fill(0); pendingKey = null }; return }
        when (requestCode) {
            100 -> { currentReport = null; result.visibility = View.GONE; runService(Intent(this, ProcessingService::class.java).setAction("INSPECT").putExtra("uri", uri.toString())) }
            101 -> currentReport?.file?.let { file -> localWork("Đang lưu APK…") {
                contentResolver.openOutputStream(uri, "wt").use { out -> requireNotNull(out) { "Không mở được tệp đích." }; file.inputStream().use { it.copyTo(out) } }
                runOnUiThread { message("Đã lưu APK", "Tệp đã được chép đến vị trí bạn chọn.") }
            } }
            102 -> { val bytes = pendingKey; pendingKey = null
                if (bytes == null) { message("Chưa lưu khóa", "Phiên xuất khóa đã đóng. Hãy bấm Xuất khóa lại."); return }
                localWork("Đang lưu khóa có mật khẩu…") {
                    try { contentResolver.openOutputStream(uri, "wt").use { out -> requireNotNull(out) { "Không mở được tệp khóa đích." }; out.write(bytes) }; runOnUiThread { message("Đã xuất khóa", "Giữ riêng tệp .p12 và mật khẩu để khôi phục hoặc cập nhật bản sao.") } }
                    finally { bytes.fill(0) }
                }
            }
            103 -> passwordDialog("Nhập khóa ký", false) { password -> localWork("Đang kiểm tra khóa nhập…") {
                try {
                    val bytes = contentResolver.openInputStream(uri).use { input -> requireNotNull(input) { "Không đọc được khóa." }; input.readNBytesCompat(1024 * 1024 + 1) }
                    try { val identity = SigningKeys.import(bytes, password); KeyVault.save(this, identity); runOnUiThread { keyInfo.text = "Đã nhập khóa. SHA-256:\n${identity.fingerprint}"; message("Đã nhập khóa", "Khóa này sẽ dùng cho các lần ký tiếp theo. Bản sao cũ chỉ cập nhật được bằng đúng khóa đã dùng trước đó.") } }
                    finally { bytes.fill(0) }
                } finally { password.fill('\u0000') }
            } }
        }
    }
    private fun java.io.InputStream.readNBytesCompat(limit: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream(); val b = ByteArray(8192)
        while (out.size() < limit) { val n = read(b, 0, minOf(b.size, limit - out.size())); if (n < 0) break; out.write(b, 0, n) }
        return out.toByteArray()
    }
    private fun passwordDialog(title: String, exporting: Boolean, action: (CharArray) -> Unit) {
        val wrap = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(24), dp(4), dp(24), 0) }
        text(wrap, if (exporting) "Ít nhất 10 ký tự. Khóa xuất được mã hóa PKCS#12. Hãy ghi nhớ mật khẩu." else "Nhập mật khẩu của tệp PKCS#12. Khóa hợp lệ sẽ thay khóa đang dùng.", 14f, muted)
        val pass = EditText(this).apply { hint = "Mật khẩu"; inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD; wrap.addView(this) }
        val confirm = if (exporting) EditText(this).apply { hint = "Nhập lại mật khẩu"; inputType = pass.inputType; wrap.addView(this) } else null
        val dialog = AlertDialog.Builder(this).setTitle(title).setView(wrap).setNegativeButton("Hủy", null).setPositiveButton(if (exporting) "Xuất khóa" else "Nhập khóa", null).create()
        dialog.setOnShowListener { dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
            if (exporting && pass.text.length < 10) { pass.error = "Cần ít nhất 10 ký tự"; return@setOnClickListener }
            if (confirm != null && pass.text.toString() != confirm.text.toString()) { confirm.error = "Mật khẩu chưa khớp"; return@setOnClickListener }
            val password = pass.text.toString().toCharArray(); pass.text.clear(); confirm?.text?.clear(); dialog.dismiss(); action(password)
        } }
        dialog.show()
    }
    private fun localWork(description: String, action: () -> Unit) {
        if (uiBusy || AppState.snapshot.busy) return
        focusScreen()
        uiBusy = true; render(AppState.snapshot); status.text = description
        worker.execute {
            try { action() } catch (e: Exception) { runOnUiThread { message("Không hoàn tất", e.message ?: e.javaClass.simpleName) } }
            finally { runOnUiThread { uiBusy = false; render(AppState.snapshot) } }
        }
    }
    private fun outputUri(): Uri? = currentReport?.file?.takeIf { it.exists() }?.let { FileProvider.getUriForFile(this, "$packageName.files", it) }
    private fun shareOutput() {
        val uri = outputUri() ?: return
        try { startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "application/vnd.android.package-archive"; putExtra(Intent.EXTRA_STREAM, uri); clipData = ClipData.newRawUri("APK", uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }, "Chia sẻ APK")) }
        catch (e: Exception) { message("Không chia sẻ được", e.message ?: "Không có ứng dụng nhận APK") }
    }
    private fun installOutput() {
        if (currentReport?.file?.exists() != true) return
        if (!packageManager.canRequestPackageInstalls()) {
            try { startActivityForResult(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")), 104) }
            catch (e: Exception) { message("Chưa mở được quyền cài APK", "Vào Cài đặt Android và cho phép APK Tách Gốc cài ứng dụng không rõ nguồn gốc.") }
            return
        }
        val uri = outputUri() ?: return
        try { startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION).apply { clipData = ClipData.newRawUri("APK", uri) }) }
        catch (e: Exception) { message("Không mở được trình cài đặt", e.message ?: "Hãy lưu APK rồi mở bằng trình quản lý tệp.") }
    }
    private fun restoreLastResult() {
        if (AppState.snapshot.report != null) return
        val prefs = getSharedPreferences("last", MODE_PRIVATE)
        val file = prefs.getString("path", null)?.let { File(it) } ?: return
        if (file.exists() && file.parentFile?.canonicalPath == File(filesDir, "results").canonicalPath) currentReport = BuildReport(file, prefs.getString("package", "") ?: "", prefs.getString("hash", "") ?: "", emptyList(), prefs.getString("cert", "") ?: "")
    }
    private fun message(title: String, body: String) { if (!isFinishing && !isDestroyed) AlertDialog.Builder(this).setTitle(title).setMessage(body).setPositiveButton("Đóng", null).show() }
    private fun focusScreen() {
        screenRoot.requestFocus()
        (getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager).hideSoftInputFromWindow(screenRoot.windowToken, 0)
    }
    private fun showLimits() = message("Hỗ trợ của bản 0.1.0", "• APK đơn có DEX thông thường; tách gốc giữ namespace lớp và sửa định danh theo bảng ánh xạ.\n• Chặn split, sharedUserId, thư viện dùng chung, native khi tách gốc, mã nhúng và tài nguyên chưa hỗ trợ.\n• Dữ liệu hoặc phiên đăng nhập bản gốc không được sao chép.\n• Đăng nhập Google, DRM, app links và kiểm tra chữ ký có thể hỏng sau khi ký lại. Không vượt chống gian lận.\n• Xác minh chữ ký không đảm bảo ứng dụng chạy được. Luôn cài thử.\n• Chỉ xử lý APK bạn có quyền sử dụng và sửa đổi.")
    override fun onDestroy() { if (isFinishing) { pendingKey?.fill(0); pendingKey = null }; worker.shutdown(); super.onDestroy() }
}
