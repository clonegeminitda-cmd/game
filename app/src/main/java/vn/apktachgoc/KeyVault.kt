package vn.apktachgoc

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import vn.apktachgoc.core.SigningIdentity
import vn.apktachgoc.core.SigningKeys
import java.io.*
import java.security.KeyFactory
import java.security.KeyStore
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.security.spec.PKCS8EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object KeyVault {
    private const val ALIAS = "apk-tach-goc-wrapping-v1"
    private fun wrappingKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        return store.getKey(ALIAS, null) as? SecretKey ?: KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }
    @Synchronized fun get(context: Context): SigningIdentity {
        val file = File(context.noBackupFilesDir, "signing-key.aes")
        if (!file.exists() && !File(file.path + ".bak").exists() && !File(file.path + ".new").exists()) return SigningKeys.create().also { save(context, it) }
        try {
            val encrypted = AtomicFile(file).openRead().use { it.readBytes() }
            require(encrypted.size > 28)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, wrappingKey(), GCMParameterSpec(128, encrypted.copyOfRange(0, 12)))
            val plain = cipher.doFinal(encrypted, 12, encrypted.size - 12)
            try {
                return DataInputStream(ByteArrayInputStream(plain)).use { input ->
                    val keySize = input.readInt(); require(keySize in 1..16384)
                    val key = ByteArray(keySize).also { input.readFully(it) }
                    val certSize = input.readInt(); require(certSize in 1..16384)
                    val cert = ByteArray(certSize).also { input.readFully(it) }
                    try { SigningIdentity(KeyFactory.getInstance("RSA").generatePrivate(PKCS8EncodedKeySpec(key)), CertificateFactory.getInstance("X.509").generateCertificate(ByteArrayInputStream(cert)) as X509Certificate) }
                    finally { key.fill(0) }
                }
            } finally { plain.fill(0) }
        } catch (e: Exception) { throw IllegalStateException("Không mở được khóa ký đã lưu. Hãy nhập bản sao PKCS#12; ứng dụng sẽ không tự thay bằng khóa mới.", e) }
    }
    @Synchronized fun save(context: Context, identity: SigningIdentity) {
        val plain = ByteArrayOutputStream().use { bytes -> DataOutputStream(bytes).use { out ->
            out.writeInt(identity.key.encoded.size); out.write(identity.key.encoded)
            out.writeInt(identity.certificate.encoded.size); out.write(identity.certificate.encoded)
        }; bytes.toByteArray() }
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, wrappingKey()) }
            val encrypted = cipher.iv + cipher.doFinal(plain)
            val file = AtomicFile(File(context.noBackupFilesDir, "signing-key.aes"))
            val stream = file.startWrite()
            try { stream.write(encrypted); file.finishWrite(stream) } catch (e: Exception) { file.failWrite(stream); throw e }
        } finally { plain.fill(0) }
    }
}
