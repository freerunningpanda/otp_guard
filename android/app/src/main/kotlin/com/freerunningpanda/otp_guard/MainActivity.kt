package com.freerunningpanda.otp_guard

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt of device_security needs a
// FragmentActivity.
class MainActivity : FlutterFragmentActivity()
