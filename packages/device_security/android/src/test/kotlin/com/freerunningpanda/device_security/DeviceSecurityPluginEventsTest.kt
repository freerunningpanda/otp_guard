package com.freerunningpanda.device_security

import android.app.Activity
import android.os.Build
import android.view.Window
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito
import java.util.concurrent.Executor
import java.util.function.Consumer
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/*
 * Tests of the events channel: which system callbacks are registered and when, and which events
 * they turn into. The system side is mocked, and the Android version is chosen per plugin.
 */

internal class DeviceSecurityPluginEventsTest {
    private val executor = Mockito.mock(Executor::class.java)
    private val windowManager = Mockito.mock(WindowManager::class.java)
    private val activity = newActivity()
    private val sink = Mockito.mock(EventChannel.EventSink::class.java)

    @Test
    fun onListen_onAndroid15_registersBothCallbacksOnTheMainExecutor() {
        val plugin = DeviceSecurityPlugin(Build.VERSION_CODES.VANILLA_ICE_CREAM)

        plugin.onAttachedToActivity(binding(activity))
        plugin.onListen(null, sink)

        Mockito.verify(activity).registerScreenCaptureCallback(eq(executor), any())
        Mockito.verify(windowManager).addScreenRecordingCallback(eq(executor), any())
    }

    @Test
    fun onListen_onAndroid14_registersOnlyTheScreenCaptureCallback() {
        val plugin = DeviceSecurityPlugin(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)

        plugin.onAttachedToActivity(binding(activity))
        plugin.onListen(null, sink)

        Mockito.verify(activity).registerScreenCaptureCallback(eq(executor), any())
        Mockito.verifyNoInteractions(windowManager)
    }

    @Test
    fun onListen_onAndroid13_registersNothing() {
        val plugin = DeviceSecurityPlugin(Build.VERSION_CODES.TIRAMISU)

        plugin.onAttachedToActivity(binding(activity))
        plugin.onListen(null, sink)

        Mockito.verify(activity, Mockito.never()).registerScreenCaptureCallback(any(), any())
        Mockito.verifyNoInteractions(windowManager)
        Mockito.verifyNoInteractions(sink)
    }

    @Test
    fun screenCaptured_sendsScreenshotTakenWithTimestamp() {
        val plugin = listeningPlugin()
        val callback = registeredScreenCaptureCallback()

        val before = System.currentTimeMillis()
        callback.onScreenCaptured()
        val after = System.currentTimeMillis()

        val event = sentEvent()
        assertEquals("screenshotTaken", event["type"])
        val timestamp = event["timestamp"]
        assertTrue(timestamp is Long && timestamp in before..after)
        assertEquals(2, event.size)
        plugin.onCancel(null)
    }

    @Test
    fun screenRecordingStateChanged_sendsScreenRecordingChanged() {
        listeningPlugin()
        val callback = registeredScreenRecordingCallback()

        callback.accept(WindowManager.SCREEN_RECORDING_STATE_VISIBLE)
        callback.accept(WindowManager.SCREEN_RECORDING_STATE_NOT_VISIBLE)

        val events = sentEvents(2)
        assertEquals("screenRecordingChanged", events[0]["type"])
        assertEquals(true, events[0]["isRecording"])
        assertTrue(events[0]["timestamp"] is Long)
        assertEquals("screenRecordingChanged", events[1]["type"])
        assertEquals(false, events[1]["isRecording"])
    }

    @Test
    fun onListen_whileRecordingAlreadyRuns_sendsTheCurrentStateAtOnce() {
        Mockito.`when`(windowManager.addScreenRecordingCallback(any(), any()))
            .thenReturn(WindowManager.SCREEN_RECORDING_STATE_VISIBLE)

        listeningPlugin()

        val event = sentEvent()
        assertEquals("screenRecordingChanged", event["type"])
        assertEquals(true, event["isRecording"])
    }

    @Test
    fun onListen_whileNotRecording_sendsNothing() {
        listeningPlugin()

        Mockito.verifyNoInteractions(sink)
    }

    @Test
    fun onCancel_unregistersTheSameCallbacksAndStopsEvents() {
        val plugin = listeningPlugin()
        val screenCapture = registeredScreenCaptureCallback()
        val screenRecording = registeredScreenRecordingCallback()

        plugin.onCancel(null)
        screenCapture.onScreenCaptured()
        screenRecording.accept(WindowManager.SCREEN_RECORDING_STATE_VISIBLE)

        Mockito.verify(activity).unregisterScreenCaptureCallback(screenCapture)
        Mockito.verify(windowManager).removeScreenRecordingCallback(screenRecording)
        Mockito.verifyNoInteractions(sink)
    }

    @Test
    fun onListen_beforeTheActivityIsAttached_registersWhenItAttaches() {
        val plugin = DeviceSecurityPlugin(Build.VERSION_CODES.VANILLA_ICE_CREAM)

        plugin.onListen(null, sink)
        Mockito.verify(activity, Mockito.never()).registerScreenCaptureCallback(any(), any())

        plugin.onAttachedToActivity(binding(activity))

        Mockito.verify(activity).registerScreenCaptureCallback(eq(executor), any())
        Mockito.verify(windowManager).addScreenRecordingCallback(eq(executor), any())
    }

    @Test
    fun onAttachedToActivity_withoutAListener_registersNothing() {
        val plugin = DeviceSecurityPlugin(Build.VERSION_CODES.VANILLA_ICE_CREAM)

        plugin.onAttachedToActivity(binding(activity))

        Mockito.verify(activity, Mockito.never()).registerScreenCaptureCallback(any(), any())
        Mockito.verifyNoInteractions(windowManager)
    }

    @Test
    fun onListen_afterOnCancel_registersAgain() {
        val plugin = listeningPlugin()

        plugin.onCancel(null)
        plugin.onListen(null, sink)

        Mockito.verify(activity, Mockito.times(2)).registerScreenCaptureCallback(eq(executor), any())
        Mockito.verify(activity).unregisterScreenCaptureCallback(any())
    }

    @Test
    fun onDetachedFromActivity_unregistersBeforeTheActivityIsForgotten() {
        val plugin = listeningPlugin()
        val screenCapture = registeredScreenCaptureCallback()
        val screenRecording = registeredScreenRecordingCallback()

        plugin.onDetachedFromActivity()

        Mockito.verify(activity).unregisterScreenCaptureCallback(screenCapture)
        Mockito.verify(windowManager).removeScreenRecordingCallback(screenRecording)
    }

    @Test
    fun onReattachedToActivityForConfigChanges_registersOnTheNewActivity() {
        val plugin = listeningPlugin()
        val newWindowManager = Mockito.mock(WindowManager::class.java)
        val newActivity = newActivity(newWindowManager)

        plugin.onDetachedFromActivityForConfigChanges()
        plugin.onReattachedToActivityForConfigChanges(binding(newActivity))

        Mockito.verify(activity).unregisterScreenCaptureCallback(any())
        Mockito.verify(newActivity).registerScreenCaptureCallback(eq(executor), any())
        Mockito.verify(newWindowManager).addScreenRecordingCallback(eq(executor), any())
    }

    private fun listeningPlugin(): DeviceSecurityPlugin {
        val plugin = DeviceSecurityPlugin(Build.VERSION_CODES.VANILLA_ICE_CREAM)
        plugin.onAttachedToActivity(binding(activity))
        plugin.onListen(null, sink)
        return plugin
    }

    private fun registeredScreenCaptureCallback(): Activity.ScreenCaptureCallback {
        val captor = ArgumentCaptor.forClass(Activity.ScreenCaptureCallback::class.java)
        Mockito.verify(activity).registerScreenCaptureCallback(eq(executor), captor.capture())
        return captor.value
    }

    @Suppress("UNCHECKED_CAST")
    private fun registeredScreenRecordingCallback(): Consumer<Int> {
        val captor = ArgumentCaptor.forClass(Consumer::class.java) as ArgumentCaptor<Consumer<Int>>
        Mockito.verify(windowManager).addScreenRecordingCallback(eq(executor), captor.capture())
        return captor.value
    }

    private fun sentEvent(): Map<*, *> = sentEvents(1).single()

    private fun sentEvents(count: Int): List<Map<*, *>> {
        val captor = ArgumentCaptor.forClass(Any::class.java)
        Mockito.verify(sink, Mockito.times(count)).success(captor.capture())
        return captor.allValues.map { it as Map<*, *> }
    }

    private fun newActivity(manager: WindowManager = windowManager): Activity {
        val activity = Mockito.mock(Activity::class.java)
        Mockito.`when`(activity.window).thenReturn(Mockito.mock(Window::class.java))
        Mockito.`when`(activity.mainExecutor).thenReturn(executor)
        Mockito.`when`(activity.windowManager).thenReturn(manager)
        return activity
    }

    private fun binding(activity: Activity): ActivityPluginBinding {
        val binding = Mockito.mock(ActivityPluginBinding::class.java)
        Mockito.`when`(binding.activity).thenReturn(activity)
        return binding
    }
}
