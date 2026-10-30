package vn.apktachgoc.core

import com.reandroid.apk.ApkModule
import com.reandroid.arsc.value.ValueType
import java.io.File
import java.util.zip.ZipFile

/** Bounded structural summary only: no asset contents, signing keys or accounts. */
object ApkDiagnostics {
    fun describe(file: File): String {
        val report = StringBuilder()
        fun line(value: String) { if (report.length < 22000) report.append(value.take(1800)).append('\n') }
        try {
            ZipFile(file).use { zip ->
                val entries = zip.entries().asSequence().take(40001).toList()
                line("Mục ZIP: ${entries.size}; dung lượng giải nén: ${entries.sumOf { maxOf(0, it.size) }} byte")
                require(entries.size <= 40000 && entries.all { it.size in 0..200L * 1024 * 1024 } && entries.sumOf { it.size } <= 1024L * 1024 * 1024) { "ZIP vượt giới hạn kiểm tra cấu trúc." }
                val dex = entries.filter { Regex("classes([0-9]+)?\\.dex").matches(it.name) }
                line("DEX tiêu chuẩn: ${dex.size}; ${dex.take(30).joinToString { "${it.name} (${it.size} byte)" }}")
                val native = entries.filter { it.name.endsWith(".so", true) }
                line("Thư viện native: ${native.size}; ABI: ${native.map { it.name.split('/').getOrNull(1) ?: "không rõ" }.distinct().joinToString()}")
                native.take(100).forEach { line("  ${it.name} (${it.size} byte; ZIP method=${it.method})") }
                if (native.size > 100) line("  ... lược bớt ${native.size - 100} thư viện")
                val packed = entries.filter { it.name.endsWith(".apk", true) || (it.name.startsWith("assets/") && it.name.endsWith(".dex", true)) }
                if (packed.isNotEmpty()) line("Mã/gói nhúng cần bộ xử lý riêng: ${packed.take(30).joinToString { it.name }}")
            }
            ApkModule.loadApkFile(file).use { module ->
                val manifest = module.androidManifest ?: error("Không đọc được manifest.")
                val root = manifest.manifestElement
                line("Manifest: package=${manifest.packageName}; version=${manifest.versionName} (${manifest.versionCode}); minSdk=${manifest.minSdkVersion}; split=${manifest.isSplit}")
                listOf("split", "sharedUserId", "requiredSplitTypes").forEach { name -> root.searchAttributeByName(name)?.let { line("manifest $name: ${it.valueType} / ${it.valueAsString ?: it.data}") } }
                line("Package tài nguyên: ${if (module.hasTableBlock()) module.tableBlock.size() else 0}")
                val all = root.recursiveElements().asSequence().toList()
                listOf("activity", "service", "receiver", "provider", "uses-split", "overlay", "instrumentation").forEach { tag -> line("$tag: ${all.count { it.name == tag }}") }
                all.filter { it.name == "provider" }.take(30).forEach { e -> e.searchAttributeByName("authorities")?.let { line("Provider authority: ${it.valueType} / ${it.valueAsString ?: ResourceIdentifiers.hex(it.data)}") } }
                if (module.hasTableBlock()) {
                    val xmlFiles = module.listResFiles().filter { it.isBinaryXml }
                    var accounts = 0
                    xmlFiles.take(128).forEach { resource ->
                        try {
                            val xml = resource.readAsXmlDocument()
                            xml.recursiveElements().asSequence().filter { it.name in setOf("account-authenticator", "sync-adapter") }.forEach { e ->
                                accounts++
                                val a = e.searchAttributeByName("accountType")
                                if (a == null) line("${resource.filePath} <${e.name}>: thiếu accountType")
                                else {
                                    line("${resource.filePath} <${e.name}> android:accountType: ${a.valueType} / ${if (a.valueType == ValueType.STRING) a.valueAsString else ResourceIdentifiers.hex(a.data)}")
                                    try { line("  Giá trị định danh: ${ResourceIdentifiers.values(module, a, resource.filePath).joinToString()}") }
                                    catch (e: Exception) { line("  Cần xử lý: ${e.message}") }
                                }
                            }
                        } catch (e: Exception) { line("Không đọc được XML ${resource.filePath}: ${e.message}") }
                    }
                    line("Đã khảo sát ${minOf(xmlFiles.size, 128)}/${xmlFiles.size} XML; authenticator/sync tìm thấy: $accounts.")
                    if (xmlFiles.size > 128) line("Phần khảo sát XML đã giới hạn; lỗi của bước xử lý vẫn ghi tệp cụ thể trong lịch sử.")
                }
            }
        } catch (e: Exception) { line("Khảo sát chưa hoàn tất: ${e.javaClass.simpleName}: ${e.message}") }
        line("Đây là chẩn đoán cấu trúc, không xác nhận app/game chạy được. Native có định danh mã hóa/tạo động, DRM hoặc kiểm tra chữ ký có thể cần xử lý riêng.")
        return report.toString().take(24576)
    }
}
