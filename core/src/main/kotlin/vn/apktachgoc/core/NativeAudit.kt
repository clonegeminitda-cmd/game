package vn.apktachgoc.core

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.ZipFile

/** Conservative audit, never patches ELF code, symbols, addresses or string tables.
 * JNI class references deliberately keep their original namespace. Only known DEX
 * class names are exempt from identifier matches. Encrypted/computed identifiers
 * and signature checks cannot be established by this static audit.
 */
internal object NativeAudit {
    private const val CONTEXT = 2048
    private data class Needle(val id: String, val encoding: Int)
    fun check(apk: File, identifiers: Set<String>, classes: Set<String>): Int {
        val errors = mutableListOf<String>()
        val count = inspect(apk, identifiers, classes, { location, message -> if (errors.size < 100) errors += "$location: $message" })
        require(errors.isEmpty()) { errors.joinToString("\n") }
        return count
    }
    fun inspect(apk: File, identifiers: Set<String>, classes: Set<String>, issue: (String, String) -> Unit, progress: (Int, Int, String) -> Unit = { _, _, _ -> }): Int = ZipFile(apk).use { zip ->
        val libraries = zip.entries().asSequence().filter { !it.isDirectory && it.name.endsWith(".so", true) }.toList()
        if (libraries.isEmpty()) return@use 0
        val needles = linkedMapOf<String, Needle>()
        identifiers.forEach { id ->
            listOf(id, id.replace('.', '/')).distinct().forEach { token ->
                listOf(0, 1, 2).forEach { encoding ->
                    val raw = when (encoding) {
                        1 -> token.toByteArray(Charsets.UTF_16LE)
                        2 -> token.toByteArray(Charsets.UTF_16BE)
                        else -> token.toByteArray(Charsets.UTF_8)
                    }.toString(Charsets.ISO_8859_1)
                    needles[raw] = Needle(id, encoding)
                }
            }
        }
        val pattern = if (needles.isEmpty()) null else Regex(needles.keys.sortedByDescending { it.length }.joinToString("|") { Regex.escape(it) })
        libraries.forEachIndexed { index, entry ->
            progress(index + 1, libraries.size, entry.name)
            try {
            require(Regex("lib/(armeabi|armeabi-v7a|arm64-v8a|x86|x86_64|riscv64)/[^/]+\\.so").matches(entry.name)) {
                "Thư viện ${entry.name} nằm ngoài cấu trúc ABI được hỗ trợ; chưa tách gốc APK này."
            }
            zip.getInputStream(entry).use { input ->
                val header = ByteArray(64)
                var used = 0
                while (used < header.size) { val n = input.read(header, used, header.size - used); if (n < 0) break; used += n }
                validateElf(header, used, entry.size, entry.name)
            }
            val unresolved = linkedSetOf<String>()
            zip.getInputStream(entry).buffered().use { input ->
                val buffer = ByteArray(65536)
                var tail = ""
                while (true) {
                    val n = input.read(buffer)
                    val end = n < 0
                    val chunk = tail + if (end) "" else String(buffer, 0, n, Charsets.ISO_8859_1)
                    // Defer matches near the end so an intact class name can be recognized.
                    val limit = if (end) chunk.length else maxOf(0, chunk.length - CONTEXT)
                    pattern?.findAll(chunk)?.filter { it.range.first < limit }?.forEach { match ->
                        val needle = needles.getValue(match.value)
                        val context = tokenAt(chunk, match.range.first, needle.encoding)
                        if (context.isEmpty() || context !in classes) unresolved += needle.id
                    }
                    if (end) break
                    tail = chunk.takeLast(CONTEXT * 2)
                }
            }
            if (unresolved.isNotEmpty()) issue(entry.name, "phát hiện định danh ${unresolved.joinToString()} trong native, ngoài tham chiếu lớp JNI đã biết. Cần xử lý riêng thư viện này; không xuất APK và không tự chuyển sang Ký lại.")
            } catch (e: Exception) { issue(entry.name, e.message ?: e.javaClass.simpleName) }
        }
        libraries.size
    }
    private fun tokenAt(raw: String, match: Int, encoding: Int): String {
        val step = if (encoding == 0) 1 else 2
        val low = if (encoding == 2) 1 else 0
        fun charAt(start: Int): Char? {
            if (start < 0 || start + step > raw.length) return null
            if (step == 2 && raw[start + 1 - low] != '\u0000') return null
            val c = raw[start + low]
            return c.takeIf { it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' || it in "_./$;" }
        }
        var start = match
        while (match - start < CONTEXT && charAt(start - step) != null) start -= step
        val result = StringBuilder()
        var cursor = start
        while (cursor - start < CONTEXT) {
            val c = charAt(cursor) ?: break
            result.append(c); cursor += step
        }
        return result.toString()
    }
    private fun validateElf(bytes: ByteArray, used: Int, size: Long, name: String) {
        fun fail(): Nothing = error("Thư viện $name không phải ELF dùng chung hợp lệ hoặc ABI chưa hỗ trợ; không xuất APK.")
        if (used < 52 || bytes[0] != 0x7f.toByte() || bytes[1] != 0x45.toByte() || bytes[2] != 0x4c.toByte() || bytes[3] != 0x46.toByte()) fail()
        val bits = bytes[4].toInt()
        if (bits !in 1..2 || bytes[5].toInt() !in 1..2 || bytes[6].toInt() != 1 || (bits == 2 && used < 64)) fail()
        val buffer = ByteBuffer.wrap(bytes).order(if (bytes[5].toInt() == 1) ByteOrder.LITTLE_ENDIAN else ByteOrder.BIG_ENDIAN)
        fun u16(offset: Int) = buffer.getShort(offset).toInt() and 65535
        fun u32(offset: Int) = buffer.getInt(offset).toLong() and 0xffffffffL
        if (u16(16) != 3 || u32(20) != 1L) fail() // ET_DYN, EV_CURRENT
        val abi = name.split('/')[1]
        val expected = when (abi) {
            "armeabi", "armeabi-v7a" -> 1 to 40
            "arm64-v8a" -> 2 to 183
            "x86" -> 1 to 3
            "x86_64" -> 2 to 62
            "riscv64" -> 2 to 243
            else -> fail()
        }
        if (bits != expected.first || u16(18) != expected.second) fail()
        val phOffset = if (bits == 2) buffer.getLong(32) else u32(28)
        val headerSize = u16(if (bits == 2) 52 else 40)
        val phSize = u16(if (bits == 2) 54 else 42)
        val phCount = u16(if (bits == 2) 56 else 44)
        if (headerSize != (if (bits == 2) 64 else 52) || phCount == 0 || phSize != (if (bits == 2) 56 else 32) ||
            phOffset < headerSize || phOffset > size || phCount.toLong() * phSize > size - phOffset) fail()
    }
}
