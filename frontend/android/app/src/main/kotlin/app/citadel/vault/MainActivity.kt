package app.citadel.vault

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * FlutterFragmentActivity (not FlutterActivity) is required by BiometricPrompt
 * and by the local_auth plugin.
 */
class MainActivity : FlutterFragmentActivity() {
    private var security: SecurityChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        security = SecurityChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        security?.dispose()
        security = null
        super.onDestroy()
    }
}
