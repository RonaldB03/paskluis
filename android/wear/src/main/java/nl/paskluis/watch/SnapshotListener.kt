package nl.paskluis.watch

import android.content.Context
import com.google.android.gms.wearable.*
import org.json.JSONObject

object Snapshots {
    private val lock = Any()
    var onChanged: (() -> Unit)? = null
    fun read(context: Context): JSONObject? = try { WatchVault(context,"cards").read()?.let { WatchProtocol.parse(it) } } catch (_: Exception) { null }
    fun receive(context: Context, item: DataItem) = synchronized(lock) {
        if(item.uri.path != WatchProtocol.PATH) return@synchronized
        try {
            val raw = DataMapItem.fromDataItem(item).dataMap.getString("snapshot") ?: return@synchronized
            val incoming = WatchProtocol.parse(raw)
            val source = item.uri.host ?: return@synchronized
            val prefs = context.getSharedPreferences("watch-state",Context.MODE_PRIVATE)
            val oldSource = prefs.getString("source",null)
            val old = read(context)
            when(WatchProtocol.decide(old,incoming,oldSource == null || oldSource == source)) {
                WatchProtocol.Decision.REJECT -> return@synchronized
                WatchProtocol.Decision.ACKNOWLEDGE -> {
                    ack(context,incoming.getLong("revision"),incoming.getString("owner"))
                    return@synchronized
                }
                WatchProtocol.Decision.REPLACE -> Unit
            }
            // Store optional logos first; owner/revision matching prevents stale
            // images from being displayed if the card write fails afterwards.
            WatchLogos.store(context, incoming, DataMapItem.fromDataItem(item).dataMap.getString("logos"))
            WatchVault(context,"cards").write(raw)
            prefs.edit().putString("source",source).putLong("receivedAt",System.currentTimeMillis()).apply()
            ack(context,incoming.getLong("revision"),incoming.getString("owner"))
            onChanged?.invoke()
        } catch (_: Exception) { /* Never acknowledge malformed or unpersisted data. */ }
    }
    fun ack(context: Context, revision: Long, owner: String) {
        val request = PutDataMapRequest.create(WatchProtocol.ACK).apply {
            dataMap.putLong("ack",revision); dataMap.putString("owner",owner)
        }
        Wearable.getDataClient(context).putDataItem(request.asPutDataRequest().setUrgent())
    }
    fun erase(context: Context, reset: Boolean = false) = synchronized(lock) {
        val old = read(context)
        if(old != null) {
            old.put("cards",org.json.JSONArray())
            old.put("locallyErased",true)
            old.put("allowNewOwner",reset)
            WatchVault(context,"cards").write(old.toString())
        }
        WatchVault(context,"logos",100000).clear()
        context.getSharedPreferences("watch-state",Context.MODE_PRIVATE).edit().remove("receivedAt").apply()
        ack(context,-1,old?.optString("owner") ?: "")
        onChanged?.invoke()
    }
}
class SnapshotListener : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        for(event in events) if(event.type == DataEvent.TYPE_CHANGED) Snapshots.receive(this,event.dataItem)
    }
}
