package vn.apktachgoc.core

import com.android.apksig.ApkVerifier
import com.reandroid.apk.ApkModule
import com.reandroid.archive.ByteInputSource
import org.jf.dexlib2.Opcodes
import org.jf.dexlib2.dexbacked.DexBackedDexFile
import org.jf.dexlib2.iface.instruction.ReferenceInstruction
import org.jf.dexlib2.iface.reference.StringReference
import java.io.File
import java.util.zip.ZipFile
import kotlin.test.*
import org.junit.Test

class EngineTest {
    private val sample = File(System.getProperty("sampleApk"))
    private val nativeSample = File(System.getProperty("nativeApk"))
    private val out = File("build/test-artifacts").apply { mkdirs() }
    private val identity by lazy { SigningKeys.create() }
    private val original = "vn.apktachgoc.sample"
    private val target = "vn.apktachgoc.sample.tachgoc"
    private fun fresh(name: String) = File(out, name).apply { delete() }
    private fun variant(name: String, edit: (ApkModule) -> Unit): File = fresh(name).also { file ->
        ApkModule.loadApkFile(sample).use { module -> module.setApkSignatureBlock(null); edit(module); module.writeApk(file) }
    }
    private fun nativeVariant(name: String, bytes: ByteArray): File = fresh(name).also { file ->
        ApkModule.loadApkFile(nativeSample).use { module ->
            module.setApkSignatureBlock(null)
            module.zipEntryMap.add(ByteInputSource(bytes, "lib/x86_64/libnativefixture.so")); module.writeApk(file)
        }
    }
    @Test fun cloneRealNativeApkKeepsJniNamespaceAndLibrary() {
        val before = ApkEngine.sha256(nativeSample)
        val file = fresh("native-clone.apk")
        val target = "vn.apktachgoc.nativesample.tachgoc"
        val report = ApkEngine.build(nativeSample, file, Mode.CLONE, target, "Native • Bản riêng", identity)
        assertEquals(target, ApkEngine.inspect(file).packageName)
        assertEquals(Mode.CLONE, report.mode)
        assertEquals(before, ApkEngine.sha256(nativeSample))
        ApkModule.loadApkFile(file).use { module ->
            assertEquals("vn.apktachgoc.nativesample.MainActivity", module.androidManifest.manifestElement.recursiveElements().asSequence().first { it.name == "activity" }.searchAttributeByName("name").valueAsString)
        }
        ZipFile(nativeSample).use { a -> ZipFile(file).use { b ->
            val name = "lib/x86_64/libnativefixture.so"
            assertContentEquals(a.getInputStream(a.getEntry(name)).readBytes(), b.getInputStream(b.getEntry(name)).readBytes())
        } }
        assertTrue(ApkVerifier.Builder(file).build().verify().isVerified)
        assertTrue(report.changes.any { it.startsWith("Native:") })
        assertTrue(report.changes.any { it.contains("SHA-256") })
    }
    @Test fun rejectsNativeIdentifiersAcrossChunksAndEncodingsWithoutOutput() {
        val base = ZipFile(nativeSample).use { it.getInputStream(it.getEntry("lib/x86_64/libnativefixture.so")).readBytes() }
        listOf(Charsets.UTF_8, Charsets.UTF_16LE, Charsets.UTF_16BE).forEachIndexed { index, charset ->
            val id = "vn.apktachgoc.nativesample"
            // Force a match crossing a streaming chunk, including odd UTF-16 alignment.
            val bytes = base + ByteArray(65530 - base.size) + id.toByteArray(charset) + ByteArray(9000)
            val input = nativeVariant("native-id-$index.apk", bytes)
            val output = fresh("must-not-exist-native-id-$index.apk")
            val error = assertFails { ApkEngine.build(input, output, Mode.CLONE, "$id.tachgoc", "X", identity) }
            assertTrue(error.message.orEmpty().contains("phát hiện định danh"), error.message)
            assertFalse(output.exists()); assertFalse(File(output.path + ".pending").exists()); assertFalse(File(output.path + ".unsigned").exists())
        }
    }
    @Test fun cloneRealSampleAndVerifyReferences() {
        val before = ApkEngine.sha256(sample)
        val file = fresh("sample-clone.apk")
        val report = ApkEngine.build(sample, file, Mode.CLONE, target, "Mẫu • Bản riêng", identity)
        assertEquals(before, ApkEngine.sha256(sample))
        assertEquals(target, ApkEngine.inspect(file).packageName)
        assertTrue(ApkVerifier.Builder(file).build().verify().isVerified)
        assertTrue(report.changes.any { it.startsWith("fixed.sample.authority → $target.provider.") })
        ApkModule.loadApkFile(file).use { module ->
            val manifest = module.androidManifest
            val elements = manifest.manifestElement.recursiveElements().asSequence().toList()
            val activity = elements.first { it.name == "activity" }
            assertEquals("$original.MainActivity", activity.searchAttributeByName("name").valueAsString)
            assertEquals("Mẫu • Bản riêng", activity.searchAttributeByName("label").valueAsString)
            assertEquals(target, activity.searchAttributeByName("taskAffinity").valueAsString)
            val provider = elements.first { it.name == "provider" }
            val authorities = provider.searchAttributeByName("authorities").valueAsString.split(';')
            assertEquals("$target.notes", authorities[0]); assertTrue(authorities[1].startsWith("$target.provider."))
            assertEquals("$target.permission.PRIVATE", elements.first { it.name == "permission" }.searchAttributeByName("name").valueAsString)
            assertEquals("$target.permission.PRIVATE", elements.first { it.name == "uses-permission" }.searchAttributeByName("name").valueAsString)
            assertEquals(target, module.tableBlock.pickOne().name)
            val strings = module.tableBlock.tableStringPool.strings.asSequence().toList()
            assertTrue(target in strings); assertTrue("$original.MainActivity" in strings)
            assertTrue("content://$target.notes/session" in strings)
        }
        ZipFile(file).use { zip ->
            ZipFile(sample).use { source -> assertContentEquals(source.getInputStream(source.getEntry("classes.dex")).readBytes(), zip.getInputStream(zip.getEntry("classes.dex")).readBytes(), "DEX thư viện không có định danh cần đổi phải giữ nguyên byte") }
            val dexFiles = zip.entries().asSequence().filter { Regex("classes([0-9]+)?\\.dex").matches(it.name) }.map { entry -> zip.getInputStream(entry).use { DexBackedDexFile.fromInputStream(Opcodes.getDefault(), it.buffered()) } }.toList()
            val classes = dexFiles.flatMap { it.classes.toList() }
            val strings = classes.flatMap { it.methods.toList() }.flatMap { it.implementation?.instructions?.toList() ?: emptyList() }
                .filterIsInstance<ReferenceInstruction>().mapNotNull { (it.reference as? StringReference)?.string }
            assertTrue("content://$target.notes/session" in strings)
            assertTrue(target in strings)
            assertTrue(classes.any { it.type == "Lvn/apktachgoc/sample/MainActivity;" })
        }
        sample.copyTo(File(out, "sample-original.apk"), overwrite = true)
    }
    @Test fun resignPreservesPackageAndDex() {
        val file = fresh("sample-resigned.apk")
        ApkEngine.build(sample, file, Mode.RESIGN, "", "", identity)
        assertEquals(original, ApkEngine.inspect(file).packageName)
        ZipFile(sample).use { a -> ZipFile(file).use { b -> assertContentEquals(a.getInputStream(a.getEntry("classes.dex")).readBytes(), b.getInputStream(b.getEntry("classes.dex")).readBytes()) } }
    }
    @Test fun resignRealNativeApkPreservesElfAndEveryDex() {
        val input = File(System.getProperty("nativeApk"))
        val before = ApkEngine.sha256(input)
        val info = ApkEngine.inspect(input)
        assertTrue(info.nativeCode)
        val output = fresh("native-resigned.apk")
        val report = ApkEngine.build(input, output, Mode.RESIGN, "", "", identity)
        assertEquals(info.packageName, ApkEngine.inspect(output).packageName)
        assertEquals(before, ApkEngine.sha256(input))
        ZipFile(input).use { original -> ZipFile(output).use { signed ->
            val names = original.entries().asSequence().map { it.name }.filter { it.endsWith(".so") || Regex("classes([0-9]+)?\\.dex").matches(it) }.toList()
            assertTrue(names.any { it.endsWith(".so") })
            names.forEach { name -> assertContentEquals(original.getInputStream(original.getEntry(name)).readBytes(), signed.getInputStream(signed.getEntry(name)).readBytes(), name) }
            assertEquals(java.util.zip.ZipEntry.STORED, signed.getEntry("lib/x86_64/libnativefixture.so").method)
        } }
        assertTrue(ApkVerifier.Builder(output).build().verify().isVerified)
        assertTrue(report.changes.any { it.contains("thư viện .so") && it.contains("SHA-256") })
        assertTrue(report.changes.any { it.contains("không tạo bản cài song song") })
        input.copyTo(File(out, "native-original.apk"), overwrite = true)
    }
    @Test fun sameKeySupportsRepeatedCloneSigning() {
        val a = ApkEngine.build(sample, fresh("update-a.apk"), Mode.CLONE, target, "A", identity)
        val b = ApkEngine.build(sample, fresh("update-b.apk"), Mode.CLONE, target, "B", identity)
        assertEquals(a.certificateSha256, b.certificateSha256)
        assertEquals(a.packageName, b.packageName)
    }
    @Test fun encryptedKeyRoundTripAndWrongPassword() {
        val bytes = SigningKeys.export(identity, "mat-khau-thu-123".toCharArray())
        val restored = SigningKeys.import(bytes, "mat-khau-thu-123".toCharArray())
        assertEquals(identity.fingerprint, restored.fingerprint)
        assertContentEquals(identity.key.encoded, restored.key.encoded)
        assertFails { SigningKeys.import(bytes, "sai-mat-khau".toCharArray()) }
        assertFails { SigningKeys.export(identity, "short".toCharArray()) }
    }
    @Test fun refusesSplitAndRequiredSplitBase() {
        val split = variant("split.apk") { it.androidManifest.manifestElement.getOrCreateAttribute("split", 0).setValueAsString("config.vi") }
        assertFailsWith<IllegalArgumentException> { ApkEngine.inspect(split) }
        val base = variant("base-required.apk") { it.androidManifest.applicationElement.getOrCreateAndroidAttribute("isSplitRequired", 0x01010591).setValueAsBoolean(true) }
        assertFailsWith<IllegalArgumentException> { ApkEngine.inspect(base) }
        val output = fresh("must-not-exist-split.apk")
        assertFails { ApkEngine.build(split, output, Mode.CLONE, target, "X", identity) }; assertFalse(output.exists())
    }
    @Test fun refusesMalformedNativeCloneWithoutPublishingOutput() {
        val native = variant("native.apk") { it.zipEntryMap.add(ByteInputSource(byteArrayOf(0x7f, 0x45, 0x4c, 0x46), "lib/arm64-v8a/libfixture.so")) }
        assertTrue(ApkEngine.inspect(native).nativeCode)
        val output = fresh("must-not-exist-native.apk")
        assertFails { ApkEngine.build(native, output, Mode.CLONE, target, "X", identity) }; assertFalse(output.exists())
    }
    @Test fun refusesUnresolvedAssetAndCleansTemporaryFiles() {
        val packed = variant("asset.apk") { it.zipEntryMap.add(ByteInputSource("{\"package\":\"$original\"}".toByteArray(), "assets/config.json")) }
        val output = fresh("must-not-exist-asset.apk")
        val error = assertFails { ApkEngine.build(packed, output, Mode.CLONE, target, "X", identity) }
        assertTrue(error.message!!.contains("assets/config.json"))
        assertFalse(output.exists()); assertFalse(File(output.path + ".pending").exists()); assertFalse(File(output.path + ".unsigned").exists())
    }
    @Test fun rejectsOverwriteAndInvalidPackage() {
        assertFails { ApkEngine.build(sample, sample, Mode.RESIGN, "", "", identity) }
        assertFalse(ApkEngine.validPackage("invalid")); assertFalse(ApkEngine.validPackage("vn.VietHoa.app"))
        assertFalse(ApkEngine.validPackage("android.hack")); assertTrue(ApkEngine.validPackage(target))
    }
    @Test fun rejectsMalformedInputPackage() {
        val broken = variant("invalid-package.apk") { it.androidManifest.setPackageName("vn.bad/package") }
        assertFailsWith<IllegalArgumentException> { ApkEngine.inspect(broken) }
        val output = fresh("must-not-exist-invalid-package.apk")
        assertFails { ApkEngine.build(broken, output, Mode.RESIGN, "", "", identity) }
        assertFalse(output.exists())
    }
}
