package nl.paskluis.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Screenshots are temporarily allowed during the test phase.
        // Re-enable FLAG_SECURE before the production release.
    }
}
