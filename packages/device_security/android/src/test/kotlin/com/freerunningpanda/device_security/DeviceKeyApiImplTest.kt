package com.freerunningpanda.device_security

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/*
 * isDeviceSecure and the hardware check are tested here. The key operations need the
 * AndroidKeyStore provider, which does not exist on the JVM, so they can be checked only on a
 * device or an emulator.
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
