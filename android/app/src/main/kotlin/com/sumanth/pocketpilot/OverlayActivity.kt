package com.sumanth.pocketpilot

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import android.content.Intent

import android.os.Bundle

class OverlayActivity : FlutterActivity() {
    private val CHANNEL = "pocketpilot/accessibility"
    private var methodChannel: MethodChannel? = null
    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.transparent
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    override fun finish() {
        super.finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    override fun getDartEntrypointFunctionName(): String {
        return "overlayMain"
    }

    override fun getInitialRoute(): String {
        val imagePath = intent.getStringExtra("imagePath") ?: ""
        return "/overlay?imagePath=$imagePath"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            val service = PilotAccessibilityService.instance
            when (call.method) {
                "moveTaskToBack" -> {
                    val moved = moveTaskToBack(true)
                    result.success(moved)
                }
                "performGlobalAction" -> {
                    if (service != null && call.argument<String>("action") != null) {
                        result.success(service.performGlobalActionByName(call.argument<String>("action")!!))
                    } else {
                        result.success(false)
                    }
                }
                "performAction" -> {
                    if (service != null) {
                        val path = call.argument<String>("path") ?: ""
                        val action = call.argument<String>("action") ?: ""
                        val arg = call.argument<String>("arg")
                        result.success(service.performNodeAction(path, action, arg))
                    } else {
                        result.success(false)
                    }
                }
                "getUITree" -> {
                    if (service != null) {
                        result.success(service.getSimplifiedTree())
                    } else {
                        result.error("UNAVAILABLE", "No UI Tree", null)
                    }
                }
                "tapOnCoordinate" -> {
                    if (service != null) {
                        val x = call.argument<Double>("x")?.toFloat() ?: 0f
                        val y = call.argument<Double>("y")?.toFloat() ?: 0f
                        result.success(service.tapOnCoordinate(x, y))
                    } else {
                        result.success(false)
                    }
                }
                "showToast" -> {
                    val msg = call.argument<String>("message") ?: ""
                    service?.showSystemToast(msg)
                    result.success(true)
                }
                "isServiceEnabled" -> {
                    result.success(service != null)
                }
                "startTaskLoop" -> {
                    val task = call.argument<String>("task")
                    if (task != null) {
                        val broadcast = Intent("com.sumanth.pocketpilot.START_TASK")
                        broadcast.putExtra("task", task)
                        sendBroadcast(broadcast)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Task text required", null)
                    }
                }
                "getInitialImagePath" -> {
                    val imagePath = intent.getStringExtra("imagePath") ?: ""
                    result.success(imagePath)
                }
                // When Assistive Touch task is completed, we can close the overlay
                "closeOverlay" -> {
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.getStringExtra("action")
        if (action == "assistive_touch_clicked") {
            val imagePath = intent.getStringExtra("imagePath")
            if (imagePath != null) {
                methodChannel?.invokeMethod("onAssistiveTouch", mapOf("imagePath" to imagePath))
            }
        }
    }
}
