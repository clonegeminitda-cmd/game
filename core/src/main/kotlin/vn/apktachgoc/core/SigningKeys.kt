package vn.apktachgoc.core

import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.asn1.DERBMPString
import org.bouncycastle.asn1.pkcs.PKCSObjectIdentifiers
import org.bouncycastle.asn1.nist.NISTObjectIdentifiers
import org.bouncycastle.asn1.x509.AlgorithmIdentifier
import org.bouncycastle.cert.jcajce.JcaX509ExtensionUtils
import org.bouncycastle.pkcs.PKCS12PfxPduBuilder
import org.bouncycastle.pkcs.jcajce.JcaPKCS12SafeBagBuilder
import org.bouncycastle.pkcs.jcajce.JcePKCSPBEOutputEncryptorBuilder
import org.bouncycastle.pkcs.jcajce.JcePKCS12MacCalculatorBuilder
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.Date
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

data class SigningIdentity(val key: PrivateKey, val certificate: X509Certificate) {
    val fingerprint: String get() = java.security.MessageDigest.getInstance("SHA-256").digest(certificate.encoded).joinToString("") { "%02x".format(it.toInt() and 255) }
}

object SigningKeys {
    // Use an explicit provider instance; do not replace Android's system BC provider.
    private val provider = BouncyCastleProvider()
    fun create(): SigningIdentity {
        val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(3072, SecureRandom()) }.generateKeyPair()
        val subject = X500Name("CN=APK Tach Goc, O=Local signing")
        val now = System.currentTimeMillis()
        val certificate = JcaX509CertificateConverter().setProvider(provider).getCertificate(
            JcaX509v3CertificateBuilder(subject, BigInteger(160, SecureRandom()).abs(), Date(now - 86400000),
                Date(now + 30L * 365 * 86400000), subject, pair.public)
                .build(JcaContentSignerBuilder("SHA256withRSA").setProvider(provider).build(pair.private)))
        certificate.verify(pair.public)
        return SigningIdentity(pair.private, certificate)
    }
    fun export(identity: SigningIdentity, password: CharArray): ByteArray {
        require(password.size >= 10) { "Mật khẩu cần ít nhất 10 ký tự." }
        val encryptor = JcePKCSPBEOutputEncryptorBuilder(NISTObjectIdentifiers.id_aes256_CBC)
            .setProvider(provider).setIterationCount(210000)
            .setPRF(AlgorithmIdentifier(PKCSObjectIdentifiers.id_hmacWithSHA256)).build(password)
        val localId = JcaX509ExtensionUtils().createSubjectKeyIdentifier(identity.certificate.publicKey)
        val keyBag = JcaPKCS12SafeBagBuilder(identity.key, encryptor)
            .addBagAttribute(PKCSObjectIdentifiers.pkcs_9_at_friendlyName, DERBMPString("apk-tach-goc"))
            .addBagAttribute(PKCSObjectIdentifiers.pkcs_9_at_localKeyId, localId).build()
        val certBag = JcaPKCS12SafeBagBuilder(identity.certificate)
            .addBagAttribute(PKCSObjectIdentifiers.pkcs_9_at_friendlyName, DERBMPString("apk-tach-goc"))
            .addBagAttribute(PKCSObjectIdentifiers.pkcs_9_at_localKeyId, localId).build()
        return PKCS12PfxPduBuilder().addData(keyBag).addData(certBag)
            .build(JcePKCS12MacCalculatorBuilder(NISTObjectIdentifiers.id_sha256).setProvider(provider).setIterationCount(210000), password).encoded
    }
    fun import(bytes: ByteArray, password: CharArray): SigningIdentity {
        require(bytes.size <= 1024 * 1024) { "Tệp khóa quá lớn (tối đa 1 MB)." }
        val store = KeyStore.getInstance("PKCS12", provider)
        try { store.load(ByteArrayInputStream(bytes), password) }
        catch (e: Exception) { throw IllegalArgumentException("Không mở được khóa PKCS#12: mật khẩu sai hoặc tệp hỏng.", e) }
        val names = store.aliases().toList().filter { store.isKeyEntry(it) }
        require(names.size == 1) { "PKCS#12 phải chứa đúng một khóa riêng." }
        val key = store.getKey(names.single(), password) as? PrivateKey ?: error("Không đọc được khóa riêng.")
        require(key.algorithm == "RSA") { "Bản đầu chỉ hỗ trợ khóa RSA." }
        val cert = store.getCertificate(names.single()) as X509Certificate
        cert.checkValidity()
        val signer = java.security.Signature.getInstance("SHA256withRSA")
        val challenge = ByteArray(32).also { SecureRandom().nextBytes(it) }
        signer.initSign(key); signer.update(challenge); val sig = signer.sign()
        signer.initVerify(cert); signer.update(challenge)
        require(signer.verify(sig)) { "Khóa riêng và chứng chỉ không khớp." }
        return SigningIdentity(key, cert)
    }
}
