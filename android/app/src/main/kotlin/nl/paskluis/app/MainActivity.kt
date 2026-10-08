package nl.paskluis.app

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var reminders: MethodChannel? = null
    private var remindersReady = false
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        reminders = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"nl.paskluis.app/gift-store-reminders")
        reminders?.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(GiftStoreReminders.status(this))
                "requestAlways" -> {
                    if (GiftStoreReminders.permission(this) != "always") {
                        if (Build.VERSION.SDK_INT >= 30) startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:$packageName")))
                        else if (Build.VERSION.SDK_INT >= 29) requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),190)
                    }
                    result.success(null)
                }
                "replace" -> { GiftStoreReminders.replace(applicationContext,call.argument<List<*>>("regions") ?: emptyList<Any>()); result.success(null) }
                "takeInitialOpen" -> {
                    remindersReady = true
                    val opened = intent?.action == "nl.paskluis.GIFT_OPEN"
                    if (opened) intent.action = Intent.ACTION_MAIN
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == "nl.paskluis.GIFT_OPEN" && remindersReady) {
            reminders?.invokeMethod("open",null)
            intent.action = Intent.ACTION_MAIN
        }
        setIntent(intent)
    }
}
