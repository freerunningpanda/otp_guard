package com.freerunningpanda.device_security

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import java.security.GeneralSecurityException
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.ProviderException
import java.security.spec.ECGenParameterSpec

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
    private val sdkInt: Int = Build.VERSION.SDK_INT
) : DeviceKeyApi {
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
    override fun generateKey(alias: String): ByteArray {
        return keystoreCall("KEY_GENERATION_FAILED") {
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
            generator.initialize(
                KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                    .setAlgorithmParameterSpec(ECGenParameterSpec(CURVE))
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .build()
            )
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

    // The Android Keystore as a KeyStore object. load(null) is required before first use: the
    // Android Keystore has no file or password to load, but the object must be initialized.
    // The facts the Keystore keeps about a private key, among them where it lives. The key
    // factory of the Keystore is asked for them, as the key itself is only a handle.
    private fun keyInfo(privateKey: PrivateKey): KeyInfo {
        val factory = KeyFactory.getInstance(privateKey.algorithm, ANDROID_KEYSTORE)
        return factory.getKeySpec(privateKey, KeyInfo::class.java)
    }

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
    }
}

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
