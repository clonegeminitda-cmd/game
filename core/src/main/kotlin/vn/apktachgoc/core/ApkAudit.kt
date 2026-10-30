package vn.apktachgoc.core

import com.reandroid.apk.ApkModule
import com.reandroid.arsc.chunk.xml.ResXmlElement
import com.reandroid.arsc.value.ValueType
import org.jf.dexlib2.Opcodes
import org.jf.dexlib2.dexbacked.DexBackedDexFile
import java.io.File
import java.security.MessageDigest
import java.util.zip.CRC32
import java.util.zip.ZipFile

data class AuditIssue(val location: String, val message: String, val warning: Boolean = false)
data class AuditReport(val issues: List<AuditIssue>, val errors: Int, val warnings: Int, val coverage: List<String>) {
    fun text(): String = buildString {
        append("KIỂM TRA TOÀN BỘ APK\nLỗi chặn: $errors; cảnh báo: $warnings.\n")
        append("Các kiểm tra độc lập tiếp tục sau lỗi; không tạo hay ký APK trong bước này.\n\n")
        coverage.forEach { append(it).append('\n') }
        append("\nDANH SÁCH PHÁT HIỆN\n")
        issues.forEachIndexed { index, issue ->
            if (length < 95000) append("${index + 1}. ${if (issue.warning) "CẢNH BÁO" else "LỖI"} [${issue.location}] ${issue.message}\n")
        }
        if (errors + warnings > issues.size || length >= 95000) append("Báo cáo vượt giới hạn hiển thị (500 phát hiện / khoảng 95.000 ký tự); các mục độc lập vẫn đã được quét, chi tiết dư được lược bớt.\n")
        append("\nKhông thể kết luận mọi lỗi chỉ bằng quét tĩnh. Giới hạn an toàn có thể ngăn đọc một mục hỏng/quá lớn; lỗi đóng gói/ký/chạy chỉ biết khi tới bước tương ứng. Native mã hóa/tạo định danh động, dịch vụ đăng nhập, DRM và chống gian lận chưa được xác nhận.\n")
    }
}

object ApkAudit {
    private const val ANDROID = "http://schemas.android.com/apk/res/android"
    fun scan(input: File, mode: Mode, target: String, label: String, progress: (Int, String) -> Unit = { _, _ -> }): AuditReport {
        val issues = mutableListOf<AuditIssue>(); val coverage = mutableListOf<String>()
        var errors = 0; var warnings = 0
        var contentScanReached = false
        val fallbackIdentifiers = linkedSetOf<String>()
        fun issue(location: String, message: String, warning: Boolean = false) {
            if (warning) warnings++ else errors++
            if (issues.size < 500) issues += AuditIssue(location.take(300), message.take(1200), warning)
        }
        fun attempt(location: String, action: () -> Unit) { try { action() } catch (e: Exception) { issue(location, e.message ?: e.javaClass.simpleName) } }
        progress(1, "Kiểm tra toàn bộ: ZIP và CRC từng mục")
        if (!input.isFile || input.length() !in 1..512L * 1024 * 1024) {
            issue("APK", "Không có tệp hợp lệ hoặc kích thước vượt 512 MB; không đọc nội dung để tránh vượt giới hạn.")
            return AuditReport(issues, errors, warnings, coverage)
        }
        var readable = true
        attempt("ZIP") {
            ZipFile(input).use { zip ->
                val entries = zip.entries().asSequence().take(40001).toList()
                coverage += "ZIP: ${entries.size} mục; APK ${input.length()} byte."
                if (entries.size > 40000) { issue("ZIP", "Vượt 40.000 mục; không đọc các cấu trúc cần giải nén."); readable = false }
                entries.groupingBy { it.name }.eachCount().filterValues { it > 1 }.forEach { (name, _) -> issue(name, "Trùng đường dẫn ZIP."); readable = false }
                entries.forEach { entry ->
                    if (entry.name.startsWith('/') || ".." in entry.name.split('/')) { issue(entry.name, "Đường dẫn ZIP không hợp lệ."); readable = false }
                    if (entry.size !in 0..200L * 1024 * 1024) { issue(entry.name, "Mục ZIP vượt 200 MB hoặc kích thước không xác định."); readable = false }
                    if (entry.name.endsWith(".apk", true)) issue(entry.name, "APK lồng nhau/APKS/XAPK cần bộ xử lý riêng.")
                }
                if (entries.sumOf { maxOf(0, it.size) } > 1024L * 1024 * 1024) { issue("ZIP", "Tổng giải nén vượt 1 GB; không đọc nội dung."); readable = false }
                if (zip.getEntry("AndroidManifest.xml") == null) { issue("AndroidManifest.xml", "Thiếu manifest của APK đơn."); readable = false }
                if (readable) {
                    var checked = 0
                    entries.filter { !it.isDirectory }.forEachIndexed { index, entry ->
                        if (index % 100 == 0) progress(2 + index * 20 / maxOf(1, entries.size), "Kiểm tra CRC ${index + 1}/${entries.size}")
                        attempt(entry.name) {
                            val crc = CRC32(); var size = 0L
                            zip.getInputStream(entry).use { stream ->
                                val b = ByteArray(65536)
                                while (true) { val n = stream.read(b); if (n < 0) break; size += n; require(size <= entry.size && size <= 200L * 1024 * 1024) { "Dữ liệu giải nén vượt kích thước đã khai báo." }; crc.update(b, 0, n) }
                            }
                            require(size == entry.size && crc.value == entry.crc) { "CRC hoặc kích thước không khớp." }
                            checked++
                        }
                    }
                    coverage += "Đã đọc/đối chiếu CRC: $checked/${entries.count { !it.isDirectory }} mục."
                }
            }
        }
        if (!readable) {
            coverage += "Các cấu trúc cần giải nén chưa được đọc vì ZIP vượt giới hạn hoặc không an toàn."
            return AuditReport(issues, errors, warnings, coverage)
        }
        progress(24, "Kiểm tra manifest và từng định danh")
        attempt("Manifest / resources.arsc") {
            ApkModule.loadApkFile(input).use { module ->
                val manifest = module.androidManifest ?: error("Không đọc được manifest.")
                val root = manifest.manifestElement ?: error("Thiếu phần tử manifest.")
                val all = listOf(root) + root.recursiveElements().asSequence().toList()
                val old = manifest.packageName.orEmpty()
                coverage += "Package nguồn: $old; version=${manifest.versionName} (${manifest.versionCode}); minSdk=${manifest.minSdkVersion}."
                if (!Regex("[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)+").matches(old)) issue("manifest package", "Package đầu vào không hợp lệ.")
                if (manifest.isSplit || root.searchAttributeByName("split") != null) issue("manifest", "Split APK chưa được ghép; cần APK đơn đầy đủ.")
                if (root.searchAttributeByName("sharedUserId") != null) issue("android:sharedUserId", "Shared UID chưa hỗ trợ đổi định danh/ký mới.")
                all.forEach { e ->
                    if (e.name in setOf("uses-split", "overlay", "instrumentation", "static-library", "sdk-library", "uses-static-library", "uses-sdk-library")) issue("<${e.name}>", "Cấu trúc chưa hỗ trợ trong APK đơn độc lập.")
                    if (e.searchAttributeByName("isSplitRequired")?.valueAsBoolean == true || e.searchAttributeByName("requiredSplitTypes") != null ||
                        (e.name == "meta-data" && e.searchAttributeByName("name")?.valueAsString == "com.android.vending.splits.required" && e.searchAttributeByName("value")?.data != 0)) issue("<${e.name}>", "Base APK yêu cầu split.")
                }
                if (module.hasTableBlock() && module.tableBlock.size() > 1) issue("resources.arsc", "Nhiều package tài nguyên chưa được hỗ trợ.")
                if (mode == Mode.CLONE) {
                    if (!ApkEngine.validPackage(target) || target == old) issue("Package đích", "Nhập package hợp lệ khác bản gốc.")
                    if (label.isBlank() || label.length > 80) issue("Tên bản sao", "Tên mới cần từ 1 đến 80 ký tự.")
                } else issue("Chế độ", "Ký lại giữ nguyên package; Android vẫn nhận cùng ứng dụng, không cài song song.", true)
                val mapping = linkedMapOf<String, String>()
                if (old.isNotBlank()) mapping[old] = target
                if (old.isNotBlank()) fallbackIdentifiers += old
                fun record(value: String, kind: String) {
                    val hash = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).take(6).joinToString("") { "%02x".format(it.toInt() and 255) }
                    mapping[value] = if (value == old || value.startsWith("$old.")) target + value.removePrefix(old) else "$target.$kind.$hash"
                    fallbackIdentifiers += value
                }
                fun literal(e: ResXmlElement, name: String): String? {
                    val a = e.searchAttribute(ANDROID, name) ?: return null
                    if (a.valueType != ValueType.STRING) { issue("<${e.name}> android:$name", "Kiểu ${a.valueType} / ${ResourceIdentifiers.hex(a.data)} chưa hỗ trợ ở định danh này."); return null }
                    return a.valueAsString
                }
                if (mode == Mode.CLONE) all.forEach { e ->
                    if (e.name == "provider") literal(e, "authorities")?.split(';')?.forEach { if (it.isBlank()) issue("provider", "Authority rỗng.") else record(it, "provider") }
                    if (e.name in setOf("permission", "permission-tree", "permission-group")) literal(e, "name")?.let { record(it, "permission") }
                    listOf("taskAffinity", "process").forEach { field -> literal(e, field)?.takeIf { it.isNotBlank() && !it.startsWith(':') }?.let { record(it, field.lowercase()) } }
                    if (e.name in setOf("action", "category")) literal(e, "name")?.takeIf { it.startsWith("$old.") }?.let { record(it, "intent") }
                    if (e.name == "data") literal(e, "scheme")?.takeIf { it == old || it.startsWith("$old.") }?.let { record(it, "scheme") }
                    val classFields = mutableSetOf<String>()
                    if (e.name in setOf("application", "activity", "service", "receiver", "provider")) classFields += "name"
                    if (e.name == "activity-alias") classFields += listOf("name", "targetActivity")
                    if (e.name == "activity") classFields += "parentActivityName"
                    if (e.name == "application") classFields += listOf("backupAgent", "manageSpaceActivity", "appComponentFactory", "zygotePreloadName")
                    classFields.forEach { literal(e, it) }
                }
                var xmlCount = 0
                if (mode == Mode.CLONE && module.hasTableBlock()) {
                    val xmlFiles = module.listResFiles().filter { it.isBinaryXml }
                    xmlFiles.forEachIndexed { index, resource ->
                        if (index % 20 == 0) progress(27 + index * 15 / maxOf(1, xmlFiles.size), "Kiểm tra XML ${index + 1}/${xmlFiles.size}: ${resource.filePath}")
                        attempt(resource.filePath) {
                            val xml = resource.readAsXmlDocument(); xmlCount++
                            xml.recursiveElements().asSequence().filter { it.name in setOf("account-authenticator", "sync-adapter") }.forEach { e ->
                                e.searchAttribute(ANDROID, "accountType")?.let { a ->
                                    ResourceIdentifiers.collect(module, a, resource.filePath) { issue("${resource.filePath} <${e.name}> android:accountType", it) }.forEach { record(it, "account") }
                                }
                            }
                        }
                    }
                    coverage += "XML nhị phân đã đọc: $xmlCount/${xmlFiles.size}; accountType gồm chuỗi, @string, bí danh và các cấu hình."
                }
                if (mapping.values.toSet().size != mapping.size) issue("Bảng định danh", "Một số định danh mới bị trùng; cần package khác hoặc bộ xử lý riêng.")
                contentScanReached = true
                val classes = hashSetOf<String>()
                var classCount = 0
                val dexFiles = module.zipEntryMap.toList().filter { Regex("classes([0-9]+)?\\.dex").matches(it.alias) }
                if (mode == Mode.CLONE && dexFiles.isEmpty()) issue("DEX", "Không có DEX tiêu chuẩn; chưa hỗ trợ APK này.")
                dexFiles.forEachIndexed { index, source ->
                    progress(43 + index * 15 / maxOf(1, dexFiles.size), "Kiểm tra DEX ${index + 1}/${dexFiles.size}: ${source.alias}")
                    attempt(source.alias) {
                        val dex = source.openStream().use { DexBackedDexFile.fromInputStream(Opcodes.getDefault(), it.buffered()) }
                        classCount += dex.classes.size
                        dex.classes.forEach { c -> classes += c.type; val binary = c.type.removePrefix("L").removeSuffix(";"); classes += binary; classes += binary.replace('/', '.') }
                    }
                }
                coverage += "Đã khảo sát ${dexFiles.size} DEX; $classCount lớp (namespace giữ nguyên)."
                if (mode == Mode.CLONE) {
                    val assets = module.zipEntryMap.toList().filter { it.alias.startsWith("assets/") || it.alias.startsWith("res/raw/") }
                    val needles = mapping.keys.filter { it.isNotEmpty() }.associateBy { it.toByteArray().toString(Charsets.ISO_8859_1) }
                    val longest = needles.keys.maxOfOrNull { it.length } ?: 1
                    assets.forEachIndexed { index, source ->
                        if (index % 100 == 0) progress(59 + index * 10 / maxOf(1, assets.size), "Kiểm tra asset/raw ${index + 1}/${assets.size}")
                        if (source.alias.endsWith(".dex", true) || source.alias.endsWith(".so", true)) issue(source.alias, "Mã nhúng cần bộ xử lý riêng.")
                        attempt(source.alias) {
                            val found = linkedSetOf<String>()
                            source.openStream().buffered().use { stream ->
                                val b = ByteArray(65536); var tail = ""
                                while (true) { val n = stream.read(b); if (n < 0) break; val text = tail + String(b, 0, n, Charsets.ISO_8859_1); needles.forEach { (raw, id) -> if (raw in text) found += id }; tail = text.takeLast(longest) }
                            }
                            if (found.isNotEmpty()) issue(source.alias, "Định danh trong asset/raw cần bộ xử lý theo định dạng: ${found.joinToString()}.")
                        }
                    }
                    coverage += "Asset/raw đã khảo sát: ${assets.size}."
                    attempt("Native") {
                        val count = NativeAudit.inspect(input, mapping.keys, classes, { location, message -> issue(location, message) }, { index, total, name -> progress(70 + index * 28 / maxOf(1, total), "Kiểm tra native $index/$total: $name") })
                        coverage += "Thư viện .so đã khảo sát: $count (ELF/ABI và định danh dạng rõ)."
                    }
                }
            }
        }
        if (!contentScanReached) {
            // A broken manifest/table must not prevent independent DEX, assets and
            // ELF checks. Only report identity matches whose values are known.
            issue("Phạm vi định danh", "Manifest/tài nguyên chưa đọc hết; vẫn kiểm tra độc lập các tệp. Các định danh chưa giải được không thể dùng để đối chiếu nội dung.", true)
            attempt("ZIP kiểm tra độc lập") {
                ZipFile(input).use { zip ->
                    val entries = zip.entries().asSequence().toList()
                    val classes = hashSetOf<String>()
                    val dexFiles = entries.filter { Regex("classes([0-9]+)?\\.dex").matches(it.name) }
                    dexFiles.forEachIndexed { index, entry ->
                        progress(45 + index * 15 / maxOf(1, dexFiles.size), "Kiểm tra DEX độc lập ${index + 1}/${dexFiles.size}: ${entry.name}")
                        attempt(entry.name) {
                            val dex = zip.getInputStream(entry).use { DexBackedDexFile.fromInputStream(Opcodes.getDefault(), it.buffered()) }
                            dex.classes.forEach { c -> classes += c.type; val binary = c.type.removePrefix("L").removeSuffix(";"); classes += binary; classes += binary.replace('/', '.') }
                        }
                    }
                    coverage += "DEX kiểm tra độc lập sau lỗi manifest/tài nguyên: ${dexFiles.size}."
                    if (mode == Mode.CLONE) {
                        val needles = fallbackIdentifiers.map { it.toByteArray().toString(Charsets.ISO_8859_1) }
                        val overlap = needles.maxOfOrNull { it.length } ?: 1
                        val assets = entries.filter { it.name.startsWith("assets/") || it.name.startsWith("res/raw/") }
                        assets.forEach { entry ->
                            if (entry.name.endsWith(".dex", true) || entry.name.endsWith(".so", true)) issue(entry.name, "Mã nhúng cần bộ xử lý riêng.")
                            attempt(entry.name) {
                                var matched = false
                                zip.getInputStream(entry).buffered().use { stream ->
                                    val b = ByteArray(65536); var tail = ""
                                    while (true) { val n = stream.read(b); if (n < 0) break; val text = tail + String(b, 0, n, Charsets.ISO_8859_1); if (needles.any { it in text }) matched = true; tail = text.takeLast(overlap) }
                                }
                                if (matched) issue(entry.name, "Chứa định danh đã biết; cần bộ xử lý theo định dạng.")
                            }
                        }
                        coverage += "Asset/raw kiểm tra độc lập: ${assets.size}; định danh chưa biết không được suy đoán."
                        val count = NativeAudit.inspect(input, fallbackIdentifiers, classes, { location, message -> issue(location, message) }, { index, total, name -> progress(70 + index * 28 / maxOf(1, total), "Kiểm tra native độc lập $index/$total: $name") })
                        coverage += "Thư viện .so kiểm tra độc lập: $count (ELF/ABI và các định danh đã biết)."
                    }
                }
            }
        }
        issue("Giới hạn chạy thử", "Quét cấu trúc không xác nhận game/đăng nhập/DRM chạy sau khi đổi package hoặc ký.", true)
        progress(100, "Đã kiểm tra: $errors lỗi chặn, $warnings cảnh báo")
        return AuditReport(issues, errors, warnings, coverage)
    }
}
