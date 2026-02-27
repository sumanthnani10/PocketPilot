package com.sumanth.pocketpilot

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.content.ComponentName
import android.text.TextUtils

class MainActivity : FlutterActivity() {
    private val CHANNEL = "pocketpilot/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isServiceEnabled" -> {
                    val expectedComponentName = ComponentName(this, PilotAccessibilityService::class.java)
                    val enabledServicesSetting = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
                    val colonSplitter = TextUtils.SimpleStringSplitter(':')
                    colonSplitter.setString(enabledServicesSetting)
                    var isEnabled = false
                    while (colonSplitter.hasNext()) {
                        val componentNameString = colonSplitter.next()
                        val enabledService = ComponentName.unflattenFromString(componentNameString)
                        if (enabledService != null && enabledService == expectedComponentName) {
                            isEnabled = true
                            break
                        }
                    }
                    if (isEnabled && PilotAccessibilityService.instance == null) {
                        result.success(false)
                    } else {
                        result.success(PilotAccessibilityService.instance != null)
                    }
                }
                "openSettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "getUITree" -> {
                    val service = PilotAccessibilityService.instance
                    if (service != null) {
                        val tree = service.getSimplifiedTree()
                        if (tree != null) {
                            result.success(tree)
                        } else {
                            result.error("UNAVAILABLE", "UI Tree not available.", null)
                        }
                    } else {
                        result.error("UNAVAILABLE", "Accessibility Service not running.", null)
                    }
                }
                "performAction" -> {
                    val service = PilotAccessibilityService.instance
                    if (service != null) {
                        val path = call.argument<String>("path")
                        val action = call.argument<String>("action")
                        val arg = call.argument<String>("arg")
                        if (path != null && action != null) {
                            val success = service.performNodeAction(path, action, arg)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARG", "Path and action are required.", null)
                        }
                    } else {
                        result.error("UNAVAILABLE", "Accessibility Service not running.", null)
                    }
                }
                "performGlobalAction" -> {
                    val service = PilotAccessibilityService.instance
                    if (service != null) {
                        val action = call.argument<String>("action")
                        if (action != null) {
                            val success = service.performGlobalActionByName(action)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARG", "Action is required.", null)
                        }
                    } else {
                        result.error("UNAVAILABLE", "Accessibility Service not running.", null)
                    }
                }
                "tapOnCoordinate" -> {
                    val service = PilotAccessibilityService.instance
                    if (service != null) {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x != null && y != null) {
                            val success = service.tapOnCoordinate(x, y)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARG", "x and y coordinates are required.", null)
                        }
                    } else {
                        result.error("UNAVAILABLE", "Accessibility Service not running.", null)
                    }
                }
                "showToast" -> {
                    val message = call.argument<String>("message")
                    val service = PilotAccessibilityService.instance
                    if (message != null) {
                        if (service != null) {
                            service.showSystemToast(message)
                        } else {
                            android.widget.Toast.makeText(this@MainActivity, message, android.widget.Toast.LENGTH_SHORT).show()
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Message is required.", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
