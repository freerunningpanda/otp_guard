package com.freerunningpanda.device_security

import android.app.Activity
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** DeviceSecurityPlugin */
class DeviceSecurityPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    // Carries method calls from Dart. Created in onAttachedToEngine and kept here so the
    // handler can be removed in onDetachedFromEngine.
    private lateinit var channel: MethodChannel

    // The Activity whose window gets FLAG_SECURE. Null whenever no Activity is attached,
    // so that a closed Activity is never kept alive by this reference.
    private var activity: Activity? = null

    // The state Dart last set successfully. FLAG_SECURE lives on the window of one Activity,
    // so it is re-applied from this field whenever a new Activity is attached.
    private var protectionEnabled = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.freerunningpanda.device_security/methods"
        )
        channel.setMethodCallHandler(this)
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
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun attachActivity(newActivity: Activity) {
        activity = newActivity
        // A new Activity has a new window without the flag. Only add it here: clearing could
        // remove a FLAG_SECURE that the host app set on its own.
        if (protectionEnabled) {
            newActivity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
