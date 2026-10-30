package vn.apktachgoc

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*
import vn.apktachgoc.core.*
import java.io.File
import java.util.zip.ZipFile

@RunWith(AndroidJUnit4::class)
class OnDeviceTest {
    @Test fun cloneRealNativeApkOnAndroid() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val folder = File(context.getExternalFilesDir(null), "device-native-clone-test").apply { mkdirs() }
        val input = File(folder, "native-original.apk")
        instrumentation.context.assets.open("native-sample-debug.apk").use { source -> input.outputStream().use { source.copyTo(it) } }
        val hash = ApkEngine.sha256(input)
        val output = File(folder, "native-clone.apk").apply { delete() }
        val report = ApkEngine.build(input, output, Mode.CLONE, "vn.apktachgoc.nativesample.tachgoc", "Native • Bản riêng", KeyVault.get(context))
        assertEquals("vn.apktachgoc.nativesample.tachgoc", ApkEngine.inspect(output).packageName)
        assertEquals(Mode.CLONE, report.mode)
        assertEquals(hash, ApkEngine.sha256(input))
        ZipFile(input).use { original -> ZipFile(output).use { clone ->
            val name = "lib/x86_64/libnativefixture.so"
            assertArrayEquals(original.getInputStream(original.getEntry(name)).readBytes(), clone.getInputStream(clone.getEntry(name)).readBytes())
        } }
        File(folder, "result.txt").writeText("PASS: tạo bản tách gốc native trên Android, package mới; giữ byte .so và APK gốc.\nInput SHA256=$hash\nOutput SHA256=${report.sha256}\nCertificate=${report.certificateSha256}\n${report.changes.joinToString("\n")}\n")
    }
    @Test fun resignRealNativeApkOnAndroid() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val folder = File(context.getExternalFilesDir(null), "device-native-test").apply { mkdirs() }
        val input = File(folder, "native-original.apk")
        instrumentation.context.assets.open("native-sample-debug.apk").use { source -> input.outputStream().use { source.copyTo(it) } }
        val originalHash = ApkEngine.sha256(input)
        assertTrue(ApkEngine.inspect(input).nativeCode)
        val output = File(folder, "native-resigned.apk").apply { delete() }
        val report = ApkEngine.build(input, output, Mode.RESIGN, "", "", KeyVault.get(context))
        assertEquals("vn.apktachgoc.nativesample", ApkEngine.inspect(output).packageName)
        assertEquals(originalHash, ApkEngine.sha256(input))
        ZipFile(input).use { original -> ZipFile(output).use { signed ->
            val name = "lib/x86_64/libnativefixture.so"
            assertArrayEquals(original.getInputStream(original.getEntry(name)).readBytes(), signed.getInputStream(signed.getEntry(name)).readBytes())
        } }
        assertTrue(report.changes.any { it.contains("thư viện .so") })
        File(folder, "result.txt").writeText("PASS: ký lại APK native trên Android; giữ nguyên package và từng byte .so.\nInput SHA256=$originalHash\nOutput SHA256=${report.sha256}\nCertificate=${report.certificateSha256}\n${report.changes.joinToString("\n")}\n")
    }
    @Test fun vaultRecoversInterruptedWriteWithoutReplacingKey() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val identity = KeyVault.get(context)
        val file = File(context.noBackupFilesDir, "signing-key.aes")
        val backup = File(file.path + ".bak")
        backup.delete()
        assertTrue(file.renameTo(backup))
        assertEquals(identity.fingerprint, KeyVault.get(context).fingerprint)
        assertTrue(file.exists())
        assertFalse(backup.exists())
    }
    @Test fun createSignCloneAndRoundTripVaultOnAndroid() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val folder = File(context.getExternalFilesDir(null), "device-test").apply { mkdirs() }
        val input = File(folder, "sample-original.apk")
        instrumentation.context.assets.open("sample-debug.apk").use { source -> input.outputStream().use { source.copyTo(it) } }
        val hash = ApkEngine.sha256(input)
        val identity = KeyVault.get(context)
        assertEquals(identity.fingerprint, KeyVault.get(context).fingerprint)
        val exported = SigningKeys.export(identity, "device-test-password-2026".toCharArray())
        val restored = SigningKeys.import(exported, "device-test-password-2026".toCharArray())
        assertEquals(identity.fingerprint, restored.fingerprint)
        KeyVault.save(context, restored)
        assertEquals(identity.fingerprint, KeyVault.get(context).fingerprint)
        val output = File(folder, "sample-clone.apk").apply { delete() }
        val result = ApkEngine.build(input, output, Mode.CLONE, "vn.apktachgoc.sample.tachgoc", "Mẫu • Bản riêng", KeyVault.get(context))
        assertTrue(output.exists()); assertEquals("vn.apktachgoc.sample.tachgoc", ApkEngine.inspect(output).packageName)
        assertEquals(hash, ApkEngine.sha256(input))
        assertEquals(identity.fingerprint, result.certificateSha256)
        val resigned = File(folder, "sample-resigned.apk").apply { delete() }
        ApkEngine.build(input, resigned, Mode.RESIGN, "", "", identity)
        assertEquals("vn.apktachgoc.sample", ApkEngine.inspect(resigned).packageName)
        File(folder, "result.txt").writeText("PASS: Android Keystore AES-GCM, PKCS#12 export/import, clone/re-sign on Android, input unchanged.\nClone SHA256=${result.sha256}\nCertificate=${identity.fingerprint}\n")
    }
}
