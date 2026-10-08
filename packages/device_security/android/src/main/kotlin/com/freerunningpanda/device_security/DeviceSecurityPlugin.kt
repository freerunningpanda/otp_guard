package com.freerunningpanda.device_security

import android.app.Activity
import android.os.Build
import android.view.WindowManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.function.Consumer

/** DeviceSecurityPlugin */
class DeviceSecurityPlugin(
    // The Android version the system callbacks are checked against. A parameter so that tests
    // can pick a version; the default no-argument constructor is the one Flutter calls.
    private val sdkInt: Int = Build.VERSION.SDK_INT
) :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler {
    // Carries method calls from Dart. Created in onAttachedToEngine and kept here so the
    // handler can be removed in onDetachedFromEngine.
    private lateinit var channel: MethodChannel

    // Carries security events to Dart. Kept for the same reason as channel.
    private lateinit var eventChannel: EventChannel

    // The Activity whose window gets FLAG_SECURE. Null whenever no Activity is attached,
    // so that a closed Activity is never kept alive by this reference.
    private var activity: Activity? = null

    // The state Dart last set successfully. FLAG_SECURE lives on the window of one Activity,
    // so it is re-applied from this field whenever a new Activity is attached.
    private var protectionEnabled = false

    // Set while Dart listens to the events channel, null otherwise.
    private var eventSink: EventChannel.EventSink? = null

    // The implementation of the key API. Kept to close its biometric prompt when the Activity
    // goes away.
    private var keyApi: DeviceKeyApiImpl? = null

    // The system callbacks while they are registered, null otherwise. Kept because
    // unregistering needs the same object that was registered.
    private var screenCaptureCallback: Activity.ScreenCaptureCallback? = null
    private var screenRecordingCallback: Consumer<Int>? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.freerunningpanda.device_security/methods"
        )
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "com.freerunningpanda.device_security/events"
        )
        eventChannel.setStreamHandler(this)
        // The Activity is asked for when a signature needs the biometric prompt.
        val keyApi = DeviceKeyApiImpl(
            flutterPluginBinding.applicationContext,
            activityProvider = { activity }
        )
        this.keyApi = keyApi
        DeviceKeyApi.setUp(flutterPluginBinding.binaryMessenger, keyApi)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method == "setScreenProtection") {
            val enabled = call.argument<Boolean>("enabled")
            if (enabled == null) {
                result.error("INVALID_ARGUMENT", "Argument 'enabled' (bool) is required", null)
                return
            }
            val activity = activity
            if (activity == null) {
                result.error("NO_ACTIVITY", "Screen protection requires an attached Activity", null)
                return
            }
            if (enabled) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            protectionEnabled = enabled
            result.success(null)
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        DeviceKeyApi.setUp(binding.binaryMessenger, null)
        keyApi = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        startWatching()
    }

    override fun onCancel(arguments: Any?) {
        stopWatching()
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    private fun attachActivity(newActivity: Activity) {
        activity = newActivity
        // A new Activity has a new window without the flag. Only add it here: clearing could
        // remove a FLAG_SECURE that the host app set on its own.
        if (protectionEnabled) {
            newActivity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        startWatching()
    }

    private fun detachActivity() {
        // Before the reference is cleared: unregistering needs the Activity.
        stopWatching()
        // A prompt of the old Activity would never answer. Close it, so the signing call ends.
        keyApi?.cancelPendingSign()
        activity = null
    }

    // The system callbacks belong to an Activity, and events go to a Dart listener, so they are
    // registered only while both exist. Called whenever one of the two appears.
    private fun startWatching() {
        val activity = activity ?: return
        if (eventSink == null) return
        if (screenCaptureCallback != null || screenRecordingCallback != null) return
        // Older versions have no such API: the stream stays silent.
        if (sdkInt >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            watchScreenCapture(activity)
        }
        if (sdkInt >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            watchScreenRecording(activity)
        }
    }

    // Called whenever one of the two disappears.
    private fun stopWatching() {
        val captureCallback = screenCaptureCallback
        val recordingCallback = screenRecordingCallback
        // Cleared in every case: a callback left in a field would make the next startWatching
        // think it is still registered, and the events would silently stop.
        screenCaptureCallback = null
        screenRecordingCallback = null
        // Without an Activity there is nothing left to unregister from.
        val activity = activity ?: return
        captureCallback?.let { unwatchScreenCapture(activity, it) }
        recordingCallback?.let { unwatchScreenRecording(activity, it) }
    }

    // The executor is the main one: the callbacks then run on the main thread, which is the
    // only thread an EventSink may be used from.
    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun watchScreenCapture(activity: Activity) {
        val callback = Activity.ScreenCaptureCallback { send("screenshotTaken") }
        screenCaptureCallback = callback
        activity.registerScreenCaptureCallback(activity.mainExecutor, callback)
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun unwatchScreenCapture(activity: Activity, callback: Activity.ScreenCaptureCallback) {
        activity.unregisterScreenCaptureCallback(callback)
    }

    @RequiresApi(Build.VERSION_CODES.VANILLA_ICE_CREAM)
    private fun watchScreenRecording(activity: Activity) {
        val callback = Consumer<Int> { state -> sendRecordingState(state) }
        screenRecordingCallback = callback
        // Registering returns the current state, so a recording that started before Dart
        // subscribed is still reported.
        val initialState = activity.windowManager.addScreenRecordingCallback(
            activity.mainExecutor,
            callback
        )
        if (initialState == WindowManager.SCREEN_RECORDING_STATE_VISIBLE) {
            sendRecordingState(initialState)
        }
    }

    @RequiresApi(Build.VERSION_CODES.VANILLA_ICE_CREAM)
    private fun unwatchScreenRecording(activity: Activity, callback: Consumer<Int>) {
        activity.windowManager.removeScreenRecordingCallback(callback)
    }

    @RequiresApi(Build.VERSION_CODES.VANILLA_ICE_CREAM)
    private fun sendRecordingState(state: Int) {
        send(
            "screenRecordingChanged",
            mapOf("isRecording" to (state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE))
        )
    }

    private fun send(type: String, fields: Map<String, Any> = emptyMap()) {
        eventSink?.success(
            mapOf("type" to type, "timestamp" to System.currentTimeMillis()) + fields
        )
    }
}
