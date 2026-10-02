package com.freerunningpanda.device_security

import android.app.Activity
import android.view.Window
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * Unit tests of the Kotlin portion of this plugin's implementation.
 *
 * The plugin has no example app, so the tests run through the main app's Gradle build:
 * `./gradlew :device_security:testDebugUnitTest` in the `android/` directory of the repository
 * root. They can also be run directly from IDEs that support JUnit such as Android Studio.
 */

internal class DeviceSecurityPluginTest {
    @Test
    fun onMethodCall_setScreenProtection_withoutActivity_returnsNoActivityError() {
        val plugin = DeviceSecurityPlugin()

        val call = MethodCall("setScreenProtection", mapOf("enabled" to true))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult)
            .error("NO_ACTIVITY", "Screen protection requires an attached Activity", null)
        Mockito.verifyNoMoreInteractions(mockResult)
    }

    @Test
    fun onMethodCall_setScreenProtection_withoutEnabled_returnsInvalidArgumentError() {
        val plugin = DeviceSecurityPlugin()

        val call = MethodCall("setScreenProtection", emptyMap<String, Any>())
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult)
            .error("INVALID_ARGUMENT", "Argument 'enabled' (bool) is required", null)
        Mockito.verifyNoMoreInteractions(mockResult)
    }

    @Test
    fun onAttachedToActivity_afterProtectionEnabled_reappliesFlagToNewWindow() {
        val plugin = DeviceSecurityPlugin()
        val firstWindow = Mockito.mock(Window::class.java)
        val secondWindow = Mockito.mock(Window::class.java)

        plugin.onAttachedToActivity(bindingWithWindow(firstWindow))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("setScreenProtection", mapOf("enabled" to true)), mockResult)
        plugin.onDetachedFromActivity()
        plugin.onAttachedToActivity(bindingWithWindow(secondWindow))

        Mockito.verify(mockResult).success(null)
        Mockito.verify(firstWindow).addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        Mockito.verify(secondWindow).addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    @Test
    fun onReattachedToActivityForConfigChanges_afterProtectionEnabled_reappliesFlagToNewWindow() {
        val plugin = DeviceSecurityPlugin()
        val firstWindow = Mockito.mock(Window::class.java)
        val secondWindow = Mockito.mock(Window::class.java)

        plugin.onAttachedToActivity(bindingWithWindow(firstWindow))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("setScreenProtection", mapOf("enabled" to true)), mockResult)
        plugin.onDetachedFromActivityForConfigChanges()
        plugin.onReattachedToActivityForConfigChanges(bindingWithWindow(secondWindow))

        Mockito.verify(secondWindow).addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    @Test
    fun onAttachedToActivity_afterProtectionDisabled_leavesNewWindowUntouched() {
        val plugin = DeviceSecurityPlugin()
        val firstWindow = Mockito.mock(Window::class.java)
        val secondWindow = Mockito.mock(Window::class.java)

        plugin.onAttachedToActivity(bindingWithWindow(firstWindow))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("setScreenProtection", mapOf("enabled" to true)), mockResult)
        plugin.onMethodCall(MethodCall("setScreenProtection", mapOf("enabled" to false)), mockResult)
        plugin.onDetachedFromActivity()
        plugin.onAttachedToActivity(bindingWithWindow(secondWindow))

        Mockito.verify(firstWindow).clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        Mockito.verifyNoInteractions(secondWindow)
    }

    private fun bindingWithWindow(window: Window): ActivityPluginBinding {
        val activity = Mockito.mock(Activity::class.java)
        Mockito.`when`(activity.window).thenReturn(window)
        val binding = Mockito.mock(ActivityPluginBinding::class.java)
        Mockito.`when`(binding.activity).thenReturn(activity)
        return binding
    }
}
