package vn.apktachgoc.core

import com.reandroid.apk.ApkModule
import com.reandroid.arsc.chunk.xml.ResXmlAttribute
import com.reandroid.arsc.value.ValueType

/** Resolve only app-owned scalar strings, with explicit bounds and cycle checks.
 * Keep resource IDs and every configuration/alias intact; rewrite their terminal
 * identifier strings later using the normal exact-value mapping.
 */
internal object ResourceIdentifiers {
    fun hex(id: Int) = "0x%08x".format(id)
    fun values(module: ApkModule, attribute: ResXmlAttribute, location: String): Set<String> {
        val errors = mutableListOf<String>()
        val result = collect(module, attribute, location) { errors += it }
        require(errors.isEmpty()) { errors.joinToString("\n") }
        return result
    }
    fun collect(module: ApkModule, attribute: ResXmlAttribute, location: String, issue: (String) -> Unit): Set<String> {
        val where = "$location android:${attribute.name}"
        fun checked(value: String): String {
            require(value.isNotBlank() && value.length <= 512) { "$where: định danh rỗng hoặc dài hơn 512 ký tự." }
            return value
        }
        if (attribute.valueType == ValueType.STRING) return try { setOf(checked(attribute.valueAsString)) } catch (e: Exception) { issue(e.message.orEmpty()); emptySet() }
        if (attribute.valueType != ValueType.REFERENCE || !module.hasTableBlock()) {
            issue("$where: kiểu ${attribute.valueType} / ${hex(attribute.data)} chưa hỗ trợ hoặc thiếu resources.arsc.")
            return emptySet()
        }
        var nodes = 0
        var limitReported = false
        fun resolve(id: Int, path: List<Int>): Set<String> {
            val chain = (path + id).joinToString(" → ") { hex(it) }
            if (++nodes > 1024) { if (!limitReported) issue("$where: vượt 1024 nút tham chiếu, phần dư chưa giải được."); limitReported = true; return emptySet() }
            try {
            require(id !in path) { "$where: vòng lặp tham chiếu tài nguyên $chain." }
            require(path.size < 32) { "$where: chuỗi tài nguyên quá sâu: $chain." }
            val resource = module.tableBlock.getLocalResource(id)
                ?: error("$where: không tìm thấy tài nguyên nội bộ $chain; tham chiếu framework/thư viện ngoài chưa hỗ trợ.")
            val entries = resource.iterator().asSequence().filter { !it.isNull }.take(257).toList()
            require(entries.isNotEmpty() && entries.size <= 256) { "$where: tài nguyên $chain không có giá trị hoặc vượt 256 cấu hình." }
            require(resource.type == "string") { "$where: $chain là @${resource.type}/${resource.name}, cần @string." }
            return entries.flatMap { entry ->
                try {
                require(!entry.isComplex && entry.resValue != null) { "$where: $chain là tài nguyên phức hợp, chưa hỗ trợ." }
                when (entry.valueType) {
                    ValueType.STRING -> setOf(checked(entry.valueAsString))
                    ValueType.REFERENCE -> resolve(entry.resValue.data, path + id)
                    else -> error("$where: $chain cấu hình ${entry.resConfig} có kiểu ${entry.valueType}, cần chuỗi hoặc bí danh @string.")
                }
                } catch (e: Exception) { issue(e.message ?: e.javaClass.simpleName); emptySet() }
            }.toSet()
            } catch (e: Exception) { issue(e.message ?: e.javaClass.simpleName); return emptySet() }
        }
        return resolve(attribute.data, emptyList())
    }
}
