package nl.paskluis.app

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.location.LocationManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.*
import org.json.JSONArray
import org.json.JSONObject

/** Native geofences only. No location polling, network requests or card codes. */
object GiftStoreReminders {
    private const val PREFS = "gift_store_regions_v1"
    private const val ROWS = "regions"
    private const val CHANNEL = "gift_store_reminders"
    private const val TAG = "gift-store"
    private var revision = 0
    private var busy = false
    private var dirty = false
    private var registrationFailed = false
    private val completions = mutableListOf<() -> Unit>()
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun granted(c: Context, p: String) = ContextCompat.checkSelfPermission(c, p) == PackageManager.PERMISSION_GRANTED
    fun permission(c: Context): String {
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(c) != ConnectionResult.SUCCESS) return "unavailable"
        val lm = c.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (Build.VERSION.SDK_INT >= 28 && !lm.isLocationEnabled) return "unavailable"
        if (!granted(c, Manifest.permission.ACCESS_FINE_LOCATION)) return "denied"
        if (Build.VERSION.SDK_INT >= 29 && !granted(c, Manifest.permission.ACCESS_BACKGROUND_LOCATION)) return "whenInUse"
        return "always"
    }
    fun status(c: Context): String {
        val p = permission(c)
        if (p != "always") return p
        if (!NotificationManagerCompat.from(c).areNotificationsEnabled()) return "notificationsDenied"
        if (Build.VERSION.SDK_INT >= 26 && (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return "notificationsDenied"
        return if (registrationFailed) "unavailable" else "always"
    }
    private fun pending(c: Context): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(c, 190, Intent(c, GiftStoreReceiver::class.java).setAction("nl.paskluis.GIFT_REGION"), flags)
    }
    private fun rows(c: Context): JSONArray = try { JSONArray(prefs(c).getString(ROWS, "[]")) } catch (_: Exception) { JSONArray() }
    fun replace(c: Context, incoming: List<*>) {
        val next = JSONArray()
        val now = System.currentTimeMillis() / 1000.0
        incoming.take(20).forEach { value ->
            val m = value as? Map<*, *> ?: return@forEach
            val id = m["id"] as? String ?: return@forEach
            val lat = (m["latitude"] as? Number)?.toDouble() ?: return@forEach
            val lon = (m["longitude"] as? Number)?.toDouble() ?: return@forEach
            val end = (m["validUntil"] as? Number)?.toDouble() ?: return@forEach
            val body = m["body"] as? String ?: return@forEach
            if (id.isBlank() || !lat.isFinite() || !lon.isFinite() || kotlin.math.abs(lat)>90 || kotlin.math.abs(lon)>180 || !end.isFinite() || end<=now) return@forEach
            next.put(JSONObject().put("id",id).put("latitude",lat).put("longitude",lon)
                .put("validUntil",minOf(end,now+7*86400)).put("body",body).put("title","PasKluis"))
        }
        // Invalidate receiver data synchronously before asynchronous OS removal.
        prefs(c).edit().putString(ROWS,next.toString()).commit()
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.activeNotifications.filter { it.tag == TAG }.forEach { nm.cancel(TAG,it.id) }
        revision++
        reconcile(c.applicationContext)
    }
    fun reconcile(c: Context, complete: (() -> Unit)? = null) {
        if (complete != null) completions.add(complete)
        dirty = true
        if (busy) return
        busy = true
        dirty = false
        val version = revision
        val client = LocationServices.getGeofencingClient(c)
        fun done() {
            busy = false
            if (dirty || version != revision) reconcile(c)
            else { val callbacks=completions.toList(); completions.clear(); callbacks.forEach { it() } }
        }
        client.removeGeofences(pending(c)).addOnCompleteListener {
            if (version != revision) { done(); return@addOnCompleteListener }
            if (permission(c) != "always") { done(); return@addOnCompleteListener }
            val now = System.currentTimeMillis()
            val data = rows(c)
            val fences = (0 until data.length()).mapNotNull { i ->
                val row = data.getJSONObject(i)
                val remaining = (row.getDouble("validUntil")*1000).toLong()-now
                if (remaining<=0) null else Geofence.Builder().setRequestId(row.getString("id"))
                    .setCircularRegion(row.getDouble("latitude"),row.getDouble("longitude"),100f)
                    .setExpirationDuration(remaining).setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                    .setNotificationResponsiveness(60000).build()
            }
            if (fences.isEmpty()) { registrationFailed=false; done(); return@addOnCompleteListener }
            try {
                client.addGeofences(GeofencingRequest.Builder().setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER).addGeofences(fences).build(),pending(c))
                    .addOnCompleteListener { result -> registrationFailed = !result.isSuccessful; done() }
            } catch (_: SecurityException) { registrationFailed=true; done() }
        }
    }
    fun entered(c: Context, ids: List<String>) {
        if (status(c) != "always") return
        val now = System.currentTimeMillis()
        val data = rows(c)
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel(CHANNEL,"PasKluis",NotificationManager.IMPORTANCE_DEFAULT))
        for (i in 0 until data.length()) {
            val row = data.getJSONObject(i)
            val id = row.getString("id")
            val last = prefs(c).getLong("last.$id",0)
            if (id !in ids || !GiftReminderPolicy.mayNotify(now,(row.getDouble("validUntil")*1000).toLong(),last)) continue
            val intent = Intent(c,MainActivity::class.java).setAction("nl.paskluis.GIFT_OPEN")
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val tap = PendingIntent.getActivity(c,190,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(c,CHANNEL).setSmallIcon(R.drawable.ic_gift_reminder)
                .setContentTitle("PasKluis").setContentText(row.getString("body"))
                .setStyle(NotificationCompat.BigTextStyle().bigText(row.getString("body")))
                .setContentIntent(tap).setAutoCancel(true).setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build()
            try {
                prefs(c).edit().putLong("last.$id",now).commit()
                nm.notify(TAG,id.hashCode(),notification)
            } catch (_: SecurityException) { prefs(c).edit().putLong("last.$id",last).apply() }
        }
    }
}

class GiftStoreReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError() || event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return
        GiftStoreReminders.entered(context,event.triggeringGeofences?.map { it.requestId } ?: emptyList())
    }
}

class GiftStoreBootReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // No fresh location lookup on restart; registration uses the saved, expiring snapshot.
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val pending = goAsync()
            var finished = false
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            val finish = Runnable { if (!finished) { finished=true; pending.finish() } }
            handler.postDelayed(finish,8000)
            GiftStoreReminders.reconcile(context.applicationContext) { handler.removeCallbacks(finish); finish.run() }
        }
    }
}
