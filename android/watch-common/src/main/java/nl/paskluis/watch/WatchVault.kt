package nl.paskluis.watch

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Private, no-backup AES-GCM storage. Key never leaves AndroidKeyStore. */
class WatchVault(private val context: Context, private val name: String, private val maxBytes: Int = 8000) {
    private val file get() = AtomicFile(File(context.noBackupFilesDir, "watch-$name.bin"))
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("paskluis-watch-$name", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("paskluis-watch-$name", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized fun read(): String? {
        if (!file.baseFile.exists()) return null
        val data = file.readFully()
        require(data.size in 29..(maxBytes+28))
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, data.copyOfRange(0,12)))
        return String(cipher.doFinal(data.copyOfRange(12,data.size)), Charsets.UTF_8)
    }
    @Synchronized fun write(raw: String) {
        require(raw.toByteArray(Charsets.UTF_8).size <= maxBytes)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val bytes = cipher.iv + cipher.doFinal(raw.toByteArray(Charsets.UTF_8))
        val stream = file.startWrite()
        try { stream.write(bytes); file.finishWrite(stream) }
        catch (e: Exception) { file.failWrite(stream); throw e }
    }
    @Synchronized fun clear() = file.delete()
}

object WatchProtocol {
    const val PATH = "/paskluis/cards/v1"
    const val ACK = "/paskluis/ack/v1"
    const val GARMIN_ID = "5fdfca8919394cb8b3bbd96184aa208c"
    enum class Decision { REPLACE, ACKNOWLEDGE, REJECT }
    fun decide(old: JSONObject?, incoming: JSONObject, sameSource: Boolean): Decision {
        if (old == null) return if (sameSource) Decision.REPLACE else Decision.REJECT
        if (!sameSource && !old.optBoolean("allowNewOwner")) return Decision.REJECT
        if (old.getString("owner") != incoming.getString("owner")) {
            return if (old.optBoolean("allowNewOwner")) Decision.REPLACE else Decision.REJECT
        }
        val previous = old.getLong("revision"); val next = incoming.getLong("revision")
        return when {
            next > previous -> Decision.REPLACE
            next == previous && !old.optBoolean("locallyErased") -> Decision.ACKNOWLEDGE
            else -> Decision.REJECT
        }
    }
    fun parse(raw: String): JSONObject {
        require(raw.toByteArray(Charsets.UTF_8).size <= 7000)
        val data = JSONObject(raw)
        require(data.getInt("schema") == 1 && data.getString("owner").length in 1..64 && data.getLong("revision") >= 0)
        val cards = data.getJSONArray("cards")
        require(cards.length() <= 12)
        val ids = mutableSetOf<String>()
        for (i in 0 until cards.length()) {
            val c = cards.getJSONObject(i)
            require(c.getString("id").isNotEmpty() && ids.add(c.getString("id")))
            require(c.getString("code").length <= 512 && c.getString("name").length <= 80)
            val w = c.getInt("width"); val h = c.getInt("height")
            require(w in 1..192 && (h == 1 || (h == w && w <= 49)))
            val bits = c.getString("bits")
            require(bits.length == (w*h+3)/4 && bits.all { it in "0123456789abcdef" })
            c.getBoolean("favorite")
        }
        return data
    }
    fun toGarmin(value: Any): Any = when(value) {
        is JSONObject -> value.keys().asSequence().associateWith { toGarmin(value.get(it)) }
        is org.json.JSONArray -> (0 until value.length()).map { toGarmin(value.get(it)) }
        else -> value
    }
}
