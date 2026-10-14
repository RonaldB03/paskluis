package nl.paskluis.watch

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import org.json.JSONObject

object WatchLogos {
    fun store(context: Context, snapshot: JSONObject, raw: String?) {
        val clean = JSONObject()
        try {
            if (raw != null && raw.toByteArray(Charsets.UTF_8).size <= 80000) {
                val supplied = JSONObject(raw)
                val cards = snapshot.getJSONArray("cards")
                for (i in 0 until cards.length()) {
                    val id = cards.getJSONObject(i).getString("id")
                    val encoded = supplied.optString(id)
                    decode(encoded)?.let { it.recycle(); clean.put(id,encoded) }
                }
            }
        } catch (_: Exception) { /* Logos are optional, never reject passes. */ }
        val envelope = JSONObject().put("owner",snapshot.getString("owner"))
            .put("revision",snapshot.getLong("revision")).put("logos",clean)
        try { WatchVault(context,"logos",100000).write(envelope.toString()) }
        catch (_: Exception) { /* A missing thumbnail must not block sync. */ }
    }
    fun read(context: Context, snapshot: JSONObject?): Map<String, Bitmap> {
        if (snapshot == null || snapshot.optBoolean("locallyErased")) return emptyMap()
        return try {
            val data = JSONObject(WatchVault(context,"logos",100000).read() ?: return emptyMap())
            if (data.getString("owner") != snapshot.getString("owner") || data.getLong("revision") != snapshot.getLong("revision")) return emptyMap()
            val logos = data.getJSONObject("logos")
            logos.keys().asSequence().mapNotNull { id -> decode(logos.optString(id))?.let { id to it } }.toMap()
        } catch (_: Exception) { emptyMap() }
    }
    private fun decode(encoded: String): Bitmap? = try {
        if (encoded.length !in 1..6000) null else {
            val bytes = Base64.decode(encoded,Base64.NO_WRAP)
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds)
            if (bounds.outWidth !in 1..64 || bounds.outHeight !in 1..64 || bounds.outMimeType != "image/png") null
            else BitmapFactory.decodeByteArray(bytes,0,bytes.size)
        }
    } catch (_: Exception) { null }
}
