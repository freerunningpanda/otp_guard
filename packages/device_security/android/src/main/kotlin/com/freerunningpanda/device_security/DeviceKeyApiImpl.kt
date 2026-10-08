package com.freerunningpanda.device_security

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.security.GeneralSecurityException
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.ProviderException
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * The keys of the device, kept in the Android Keystore: the private key never leaves it. The
 * Pigeon-generated DeviceKeyApi is the contract with Dart: Dart calls a method of it, and the
 * generated code runs the method below and sends the result back. A thrown FlutterError reaches
 * Dart as a PlatformException with the same code and message.
 *
 * The PrivateKey object that Java gives for a Keystore key is only a handle. The key bytes
 * cannot be read from it: the app can only ask the Keystore to use the key.
 */
internal class DeviceKeyApiImpl(
    private val context: Context,
    // The Android version the hardware check is made for. A parameter so that tests can pick one.
    private val sdkInt: Int = Build.VERSION.SDK_INT,
    // The Activity the biometric prompt is shown in. Asked at the moment of signing, because the
    // Activity can change over the life of the plugin.
    private val activityProvider: () -> Activity? = { null }
) : DeviceKeyApi {
    // The biometric prompt that is on the screen, null otherwise. One prompt at a time.
    private var pendingPrompt: BiometricPrompt? = null

    // True when a PIN, a pattern or a password is set: the user can be asked to prove they own
    // the device. Without a screen lock there is nothing to protect the keys with.
    override fun isDeviceSecure(): Boolean {
        val keyguardManager = context.getSystemService(KeyguardManager::class.java)
            ?: throw FlutterError("UNAVAILABLE", "The keyguard service is not available", null)
        return keyguardManager.isDeviceSecure
    }

    // Returns the public key as X.509 SubjectPublicKeyInfo in DER, which is what
    // PublicKey.encoded gives.
    //
    // The key must live in secure hardware (TEE or StrongBox), as it must in the Secure Enclave
    // on iOS. Without such hardware (an emulator, some cheap devices) the Keystore still creates
    // the key, but in software, and the app could not tell. So the key is checked after it is
    // created, and a software key is deleted and refused with UNAVAILABLE, the same as on iOS.
    //
    // The key also requires biometrics for every use. The secure hardware enforces that, not
    // this code, so there is no check in the app to bypass.
    override fun generateKey(alias: String): ByteArray {
        return keystoreCall("KEY_GENERATION_FAILED") {
            // Without enrolled biometrics the key could be made, but never used. Say so now.
            requireBiometrics()
            // The generator would silently replace an existing key, and a server that knows the
            // old public key would then reject every signature.
            if (keyStore().containsAlias(alias)) {
                throw FlutterError("KEY_EXISTS", "A key with the alias '$alias' already exists", null)
            }
            // A generator of elliptic-curve keys that works inside the Android Keystore: the
            // private key is created there, in secure hardware where the device has it, and
            // never exists in the memory of the app.
            val generator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                ANDROID_KEYSTORE
            )
            // What to create and how the key may be used. The alias is its name in the
            // Keystore. It can only sign (not decrypt), on the P-256 curve, with SHA-256.
            val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec(CURVE))
                .setDigests(KeyProperties.DIGEST_SHA256)
                // The hardware lets the key be used only after the user authenticates.
                .setUserAuthenticationRequired(true)
                // When a fingerprint or a face is added, the key stops working for good. Without
                // this, a stranger who adds their own finger would get access.
                .setInvalidatedByBiometricEnrollment(true)
            if (sdkInt >= Build.VERSION_CODES.R) {
                // Spell out the default: authentication for every single use (timeout 0), by a
                // strong biometric only, not by the PIN.
                spec.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            }
            generator.initialize(spec.build())
            // Creates the pair in the Keystore. Only the public key is taken from it: its
            // `encoded` form is the DER bytes that go to the server.
            val keyPair = generator.generateKeyPair()
            // Where the key lives is known only now. If the check fails or finds a software key,
            // the key is deleted, so a refused call leaves nothing behind.
            var hardwareBacked = false
            try {
                hardwareBacked = isHardwareBacked(keyInfo(keyPair.private), sdkInt)
            } finally {
                if (!hardwareBacked) keyStore().deleteEntry(alias)
            }
            if (!hardwareBacked) {
                throw FlutterError(
                    "UNAVAILABLE",
                    "The key could not be created in secure hardware (TEE or StrongBox)",
                    null
                )
            }
            keyPair.public.encoded
        }
    }

    override fun hasKey(alias: String): Boolean {
        return keystoreCall("KEY_STORE_FAILED") { keyStore().containsAlias(alias) }
    }

    // Deleting an alias that does not exist is not an error: the end result is the same.
    override fun deleteKey(alias: String) {
        keystoreCall("KEY_STORE_FAILED") { keyStore().deleteEntry(alias) }
    }

    // Pigeon calls this as a suspend function: it waits for the user without blocking a thread.
    // The work is done by signWithPrompt, which reports through a callback, because the
    // biometric prompt answers through callbacks. Here the callback resumes the suspended call.
    override suspend fun sign(
        alias: String,
        challenge: ByteArray,
        title: String,
        subtitle: String?,
        cancelText: String
    ): ByteArray {
        return suspendCancellableCoroutine { continuation ->
            signWithPrompt(alias, challenge, title, subtitle, cancelText) { result ->
                continuation.resumeWith(result)
            }
            continuation.invokeOnCancellation { cancelPendingSign() }
        }
    }

    // Shows the biometric prompt and, when the user passes it, signs the challenge. The result,
    // a signature or a FlutterError, goes to the callback exactly once.
    //
    // The texts of the prompt come from the app: title, an optional subtitle and the label of the
    // cancel button. The plugin has no texts of its own, so the app can translate them and word
    // them for its scenario.
    //
    // The biometric check is not a gate in front of the signature. The Signature object is
    // initialized with the private key first, and the hardware lets it work only after the
    // prompt succeeds: the prompt receives the object as a CryptoObject and unlocks it.
    internal fun signWithPrompt(
        alias: String,
        challenge: ByteArray,
        title: String,
        subtitle: String?,
        cancelText: String,
        callback: (Result<ByteArray>) -> Unit
    ) {
        try {
            // BiometricPrompt refuses a prompt without a title or a cancel button, with an
            // exception that would be an obscure crash. Say what is wrong instead.
            if (title.isBlank() || cancelText.isBlank()) {
                throw FlutterError("INVALID_ARGUMENT", "title and cancelText must not be empty", null)
            }
            val activity = activityProvider()
                ?: throw FlutterError("NO_ACTIVITY", "Signing requires an attached Activity", null)
            // BiometricPrompt works only with a FragmentActivity. A plain FlutterActivity is not
            // one, and the app has to switch to FlutterFragmentActivity.
            val fragmentActivity = activity as? FragmentActivity
                ?: throw FlutterError(
                    "ACTIVITY_NOT_SUPPORTED",
                    "Signing needs a FragmentActivity: let MainActivity extend FlutterFragmentActivity",
                    null
                )
            if (pendingPrompt != null) {
                throw FlutterError("SIGNING_IN_PROGRESS", "A biometric prompt is already shown", null)
            }
            val signature = initSignature(alias)

            val prompt = BiometricPrompt(
                fragmentActivity,
                ContextCompat.getMainExecutor(context),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        result: BiometricPrompt.AuthenticationResult
                    ) {
                        pendingPrompt = null
                        callback(signChallenge(result.cryptoObject?.signature, challenge))
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        pendingPrompt = null
                        callback(Result.failure(biometricError(errorCode, errString)))
                    }

                    // A finger that did not match. The prompt stays and the user may try again,
                    // so this is not an end of the call.
                    override fun onAuthenticationFailed() = Unit
                }
            )
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle(title)
                .setSubtitle(subtitle)
                .setNegativeButtonText(cancelText)
                // A CryptoObject can be unlocked only by a strong biometric.
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .build()
            pendingPrompt = prompt
            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(signature))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: KeyPermanentlyInvalidatedException) {
            // The fingerprints or faces changed. The key is meant to stop working then, so this
            // is a normal case: the app creates a new key and registers it again.
            callback(Result.failure(FlutterError("KEY_INVALIDATED", KEY_INVALIDATED_MESSAGE, null)))
        } catch (e: GeneralSecurityException) {
            callback(Result.failure(FlutterError("SIGNING_FAILED", e.message, null)))
        } catch (e: ProviderException) {
            callback(Result.failure(FlutterError("SIGNING_FAILED", e.message, null)))
        }
    }

    // Closes the prompt that is on the screen, for example when its Activity goes away. The
    // prompt reports ERROR_CANCELED, so the waiting call ends with USER_CANCELED instead of
    // waiting forever.
    fun cancelPendingSign() {
        pendingPrompt?.cancelAuthentication()
    }

    // A Signature ready for signing with the key of the alias, still locked: the hardware
    // unlocks it only after the biometric prompt succeeds.
    private fun initSignature(alias: String): Signature {
        val privateKey = keyStore().getKey(alias, null) as? PrivateKey
            ?: throw FlutterError("KEY_NOT_FOUND", "No key with the alias '$alias'", null)
        // ECDSA over the SHA-256 of the data. The result is a DER signature, the same on iOS.
        return Signature.getInstance(SIGNATURE_ALGORITHM).apply { initSign(privateKey) }
    }

    // BIOMETRIC_STRONG is the class of biometrics that can unlock a key. Anything else than a
    // plain "yes" means the user cannot sign: no sensor, nothing enrolled, a security update
    // is pending, and so on.
    private fun requireBiometrics() {
        val status = BiometricManager.from(context)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        if (status != BiometricManager.BIOMETRIC_SUCCESS) {
            throw FlutterError(
                "BIOMETRY_UNAVAILABLE",
                "Strong biometrics are not set up or not available (status $status)",
                null
            )
        }
    }

    // The facts the Keystore keeps about a private key, among them where it lives. The key
    // factory of the Keystore is asked for them, as the key itself is only a handle.
    private fun keyInfo(privateKey: PrivateKey): KeyInfo {
        val factory = KeyFactory.getInstance(privateKey.algorithm, ANDROID_KEYSTORE)
        return factory.getKeySpec(privateKey, KeyInfo::class.java)
    }

    // The Android Keystore as a KeyStore object. load(null) is required before first use: the
    // Android Keystore has no file or password to load, but the object must be initialized.
    private fun keyStore(): KeyStore {
        return KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    // Runs the block and turns Keystore failures into a FlutterError, which Pigeon delivers to
    // Dart as a PlatformException. A FlutterError thrown inside the block (KEY_EXISTS) is not a
    // GeneralSecurityException or a ProviderException, so it passes through unchanged. `inline`
    // lets the block return a value to the caller with no extra cost.
    private inline fun <T> keystoreCall(code: String, block: () -> T): T {
        try {
            return block()
        } catch (e: GeneralSecurityException) {
            throw FlutterError(code, e.message, null)
        } catch (e: ProviderException) {
            throw FlutterError(code, e.message, null)
        }
    }

    private companion object {
        // The name of the Keystore provider, fixed by Android.
        const val ANDROID_KEYSTORE = "AndroidKeyStore"

        // secp256r1 is the same curve as P-256 and prime256v1: three names for one thing.
        const val CURVE = "secp256r1"

        const val SIGNATURE_ALGORITHM = "SHA256withECDSA"
    }
}

internal const val KEY_INVALIDATED_MESSAGE =
    "The biometrics changed, so the key is no longer valid. Create a new key and register it again"

// Whether the key lives in secure hardware. Since Android 12 (API 31) the Keystore tells where
// exactly: the TEE, the StrongBox chip, or a hardware level it cannot name. Before that there is
// only a yes or no. A software key, or an unknown level, does not count.
internal fun isHardwareBacked(keyInfo: KeyInfo, sdkInt: Int): Boolean {
    if (sdkInt >= Build.VERSION_CODES.S) {
        return when (keyInfo.securityLevel) {
            KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT,
            KeyProperties.SECURITY_LEVEL_STRONGBOX,
            KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE -> true
            else -> false
        }
    }
    @Suppress("DEPRECATION")
    return keyInfo.isInsideSecureHardware
}

// Signs the challenge with the Signature that the successful biometric prompt unlocked. The
// result is the DER signature, or a FlutterError if the signing fails.
internal fun signChallenge(signature: Signature?, challenge: ByteArray): Result<ByteArray> {
    if (signature == null) {
        return Result.failure(
            FlutterError("SIGNING_FAILED", "The biometric result carries no signature", null)
        )
    }
    return try {
        signature.update(challenge)
        Result.success(signature.sign())
    } catch (e: GeneralSecurityException) {
        Result.failure(FlutterError("SIGNING_FAILED", e.message, null))
    }
}

// Turns the error code of the biometric prompt into the error that Dart gets: the user closed
// the prompt, biometrics cannot be used, or something else went wrong.
internal fun biometricError(errorCode: Int, message: CharSequence): FlutterError {
    return when (errorCode) {
        BiometricPrompt.ERROR_USER_CANCELED,
        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
        BiometricPrompt.ERROR_CANCELED ->
            FlutterError("USER_CANCELED", "The user closed the biometric prompt", null)

        BiometricPrompt.ERROR_NO_BIOMETRICS,
        BiometricPrompt.ERROR_HW_NOT_PRESENT,
        BiometricPrompt.ERROR_HW_UNAVAILABLE,
        BiometricPrompt.ERROR_LOCKOUT,
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
        BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL,
        BiometricPrompt.ERROR_SECURITY_UPDATE_REQUIRED ->
            FlutterError("BIOMETRY_UNAVAILABLE", message.toString(), null)

        else -> FlutterError("SIGNING_FAILED", message.toString(), null)
    }
}
