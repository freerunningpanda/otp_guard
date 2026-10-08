package com.freerunningpanda.device_security

import android.app.KeyguardManager
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.GeneralSecurityException
import java.security.KeyPairGenerator
import java.security.KeyStore
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
internal class DeviceKeyApiImpl(private val context: Context) : DeviceKeyApi {
    // True when a PIN, a pattern or a password is set: the user can be asked to prove they own
    // the device. Without a screen lock there is nothing to protect the keys with.
    override fun isDeviceSecure(): Boolean {
        val keyguardManager = context.getSystemService(KeyguardManager::class.java)
            ?: throw FlutterError("UNAVAILABLE", "The keyguard service is not available", null)
        return keyguardManager.isDeviceSecure
    }

    // Returns the public key as X.509 SubjectPublicKeyInfo in DER, which is what
    // PublicKey.encoded gives.
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
            generator.generateKeyPair().public.encoded
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
