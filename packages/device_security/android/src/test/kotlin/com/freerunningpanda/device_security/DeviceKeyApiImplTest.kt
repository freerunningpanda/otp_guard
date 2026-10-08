package com.freerunningpanda.device_security

import android.app.KeyguardManager
import android.content.Context
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/*
 * Only isDeviceSecure is tested here. The key operations need the AndroidKeyStore provider,
 * which does not exist on the JVM, so they can be checked only on a device or an emulator.
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

    private fun contextWith(keyguardManager: KeyguardManager?): Context {
        val context = Mockito.mock(Context::class.java)
        Mockito.`when`(context.getSystemService(KeyguardManager::class.java))
            .thenReturn(keyguardManager)
        return context
    }
}
