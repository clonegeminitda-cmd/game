package vn.apktachgoc.core

import com.android.apksig.ApkSigner
import com.android.apksig.ApkVerifier
import com.reandroid.apk.ApkModule
import com.reandroid.archive.ByteInputSource
import com.reandroid.archive.writer.ZipAligner
import com.reandroid.arsc.chunk.xml.ResXmlElement
import com.reandroid.arsc.value.ValueType
import org.jf.dexlib2.Opcode
import org.jf.dexlib2.Opcodes
import org.jf.dexlib2.dexbacked.DexBackedDexFile
import org.jf.dexlib2.iface.instruction.Instruction
import org.jf.dexlib2.iface.instruction.ReferenceInstruction
import org.jf.dexlib2.iface.instruction.OneRegisterInstruction
import org.jf.dexlib2.iface.reference.StringReference
import org.jf.dexlib2.iface.value.EncodedValue
import org.jf.dexlib2.iface.value.StringEncodedValue
import org.jf.dexlib2.immutable.instruction.ImmutableInstruction21c
import org.jf.dexlib2.immutable.instruction.ImmutableInstruction31c
import org.jf.dexlib2.immutable.reference.ImmutableStringReference
import org.jf.dexlib2.immutable.value.ImmutableStringEncodedValue
import org.jf.dexlib2.rewriter.*
import org.jf.dexlib2.writer.io.MemoryDataStore
import org.jf.dexlib2.writer.pool.DexPool
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

data class ApkInfo(val packageName: String, val versionName: String, val versionCode: Int, val minSdk: Int, val nativeCode: Boolean)
enum class Mode { RESIGN, CLONE }
data class BuildReport(val file: File, val packageName: String, val sha256: String, val changes: List<String>, val certificateSha256: String, val mode: Mode = Mode.RESIGN)

object ApkEngine {
    private const val ANDROID = "http://schemas.android.com/apk/res/android"
    private val packageRegex = Regex("[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+")
    fun validPackage(name: String) = name.length in 5..180 && packageRegex.matches(name) && !name.startsWith("android.") && !name.startsWith("java.")
    fun sha256(file: File): String = file.inputStream().use { stream ->
        val md = MessageDigest.getInstance("SHA-256"); val buffer = ByteArray(65536)
        while (true) { val n = stream.read(buffer); if (n < 0) break; md.update(buffer, 0, n) }
        md.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
    }
    private fun elements(root: ResXmlElement): List<ResXmlElement> = listOf(root) + root.recursiveElements().asSequence().toList()
    private fun attr(element: ResXmlElement, name: String) = element.searchAttribute(ANDROID, name)
    private fun string(element: ResXmlElement, name: String): String? {
        val a = attr(element, name) ?: return null
        require(a.valueType == ValueType.STRING) { "Định danh android:$name dùng tham chiếu tài nguyên; bản đầu chưa hỗ trợ." }
        return a.valueAsString
    }
    private fun guardZip(file: File): Boolean {
        require(file.length() in 1..(512L * 1024 * 1024)) { "APK rỗng hoặc lớn hơn 512 MB." }
        ZipFile(file).use { zip ->
            val entries = zip.entries().toList()
            require(entries.size <= 40000 && entries.map { it.name }.toSet().size == entries.size) { "ZIP quá nhiều mục hoặc trùng tên mục." }
            require(entries.none { it.name.startsWith("/") || it.name.split('/').contains("..") }) { "ZIP có đường dẫn không hợp lệ." }
            require(entries.all { it.size >= 0 && it.size <= 200L * 1024 * 1024 } && entries.sumOf { it.size } <= 1024L * 1024 * 1024) { "APK vượt giới hạn giải nén an toàn (mục 200 MB / tổng 1 GB)." }
            require(zip.getEntry("AndroidManifest.xml") != null) { "Không phải APK đơn: thiếu AndroidManifest.xml. Không nhận APKS/XAPK/AAB." }
            require(entries.none { it.name.endsWith(".apk", true) }) { "Gói chứa APK lồng nhau; chưa hỗ trợ." }
            return entries.any { it.name.endsWith(".so", true) }
        }
    }
    fun inspect(file: File): ApkInfo {
        val native = guardZip(file)
        ApkModule.loadApkFile(file).use { module ->
            val manifest = module.androidManifest ?: error("Manifest nhị phân không đọc được.")
            val root = manifest.manifestElement ?: error("Thiếu phần tử manifest.")
            val all = elements(root)
            require(!manifest.isSplit && root.searchAttributeByName("split") == null && all.none {
                it.name == "uses-split" || attr(it, "isSplitRequired")?.valueAsBoolean == true ||
                attr(it, "requiredSplitTypes") != null ||
                (it.name == "meta-data" && attr(it, "name")?.valueAsString == "com.android.vending.splits.required" && attr(it, "value")?.data != 0)
            }) { "Đây là split APK hoặc base APK cần split. Hãy chọn APK đơn đầy đủ; bản đầu chưa ghép split." }
            require(attr(root, "sharedUserId") == null) { "APK dùng sharedUserId; ký mới có thể xung đột UID. Chưa hỗ trợ." }
            require(all.none { it.name in setOf("overlay", "instrumentation", "static-library", "sdk-library", "uses-static-library", "uses-sdk-library") }) { "APK hệ thống, overlay, instrumentation hoặc thư viện chia sẻ chưa được hỗ trợ." }
            require(module.hasTableBlock().not() || module.tableBlock.size() <= 1) { "APK có nhiều package tài nguyên; chưa hỗ trợ." }
            val pkg = manifest.packageName ?: error("Thiếu package name.")
            require(pkg.length in 3..223 && Regex("[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)+").matches(pkg)) { "Package của APK đầu vào không hợp lệ; không thể tạo APK cài được." }
            return ApkInfo(pkg, manifest.versionName ?: "?", manifest.versionCode ?: 0, manifest.minSdkVersion ?: 1, native)
        }
    }
    fun build(input: File, output: File, mode: Mode, newPackage: String, label: String, identity: SigningIdentity, progress: (Int, String) -> Unit = { _, _ -> }): BuildReport {
        require(input.canonicalPath != output.canonicalPath) { "Không được ghi đè APK đầu vào." }
        progress(5, "Kiểm tra APK đầu vào")
        val originalHash = sha256(input)
        val info = inspect(input)
        if (mode == Mode.CLONE) {
            require(validPackage(newPackage) && newPackage != info.packageName) { "Package mới phải khác bản gốc, gồm các đoạn chữ thường, số, dấu gạch dưới, phân cách bằng dấu chấm." }
            require(label.isNotBlank() && label.length <= 80) { "Tên bản sao cần từ 1 đến 80 ký tự." }
        }
        val target = if (mode == Mode.CLONE) newPackage else info.packageName
        val changes = mutableListOf<String>()
        if (mode == Mode.RESIGN) changes += "Ký lại APK: giữ nguyên package ${info.packageName}; không tạo bản cài song song."
        else changes += "Tách gốc: package mới $target, cài riêng với ${info.packageName}; dữ liệu và UID do Android cấp riêng."
        val temp = File(output.parentFile, output.name + ".unsigned")
        val pending = File(output.parentFile, output.name + ".pending")
        output.parentFile?.mkdirs()
        try {
            ApkModule.loadApkFile(input).use { module ->
                module.setApkSignatureBlock(null)
                module.zipEntryMap.toList().filter { source ->
                    val name = source.alias.uppercase()
                    name == "META-INF/MANIFEST.MF" || (name.startsWith("META-INF/") && (name.endsWith(".SF") || name.endsWith(".RSA") || name.endsWith(".DSA") || name.endsWith(".EC") || name.substringAfterLast('/').startsWith("SIG-")))
                }.forEach { module.zipEntryMap.remove(it) }
                if (mode == Mode.CLONE) rewrite(module, input, info.packageName, newPackage, label, changes, progress)
                progress(65, "Đóng gói và căn chỉnh ZIP")
                module.createApkFileWriter(temp).apply {
                    zipAligner = ZipAligner().apply { setDefaultAlignment(4); setFileAlignment(java.util.function.Predicate { it.endsWith(".so", true) }, 16384) }
                }.write()
            }
            progress(78, "Ký APK v1 / v2 / v3")
            val signer = ApkSigner.SignerConfig.Builder("APK Tach Goc", identity.key, listOf(identity.certificate)).build()
            ApkSigner.Builder(listOf(signer)).setInputApk(temp).setOutputApk(pending)
                .setMinSdkVersion(maxOf(26, info.minSdk)).setV1SigningEnabled(true).setV2SigningEnabled(true)
                .setV3SigningEnabled(true).setV4SigningEnabled(false).setOtherSignersSignaturesPreserved(false).build().sign()
            progress(90, "Xác minh chữ ký và cấu trúc đầu ra")
            val result = ApkVerifier.Builder(pending).setMinCheckedPlatformVersion(maxOf(26, info.minSdk)).build().verify()
            require(result.isVerified && result.isVerifiedUsingV2Scheme && result.signerCertificates.any { it.encoded.contentEquals(identity.certificate.encoded) }) { "Chữ ký APK không hợp lệ: ${result.errors.joinToString()}" }
            val finalInfo = inspect(pending)
            require(finalInfo.packageName == target && finalInfo.versionCode == info.versionCode) { "Package hoặc phiên bản đầu ra không khớp." }
            ZipFile(pending).use { zip -> zip.entries().asSequence().filter { !it.isDirectory }.forEach { entry ->
                val crc = java.util.zip.CRC32()
                zip.getInputStream(entry).use { stream -> val b = ByteArray(65536); while (true) { val n = stream.read(b); if (n < 0) break; crc.update(b, 0, n) } }
                require(crc.value == entry.crc) { "CRC không khớp: ${entry.name}" }
            } }
            if (info.nativeCode) {
                progress(94, "Đối chiếu SHA-256 từng thư viện native (.so)")
                val nativeCount = verifyNativePreserved(input, pending)
                changes += "Đã đối chiếu SHA-256: giữ nguyên nội dung $nativeCount thư viện .so, căn chỉnh ZIP cho thư viện không nén ở biên 16 KB."
            }
            require(sha256(input) == originalHash) { "APK đầu vào đã thay đổi trong lúc xử lý." }
            require(!output.exists()) { "Tên đầu ra đã tồn tại; hãy tạo tên khác." }
            require(pending.renameTo(output)) { "Không thể hoàn tất tệp đầu ra." }
            progress(100, "Đã xác minh APK; cần cài thử để kiểm tra hành vi ứng dụng")
            return BuildReport(output, target, sha256(output), changes, identity.fingerprint, mode)
        } finally { temp.delete(); pending.delete() }
    }
    private fun verifyNativePreserved(input: File, signed: File): Int = ZipFile(input).use { original ->
        ZipFile(signed).use { result ->
            fun names(zip: ZipFile) = zip.entries().asSequence().filter { !it.isDirectory && it.name.endsWith(".so", true) }.map { it.name }.toSet()
            val expected = names(original)
            require(names(result) == expected) { "Danh sách thư viện native bị thay đổi; không xuất APK." }
            fun hash(zip: ZipFile, name: String): ByteArray = zip.getInputStream(zip.getEntry(name)).use { stream ->
                val digest = MessageDigest.getInstance("SHA-256"); val buffer = ByteArray(65536)
                while (true) { val count = stream.read(buffer); if (count < 0) break; digest.update(buffer, 0, count) }
                digest.digest()
            }
            expected.forEach { name -> require(MessageDigest.isEqual(hash(original, name), hash(result, name))) { "Thư viện $name đã thay đổi ngoài dự kiến; không xuất APK." } }
            expected.size
        }
    }
    private fun rewrite(module: ApkModule, input: File, old: String, new: String, label: String, changes: MutableList<String>, progress: (Int, String) -> Unit) {
        val manifest = module.androidManifest
        val root = manifest.manifestElement
        val all = elements(root)
        val mapping = linkedMapOf(old to new)
        fun ownedId(value: String, kind: String): String = if (value == old || value.startsWith("$old.")) new + value.removePrefix(old) else "$new.$kind.${digest(value)}"
        fun record(value: String, kind: String) { mapping[value] = ownedId(value, kind) }
        progress(15, "Lập bảng định danh riêng cho bản sao")
        all.forEach { e ->
            if (e.name == "provider") string(e, "authorities")?.split(';')?.forEach { require(it.isNotBlank()) { "Provider authority rỗng." }; record(it, "provider") }
            if (e.name in setOf("permission", "permission-tree", "permission-group")) string(e, "name")?.let { record(it, "permission") }
            for (field in listOf("taskAffinity", "process")) string(e, field)?.takeIf { it.isNotBlank() && !it.startsWith(":") }?.let { record(it, field.lowercase()) }
            if (e.name in setOf("action", "category")) string(e, "name")?.takeIf { it.startsWith("$old.") }?.let { record(it, "intent") }
            if (e.name == "data") string(e, "scheme")?.takeIf { it == old || it.startsWith("$old.") }?.let { record(it, "scheme") }
        }
        val resourceXml = if (module.hasTableBlock()) module.listResFiles().filter { it.isBinaryXml }.map { it to it.readAsXmlDocument() } else emptyList()
        resourceXml.forEach { (file, xml) ->
            xml.recursiveElements().asSequence().forEach { e ->
                if (e.name in setOf("account-authenticator", "sync-adapter")) attr(e, "accountType")?.let { a ->
                    ResourceIdentifiers.values(module, a, "${file.filePath} <${e.name}>").forEach { record(it, "account") }
                    if (a.valueType == ValueType.REFERENCE) changes += "${file.filePath}: android:accountType ${ResourceIdentifiers.hex(a.data)} đã giải tham chiếu @string/bí danh theo mọi cấu hình."
                }
            }
        }
        require(mapping.values.toSet().size == mapping.size) { "Định danh mới bị trùng sau ánh xạ; hãy dùng package khác." }
        // Class names stay in their original DEX namespace. Expand relative names BEFORE changing the manifest package.
        val classTags = setOf("application", "activity", "activity-alias", "service", "receiver", "provider")
        all.forEach { e ->
            val classFields = mutableSetOf<String>()
            if (e.name in classTags && e.name != "activity-alias") classFields += "name"
            if (e.name == "activity-alias") classFields += listOf("name", "targetActivity")
            if (e.name == "activity") classFields += "parentActivityName"
            if (e.name == "application") classFields += listOf("backupAgent", "manageSpaceActivity", "appComponentFactory", "zygotePreloadName")
            e.attributes.asSequence().toList().forEach { a ->
                if (a.uri == ANDROID && a.name in classFields) {
                    require(a.valueType == ValueType.STRING) { "Tên lớp ${a.name} qua tài nguyên chưa được hỗ trợ." }
                    val value = a.valueAsString
                    a.setValueAsString(if (value.startsWith('.')) old + value else if ('.' !in value) "$old.$value" else value)
                } else if (a.valueType == ValueType.STRING) {
                    val value = a.valueAsString
                    val replaced = if (a.name == "authorities" && e.name == "provider") value.split(';').joinToString(";") { mapping[it] ?: it } else rewriteValue(value, mapping)
                    if (value != replaced) a.setValueAsString(replaced)
                }
            }
        }
        manifest.setPackageName(new)
        manifest.setApplicationLabel(label)
        all.filter { it.name == "activity" || it.name == "activity-alias" }.forEach { e ->
            if (e.elements.asSequence().any { it.name == "intent-filter" && it.elements.asSequence().any { child -> child.name == "category" && attr(child, "name")?.valueAsString == "android.intent.category.LAUNCHER" } }) {
                e.getOrCreateAndroidAttribute("label", 0x01010001).setValueAsString(label)
            }
        }
        // Leave resources' Java class names intact; change only package metadata and exact known identifier values.
        if (module.hasTableBlock()) {
            module.tableBlock.listPackages().forEach { it.setName(new) }
            module.tableBlock.tableStringPool.iterator().asSequence().toList().forEach { s ->
                val value = s.get(); val replaced = rewriteValue(value, mapping)
                if (replaced != value) s.set(replaced)
            }
            resourceXml.forEach { (file, xml) ->
                xml.recursiveAttributes().asSequence().forEach { a ->
                    if (a.valueType == ValueType.STRING) { val value = a.valueAsString; val replaced = rewriteValue(value, mapping); if (value != replaced) a.setValueAsString(replaced) }
                }
                xml.refreshFull()
                module.zipEntryMap.add(ByteInputSource(xml.bytes, file.filePath))
            }
            module.tableBlock.refresh()
        }
        manifest.refreshFull()
        val dexFiles = module.zipEntryMap.toList().filter { Regex("classes([0-9]+)?\\.dex").matches(it.alias) }
        require(dexFiles.isNotEmpty()) { "Không có DEX tiêu chuẩn; bản đầu chưa hỗ trợ APK này." }
        val classNames = hashSetOf<String>()
        dexFiles.forEachIndexed { i, source ->
            progress(25 + i * 30 / dexFiles.size, "Xử lý DEX ${i + 1}/${dexFiles.size}")
            val dex = source.openStream().use { DexBackedDexFile.fromInputStream(Opcodes.getDefault(), it.buffered()) }
            dex.classes.forEach { c ->
                classNames += c.type
                val binary = c.type.removePrefix("L").removeSuffix(";")
                classNames += binary; classNames += binary.replace('/', '.')
            }
            // Most library-only DEX files contain no app identifiers. Preserve their exact bytes.
            if (dex.stringReferences.none { rewriteValue(it.string, mapping) != it.string }) return@forEachIndexed
            val rewriter = DexRewriter(object : RewriterModule() {
                override fun getInstructionRewriter(rewriters: Rewriters): Rewriter<Instruction> = object : InstructionRewriter(rewriters) {
                    override fun rewrite(value: Instruction): Instruction {
                        if (value.opcode == Opcode.CONST_STRING || value.opcode == Opcode.CONST_STRING_JUMBO) {
                            val before = ((value as ReferenceInstruction).reference as StringReference).string
                            val after = rewriteValue(before, mapping)
                            if (before != after) {
                                val register = (value as OneRegisterInstruction).registerA
                                return if (value.opcode == Opcode.CONST_STRING) ImmutableInstruction21c(Opcode.CONST_STRING, register, ImmutableStringReference(after)) else ImmutableInstruction31c(Opcode.CONST_STRING_JUMBO, register, ImmutableStringReference(after))
                            }
                        }
                        return super.rewrite(value)
                    }
                }
                override fun getEncodedValueRewriter(rewriters: Rewriters): Rewriter<EncodedValue> = object : EncodedValueRewriter(rewriters) {
                    override fun rewrite(value: EncodedValue): EncodedValue = if (value is StringEncodedValue) ImmutableStringEncodedValue(rewriteValue(value.value, mapping)) else super.rewrite(value)
                }
            }).dexFileRewriter.rewrite(dex)
            val store = MemoryDataStore()
            DexPool.writeTo(store, rewriter)
            // Parse again to reject DEX encoding errors, without modifying class descriptors.
            val bytes = store.data
            val verifiedDex = DexBackedDexFile(Opcodes.getDefault(), bytes)
            require(verifiedDex.classes.size == dex.classes.size) { "Số lớp DEX thay đổi ngoài dự kiến." }
            module.zipEntryMap.add(ByteInputSource(bytes, source.alias))
        }
        progress(58, "Kiểm tra ELF và định danh trong thư viện native")
        val nativeCount = NativeAudit.check(input, mapping.keys, classNames)
        if (nativeCount > 0) changes += "Native: đã kiểm tra $nativeCount tệp ELF; giữ nguyên tên lớp JNI và toàn bộ byte .so. Kiểm tra tĩnh chỉ phát hiện tham chiếu định danh dạng rõ, không chứng minh game chạy được."
        // Packed code and text assets with original identifiers need format-specific handling. Fail closed.
        module.zipEntryMap.toList().filter { it.alias.startsWith("assets/") || it.alias.startsWith("res/raw/") }.forEach { source ->
            val bytes = source.openStream().use { it.readBytes() }
            require(!source.alias.endsWith(".dex", true) && !source.alias.endsWith(".so", true)) { "Mã nhúng trong ${source.alias}; chưa hỗ trợ." }
            val text = bytes.toString(Charsets.ISO_8859_1)
            require(mapping.keys.none { it in text }) { "Tệp ${source.alias} chứa định danh gốc; cần bộ xử lý riêng cho định dạng này. Không xuất APK có tham chiếu chưa xử lý." }
        }
        mapping.forEach { (from, to) -> changes += "$from → $to" }
        changes += "Tên hiển thị → $label; giữ nguyên namespace lớp DEX; mở rộng tên lớp tương đối."
    }
    private fun digest(value: String) = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).take(6).joinToString("") { "%02x".format(it.toInt() and 255) }
    private fun rewriteValue(value: String, mapping: Map<String, String>): String {
        mapping[value]?.let { return it }
        // A content URI has an authority boundary, so replacing that token cannot change a class name or arbitrary text.
        if (value.startsWith("content://")) {
            val authority = value.removePrefix("content://").takeWhile { it != '/' && it != '?' && it != '#' }
            mapping[authority]?.let { return "content://" + it + value.removePrefix("content://$authority") }
        }
        return value
    }
}
