package app.citadel.vault

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Platform security bridge.
 *
 * Biometric unlock design: a 256-bit AES-GCM key lives in the Android Keystore
 * (StrongBox when available) with `setUserAuthenticationRequired(true)`. The
 * key material never leaves secure hardware and the OS will only perform an
 * encrypt/decrypt with it inside a BiometricPrompt authenticated with a
 * CryptoObject. The vault key (VEK) is wrapped with this key; the wrapped blob
 * is stored by Dart. A successful fingerprint therefore *releases a key* - it is
 * not a boolean gate that could be bypassed by patching the app.
 *
 * The key is invalidated by the OS when biometrics are re-enrolled, which
 * forces a master-password unlock.
 */
class SecurityChannel(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "setSecureScreen" -> {
                    setSecureScreen(call.argument<Boolean>("enabled") ?: true)
                    result.success(null)
                }
                "copyToClipboard" -> {
                    copyToClipboard(
                        call.argument<String>("text") ?: "",
                        call.argument<Boolean>("sensitive") ?: true,
                    )
                    result.success(null)
                }
                "clearClipboardIfMatches" ->
                    result.success(clearClipboardIfMatches(call.argument<String>("sha256") ?: ""))
                "biometricStatus" -> result.success(biometricStatus())
                "biometricEncrypt" -> biometricEncrypt(call, result)
                "biometricDecrypt" -> biometricDecrypt(call, result)
                "biometricDeleteKey" -> {
                    deleteKey()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Never include payloads in error messages.
            result.error("native_error", e.javaClass.simpleName, null)
        }
    }

    // ---------------------------------------------------------------- screen

    private fun setSecureScreen(enabled: Boolean) {
        activity.runOnUiThread {
            if (enabled) {
                activity.window.setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE,
                )
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    // ------------------------------------------------------------- clipboard

    private fun clipboard(): ClipboardManager =
        activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    private fun copyToClipboard(text: String, sensitive: Boolean) {
        val clip = ClipData.newPlainText("Citadel", text)
        if (sensitive) {
            // Hides the value from the Android 13+ clipboard preview overlay
            // and keyboard clipboard suggestions that honour the flag.
            clip.description.extras = PersistableBundle().apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                } else {
                    putBoolean("android.content.extra.IS_SENSITIVE", true)
                }
            }
        }
        clipboard().setPrimaryClip(clip)
    }

    /**
     * Clears the clipboard only if it still holds the value we copied
     * (compared by SHA-256 so the plaintext never crosses the channel twice).
     * Returns: "cleared", "changed", "empty" or "unreadable" (Android 10+
     * blocks clipboard reads while the app does not have focus).
     */
    private fun clearClipboardIfMatches(expectedSha256: String): String {
        val cm = clipboard()
        if (!cm.hasPrimaryClip()) return "empty"
        val clip = cm.primaryClip ?: return "unreadable"
        if (clip.itemCount == 0) return "empty"
        val text = clip.getItemAt(0).coerceToText(activity)?.toString() ?: return "unreadable"
        val digest = MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))
        val hex = digest.joinToString("") { "%02x".format(it) }
        if (!MessageDigest.isEqual(hex.toByteArray(), expectedSha256.lowercase().toByteArray())) {
            return "changed"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            cm.clearPrimaryClip()
        } else {
            cm.setPrimaryClip(ClipData.newPlainText("", ""))
        }
        return "cleared"
    }

    // ------------------------------------------------------------- biometric

    private fun authenticators(allowDeviceCredential: Boolean): Int =
        if (allowDeviceCredential && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            BIOMETRIC_STRONG or DEVICE_CREDENTIAL
        } else {
            BIOMETRIC_STRONG
        }

    private fun biometricStatus(): Map<String, Any> {
        val bm = BiometricManager.from(activity)
        val strong = bm.canAuthenticate(BIOMETRIC_STRONG)
        val withCredential =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                bm.canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            } else {
                BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED
            }
        return mapOf(
            "strongBiometric" to (strong == BiometricManager.BIOMETRIC_SUCCESS),
            "strongBiometricCode" to strong,
            "deviceCredential" to (withCredential == BiometricManager.BIOMETRIC_SUCCESS),
            "noneEnrolled" to (strong == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED),
            "keyExists" to keyExists(),
        )
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun keyExists(): Boolean = keyStore().containsAlias(KEY_ALIAS)

    private fun deleteKey() {
        val ks = keyStore()
        if (ks.containsAlias(KEY_ALIAS)) ks.deleteEntry(KEY_ALIAS)
    }

    private fun createKey(allowDeviceCredential: Boolean): SecretKey {
        deleteKey()
        fun build(strongBox: Boolean): KeyGenParameterSpec {
            val b = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val types = if (allowDeviceCredential) {
                    KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
                } else {
                    KeyProperties.AUTH_BIOMETRIC_STRONG
                }
                // 0 seconds = every single use requires a fresh authentication.
                b.setUserAuthenticationParameters(0, types)
            }
            if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                b.setIsStrongBoxBacked(true)
            }
            return b.build()
        }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        // Prefer StrongBox (dedicated secure element). Many devices lack it or
        // reject some parameter combinations there, so fall back to the TEE.
        return try {
            generator.init(build(strongBox = true))
            generator.generateKey()
        } catch (e: StrongBoxUnavailableException) {
            generator.init(build(strongBox = false))
            generator.generateKey()
        } catch (e: java.security.ProviderException) {
            generator.init(build(strongBox = false))
            generator.generateKey()
        }
    }

    private fun loadKey(): SecretKey? = keyStore().getKey(KEY_ALIAS, null) as? SecretKey

    private fun biometricEncrypt(call: MethodCall, result: MethodChannel.Result) {
        val plain = call.argument<ByteArray>("data") ?: return result.error("bad_args", "data", null)
        val allowCred = call.argument<Boolean>("allowDeviceCredential") ?: false
        val key = createKey(allowCred)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        prompt(call, cipher, allowCred, result) { c ->
            val ct = c.doFinal(plain)
            mapOf("iv" to c.iv, "ct" to ct)
        }
    }

    private fun biometricDecrypt(call: MethodCall, result: MethodChannel.Result) {
        val iv = call.argument<ByteArray>("iv") ?: return result.error("bad_args", "iv", null)
        val ct = call.argument<ByteArray>("ct") ?: return result.error("bad_args", "ct", null)
        val allowCred = call.argument<Boolean>("allowDeviceCredential") ?: false
        val key = loadKey() ?: return result.error("no_key", "Biometric key missing", null)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        try {
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
        } catch (e: KeyPermanentlyInvalidatedException) {
            deleteKey()
            return result.error("invalidated", "Biometric enrollment changed", null)
        }
        prompt(call, cipher, allowCred, result) { c -> c.doFinal(ct) }
    }

    private fun prompt(
        call: MethodCall,
        cipher: Cipher,
        allowDeviceCredential: Boolean,
        result: MethodChannel.Result,
        onCipher: (Cipher) -> Any,
    ) {
        val title = call.argument<String>("title") ?: "Unlock vault"
        val subtitle = call.argument<String>("subtitle")
        val builder = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setConfirmationRequired(false)
            .setAllowedAuthenticators(authenticators(allowDeviceCredential))
        if (subtitle != null) builder.setSubtitle(subtitle)
        if (!(allowDeviceCredential && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)) {
            builder.setNegativeButtonText(call.argument<String>("cancel") ?: "Use master password")
        }

        var replied = false
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(res: BiometricPrompt.AuthenticationResult) {
                if (replied) return
                replied = true
                try {
                    val c = res.cryptoObject?.cipher
                        ?: return result.error("no_cipher", "No crypto object", null)
                    result.success(onCipher(c))
                } catch (e: Exception) {
                    result.error("crypto_failed", e.javaClass.simpleName, null)
                }
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                if (replied) return
                replied = true
                val code = when (errorCode) {
                    BiometricPrompt.ERROR_USER_CANCELED,
                    BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                    BiometricPrompt.ERROR_CANCELED -> "cancelled"
                    BiometricPrompt.ERROR_LOCKOUT,
                    BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "lockout"
                    else -> "auth_error"
                }
                result.error(code, errString.toString(), errorCode)
            }
        }
        activity.runOnUiThread {
            BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), callback)
                .authenticate(builder.build(), BiometricPrompt.CryptoObject(cipher))
        }
    }

    companion object {
        const val CHANNEL = "app.citadel.vault/security"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "citadel_biometric_vek_wrap_v1"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
