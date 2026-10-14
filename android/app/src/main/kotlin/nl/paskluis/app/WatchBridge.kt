package nl.paskluis.app

import android.content.Context
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import com.google.android.gms.wearable.*
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import nl.paskluis.watch.WatchProtocol
import nl.paskluis.watch.WatchRouting
import nl.paskluis.watch.WatchVault
import org.json.JSONObject

class WatchBridge(private val context: Context, messenger: BinaryMessenger) : DataClient.OnDataChangedListener {
    private val channel = MethodChannel(messenger, "nl.paskluis.app/watches")
    private val prefs = context.getSharedPreferences("watch-status", Context.MODE_PRIVATE)
    private val client = Wearable.getDataClient(context)
    private var iq: ConnectIQ? = null
    private var iqReady = false
    private var iqAttempted = false
    private val garminApp = IQApp(WatchProtocol.GARMIN_ID)
    private var devices = listOf<IQDevice>()
    private var registered: Long? = null
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "status" -> {
                        client.addListener(this)
                        // Read persisted ACKs as well as live callbacks after process restart.
                        if (prefs.contains("garmin.device")) startGarmin()
                        fun reply() = result.success(mapOf("wear" to state("wear"), "garmin" to state("garmin"),
                            "garminDevices" to devices.map { mapOf("id" to it.deviceIdentifier.toString(), "name" to it.friendlyName) }))
                        client.dataItems.addOnSuccessListener { items ->
                            items.use { for (item in it) consume(item) }; reply()
                        }.addOnFailureListener { reply() }
                    }
                    "wearDevices" -> {
                        Wearable.getCapabilityClient(context).getCapability("paskluis_addressed_watch",CapabilityClient.FILTER_REACHABLE)
                            .addOnSuccessListener { capability -> result.success(capability.nodes.map { mapOf("id" to it.id,"name" to it.displayName) }) }
                            .addOnFailureListener { result.error("connection","Watch unavailable",null) }
                    }
                    "setWear" -> {
                        val id = call.argument<String>("id")!!
                        require(!prefs.contains("wear.device") || prefs.getString("wear.device",null) == id)
                        Wearable.getCapabilityClient(context).getCapability("paskluis_addressed_watch",CapabilityClient.FILTER_REACHABLE).addOnSuccessListener { capability ->
                            val node = capability.nodes.firstOrNull { it.id == id }
                            if(node == null) result.error("connection","Watch unavailable",null)
                            else { prefs.edit().putString("wear.device",id).putString("wear.name",node.displayName).remove("wear.ack").apply(); result.success(null) }
                        }.addOnFailureListener { result.error("connection","Watch unavailable",null) }
                    }
                    "forgetWear" -> {
                        // Remove queued payloads before allowing another recipient.
                        client.deleteDataItems(android.net.Uri.parse("wear://*"+WatchProtocol.PATH),DataClient.FILTER_PREFIX)
                            .addOnSuccessListener {
                                val edit = prefs.edit()
                                for(suffix in listOf("device","name","pending","owner","count","ack","ackOwner")) edit.remove("wear.$suffix")
                                edit.apply(); WatchVault(context,"pending-wear").clear(); result.success(null)
                            }.addOnFailureListener { result.error("connection","Could not detach watch",null) }
                    }
                    "garminLogo" -> {
                        val payload = JSONObject(call.arguments as Map<*,*>).put("kind","logo")
                        require(payload.getString("pixels").length == 576)
                        val device = devices.firstOrNull { it.deviceIdentifier == prefs.getLong("garmin.device",-1) }
                        if(!iqReady || device == null) result.error("connection","Garmin unavailable",null)
                        else iq!!.sendMessage(device,garminApp,WatchProtocol.toGarmin(payload)) { _,_,status ->
                            android.os.Handler(context.mainLooper).post {
                                if(status == ConnectIQ.IQMessageStatus.SUCCESS) result.success(null)
                                else result.error("connection","Thumbnail transfer failed",null)
                            }
                        }
                    }
                    "chooseGarmin" -> { if (iq == null) iqAttempted = false; startGarmin(); refreshDevices(); result.success(null) }
                    "forgetGarmin" -> {
                        if (iqReady) iq?.unregisterAllForEvents()
                        registered = null
                        val edit = prefs.edit()
                        for (suffix in listOf("device","pending","owner","count","ack","ackOwner")) edit.remove("garmin.$suffix")
                        edit.apply()
                        WatchVault(context,"pending-garmin").clear()
                        result.success(null)
                    }
                    "setGarmin" -> {
                        val id = call.argument<String>("id")!!.toLong()
                        require(devices.any { it.deviceIdentifier == id })
                        val old = prefs.getLong("garmin.device", -1)
                        require(old == -1L || old == id || (!prefs.contains("garmin.pending") ||
                            (state("garmin")["confirmed"] == true && prefs.getInt("garmin.count", -1) == 0)))
                        if (old != id) prefs.edit().remove("garmin.ack").apply()
                        prefs.edit().putLong("garmin.device",id).apply()
                        registerGarmin(); result.success(null)
                    }
                    "replace" -> {
                        val target = call.argument<String>("target")!!
                        val raw = call.argument<String>("snapshot")!!
                        val snapshot = WatchProtocol.parse(raw)
                        require(target == "wear" || target == "garmin")
                        WatchVault(context, "pending-$target").write(raw)
                        prefs.edit().putLong("$target.pending",snapshot.getLong("revision"))
                            .putString("$target.owner",snapshot.getString("owner"))
                            .putInt("$target.count",snapshot.getJSONArray("cards").length()).apply()
                        if (target == "wear") {
                            val logos = call.argument<String>("logos") ?: "{}"
                            require(logos.toByteArray(Charsets.UTF_8).size <= 80000)
                            val request = PutDataMapRequest.create(WatchRouting.path(requireNotNull(prefs.getString("wear.device",null)))).apply {
                                dataMap.putString("snapshot",raw)
                                dataMap.putString("logos",logos)
                            }
                            client.putDataItem(request.asPutDataRequest().setUrgent())
                                .addOnSuccessListener { result.success(null) }
                                .addOnFailureListener { result.error("connection", "Wear OS unavailable", null) }
                        } else {
                            startGarmin(); registerGarmin()
                            val device = devices.firstOrNull { it.deviceIdentifier == prefs.getLong("garmin.device",-1) }
                            if (!iqReady || device == null) result.error("connection","Choose a Garmin and open its app",null)
                            else iq!!.sendMessage(device,garminApp,WatchProtocol.toGarmin(snapshot)) { _,_,status ->
                                android.os.Handler(context.mainLooper).post {
                                    if (status == ConnectIQ.IQMessageStatus.SUCCESS) result.success(null)
                                    else result.error("connection","Garmin did not accept the transfer",null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("connection", "Watch connection unavailable",null) }
        }
    }
    private fun state(target: String): Map<String,Any> = mapOf(
        "confirmed" to (prefs.contains("$target.pending") && prefs.getLong("$target.pending",-1) == prefs.getLong("$target.ack",-2) &&
            prefs.getString("$target.owner",null) == prefs.getString("$target.ackOwner",null)),
        "locallyErased" to (prefs.getLong("$target.ack",-2) == -1L &&
            prefs.getString("$target.owner",null) == prefs.getString("$target.ackOwner",null)),
        "device" to if (target == "garmin") prefs.getLong("garmin.device",-1).toString() else prefs.getString("wear.device","").orEmpty(),
        "name" to prefs.getString("$target.name",null).orEmpty())
    private fun changed() { android.os.Handler(context.mainLooper).post { channel.invokeMethod("changed",null) } }
    override fun onDataChanged(events: DataEventBuffer) { for(event in events) if(event.type == DataEvent.TYPE_CHANGED) consume(event.dataItem) }
    private fun consume(item: DataItem) {
        if(item.uri.path != WatchProtocol.ACK || !WatchRouting.acceptsAck(item.uri.host,prefs.getString("wear.device",null))) return
        val data = DataMapItem.fromDataItem(item).dataMap
        val ack = data.getLong("ack",-1); val owner = data.getString("owner") ?: ""
        if (ack == prefs.getLong("wear.ack",-2) && owner == prefs.getString("wear.ackOwner",null)) return
        prefs.edit().putLong("wear.ack",ack).putString("wear.ackOwner",owner).apply()
        changed()
    }
    private fun startGarmin() {
        if(iq != null || iqAttempted) return
        iqAttempted = true
        iq = ConnectIQ.getInstance(context,ConnectIQ.IQConnectType.WIRELESS)
        iq!!.initialize(context,false,object: ConnectIQ.ConnectIQListener {
            override fun onSdkReady() { iqReady = true; refreshDevices(); registerGarmin(); changed() }
            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) { iqReady = false; iq = null; changed() }
            override fun onSdkShutDown() { iqReady = false; iq = null }
        })
    }
    private fun refreshDevices() {
        if(!iqReady) return
        devices = iq!!.knownDevices ?: emptyList()
        changed()
    }
    private fun registerGarmin() {
        if(!iqReady) return
        val device = devices.firstOrNull { it.deviceIdentifier == prefs.getLong("garmin.device",-1) } ?: return
        if(registered == device.deviceIdentifier) return
        iq!!.unregisterAllForEvents()
        iq!!.registerForAppEvents(device,garminApp) { d,_,messages,status ->
            if(status == ConnectIQ.IQMessageStatus.SUCCESS && d.deviceIdentifier == prefs.getLong("garmin.device",-1)) {
                for(message in messages) if(message is Map<*,*>) {
                    val ack = message["ack"] as? Number ?: continue
                    val owner = message["owner"] as? String ?: continue
                    prefs.edit().putLong("garmin.ack",ack.toLong()).putString("garmin.ackOwner",owner).apply()
                    changed()
                }
            }
        }
        registered = device.deviceIdentifier
    }
    fun close() {
        client.removeListener(this)
        try { iq?.shutdown(context) } catch (_: Exception) {}
        channel.setMethodCallHandler(null)
    }
}
