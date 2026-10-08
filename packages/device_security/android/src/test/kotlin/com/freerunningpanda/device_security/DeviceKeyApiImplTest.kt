package com.freerunningpanda.device_security

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricPrompt
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertContentEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/*
 * isDeviceSecure, the hardware check and the parts of signing that do not need the Keystore or
 * a real biometric prompt are tested here. The key operations need the AndroidKeyStore provider,
 * which does not exist on the JVM, and the prompt needs a device with biometrics, so those can
 * be checked only on a device.
 */

internal class DeviceKeyApiImplTest {
    @Test
    fun isDeviceSecure_returnsWhatTheKeyguardReports() {
        for (secure in listOf(true, false)) {
            val keyguardManager = Mockito.mock(KeyguardManager::class.java)
            Mockito.`when`(keyguardManager.isDeviceSecure).thenReturn(secure)

            val api = DeviceKeyApiImpl(contextWith(keyguardManager))

            assertEquals(secure, api.isDeviceSecure())
        }
    }

    @Test
    fun isDeviceSecure_withoutKeyguardService_throwsUnavailable() {
        val api = DeviceKeyApiImpl(contextWith(null))

        val error = assertFailsWith<FlutterError> { api.isDeviceSecure() }

        assertEquals("UNAVAILABLE", error.code)
    }

    @Test
    fun isHardwareBacked_onAndroid12_acceptsTeeStrongBoxAndUnknownSecure() {
        for (level in listOf(
            KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT,
            KeyProperties.SECURITY_LEVEL_STRONGBOX,
            KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE
        )) {
            assertTrue(isHardwareBacked(keyInfoAtLevel(level), Build.VERSION_CODES.S), "level $level")
        }
    }

    @Test
    fun isHardwareBacked_onAndroid12_refusesSoftwareAndUnknown() {
        for (level in listOf(
            KeyProperties.SECURITY_LEVEL_SOFTWARE,
            KeyProperties.SECURITY_LEVEL_UNKNOWN
        )) {
            assertFalse(isHardwareBacked(keyInfoAtLevel(level), Build.VERSION_CODES.S), "level $level")
        }
    }

    @Test
    fun isHardwareBacked_beforeAndroid12_followsIsInsideSecureHardware() {
        for (inside in listOf(true, false)) {
            val keyInfo = Mockito.mock(KeyInfo::class.java)
            Mockito.`when`(keyInfo.isInsideSecureHardware).thenReturn(inside)

            assertEquals(inside, isHardwareBacked(keyInfo, Build.VERSION_CODES.R))
        }
    }

    @Test
    fun biometricError_userClosedThePrompt_isUserCanceled() {
        for (code in listOf(
            BiometricPrompt.ERROR_USER_CANCELED,
            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
            BiometricPrompt.ERROR_CANCELED
        )) {
            assertEquals("USER_CANCELED", biometricError(code, "closed").code, "code $code")
        }
    }

    @Test
    fun biometricError_biometricsCannotBeUsed_isBiometryUnavailable() {
        for (code in listOf(
            BiometricPrompt.ERROR_NO_BIOMETRICS,
            BiometricPrompt.ERROR_HW_NOT_PRESENT,
            BiometricPrompt.ERROR_HW_UNAVAILABLE,
            BiometricPrompt.ERROR_LOCKOUT,
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL,
            BiometricPrompt.ERROR_SECURITY_UPDATE_REQUIRED
        )) {
            assertEquals("BIOMETRY_UNAVAILABLE", biometricError(code, "no").code, "code $code")
        }
    }

    @Test
    fun biometricError_anythingElse_isSigningFailedWithTheMessage() {
        val error = biometricError(BiometricPrompt.ERROR_TIMEOUT, "timed out")

        assertEquals("SIGNING_FAILED", error.code)
        assertEquals("timed out", error.message)
    }

    @Test
    fun signChallenge_producesASignatureThatVerifiesWithThePublicKey() {
        // A software key stands in for the Keystore key: the signing code is the same.
        val generator = KeyPairGenerator.getInstance("EC")
        generator.initialize(ECGenParameterSpec("secp256r1"))
        val keyPair = generator.generateKeyPair()
        val signature = Signature.getInstance("SHA256withECDSA").apply { initSign(keyPair.private) }
        val challenge = "challenge from the server".toByteArray()

        val result = signChallenge(signature, challenge)

        val signed = assertNotNull(result.getOrNull())
        val verifier = Signature.getInstance("SHA256withECDSA").apply {
            initVerify(keyPair.public)
            update(challenge)
        }
        assertTrue(verifier.verify(signed))
        // A DER signature starts with the SEQUENCE tag.
        assertEquals(0x30.toByte(), signed[0])
    }

    @Test
    fun signChallenge_withoutASignature_failsWithSigningFailed() {
        val error = assertIs<FlutterError>(signChallenge(null, byteArrayOf(1)).exceptionOrNull())

        assertEquals("SIGNING_FAILED", error.code)
    }

    @Test
    fun signChallenge_withASignatureThatWasNotInitialized_failsWithSigningFailed() {
        val signature = Signature.getInstance("SHA256withECDSA")

        val error = assertIs<FlutterError>(signChallenge(signature, byteArrayOf(1)).exceptionOrNull())

        assertEquals("SIGNING_FAILED", error.code)
    }

    @Test
    fun signWithPrompt_withoutActivity_failsWithNoActivity() {
        val api = DeviceKeyApiImpl(contextWith(null), activityProvider = { null })

        val error = signErrorOf(api)

        assertEquals("NO_ACTIVITY", error.code)
    }

    @Test
    fun signWithPrompt_withAPlainActivity_failsWithActivityNotSupported() {
        val plainActivity = Mockito.mock(Activity::class.java)
        val api = DeviceKeyApiImpl(contextWith(null), activityProvider = { plainActivity })

        val error = signErrorOf(api)

        assertEquals("ACTIVITY_NOT_SUPPORTED", error.code)
        assertTrue(error.message.orEmpty().contains("FlutterFragmentActivity"))
    }

    @Test
    fun signWithPrompt_withAnEmptyTitleOrCancelText_failsWithInvalidArgument() {
        // The Activity is missing too, to show that the arguments are checked first.
        val api = DeviceKeyApiImpl(contextWith(null), activityProvider = { null })

        for ((title, cancelText) in listOf("" to "Cancel", "  " to "Cancel", "Title" to "")) {
            val error = signErrorOf(api, title = title, cancelText = cancelText)

            assertEquals("INVALID_ARGUMENT", error.code, "title '$title', cancel '$cancelText'")
        }
    }

    @Test
    fun cancelPendingSign_withNoPrompt_doesNothing() {
        DeviceKeyApiImpl(contextWith(null)).cancelPendingSign()
    }

    // Runs signWithPrompt and returns the error it reports. The callback must be called once.
    private fun signErrorOf(
        api: DeviceKeyApiImpl,
        title: String = "Confirm sign-in",
        subtitle: String? = null,
        cancelText: String = "Cancel"
    ): FlutterError {
        val results = mutableListOf<Result<ByteArray>>()
        api.signWithPrompt("alias", byteArrayOf(1, 2, 3), title, subtitle, cancelText) {
            results.add(it)
        }
        assertEquals(1, results.size)
        return assertIs<FlutterError>(results.single().exceptionOrNull())
    }

    private fun contextWith(keyguardManager: KeyguardManager?): Context {
        val context = Mockito.mock(Context::class.java)
        Mockito.`when`(context.getSystemService(KeyguardManager::class.java))
            .thenReturn(keyguardManager)
        return context
    }

    private fun keyInfoAtLevel(level: Int): KeyInfo {
        val keyInfo = Mockito.mock(KeyInfo::class.java)
        Mockito.`when`(keyInfo.securityLevel).thenReturn(level)
        return keyInfo
    }
}
