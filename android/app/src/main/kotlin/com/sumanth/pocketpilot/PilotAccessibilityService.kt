package com.sumanth.pocketpilot

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import android.view.WindowManager
import android.widget.ImageView
import android.widget.FrameLayout
import android.graphics.drawable.GradientDrawable
import android.graphics.Color
import android.content.res.ColorStateList
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.MotionEvent
import android.view.KeyEvent
import android.content.Intent
import android.graphics.Bitmap
import java.io.File
import java.io.FileOutputStream

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.MethodChannel
import io.flutter.FlutterInjector

class PilotAccessibilityService : AccessibilityService() {

    companion object {
        var instance: PilotAccessibilityService? = null
    }

    private var windowManager: WindowManager? = null
    private var floatingView: FrameLayout? = null
    
    private var flutterEngine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var chatOverlayView: FrameLayout? = null
    private var methodChannel: MethodChannel? = null
    private var currentImagePath: String = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        setupAssistiveTouch()
        setupFlutterEngine()
    }

    private fun setupFlutterEngine() {
        if (flutterEngine != null) return
        try {
            flutterEngine = FlutterEngine(this.applicationContext)
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "overlayMain"
                )
            )
            flutterEngine?.lifecycleChannel?.appIsResumed()
            
            methodChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "pocketpilot/accessibility")
            setupMethodChannel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setupMethodChannel() {
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> result.success(true) // No task to move, we're an overlay
                "performGlobalAction" -> {
                    val actionName = call.argument<String>("action")
                    if (actionName != null) {
                        result.success(performGlobalActionByName(actionName))
                    } else {
                        result.success(false)
                    }
                }
                "performAction" -> {
                    val path = call.argument<String>("path") ?: ""
                    val action = call.argument<String>("action") ?: ""
                    val arg = call.argument<String>("arg")
                    result.success(performNodeAction(path, action, arg))
                }
                "getUITree" -> {
                    val tree = getSimplifiedTree()
                    if (tree != null) {
                        result.success(tree)
                    } else {
                        result.error("UNAVAILABLE", "No UI Tree", null)
                    }
                }
                "tapOnCoordinate" -> {
                    val x = call.argument<Double>("x")?.toFloat() ?: 0f
                    val y = call.argument<Double>("y")?.toFloat() ?: 0f
                    result.success(tapOnCoordinate(x, y))
                }
                "showToast" -> {
                    val msg = call.argument<String>("message") ?: ""
                    showSystemToast(msg)
                    result.success(true)
                }
                "isServiceEnabled" -> result.success(true)
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
                    result.success(currentImagePath)
                }
                "closeOverlay" -> {
                    Handler(Looper.getMainLooper()).post {
                        hideChatOverlay()
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupAssistiveTouch() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            floatingView = FrameLayout(this)
            
            val fab = ImageView(this)
            fab.setImageResource(android.R.drawable.ic_menu_help)
            
            val shape = GradientDrawable()
            shape.shape = GradientDrawable.OVAL
            shape.setColor(Color.parseColor("#448AFF"))
            fab.background = shape
            fab.imageTintList = ColorStateList.valueOf(Color.WHITE)
            
            val layoutParams = FrameLayout.LayoutParams(150, 150)
            fab.layoutParams = layoutParams
            fab.setPadding(30, 30, 30, 30)

            floatingView!!.addView(fab)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.CENTER_VERTICAL or Gravity.END
            params.x = 20
            params.y = 0

            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f
            var isMoving = false

            fab.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isMoving = false
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (initialTouchX - event.rawX).toInt() 
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                            isMoving = true
                        }
                        params.x = initialX + dx
                        params.y = initialY + dy
                        try {
                            windowManager?.updateViewLayout(floatingView, params)
                        } catch (e: Exception) {}
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!isMoving) {
                            onAssistiveTouchClicked()
                        }
                        true
                    }
                    else -> false
                }
            }

            try {
                windowManager?.addView(floatingView, params)
            } catch (e: Exception) {}
        }
    }

    private fun onAssistiveTouchClicked() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            val wasOpen = chatOverlayView != null
            if (wasOpen) {
                hideChatOverlay()
            }
            
            Handler(Looper.getMainLooper()).postDelayed({
                val executor = mainExecutor
                takeScreenshot(android.view.Display.DEFAULT_DISPLAY, executor, object : TakeScreenshotCallback {
                    override fun onSuccess(screenshotResult: AccessibilityService.ScreenshotResult) {
                        val hardwareBuffer = screenshotResult.hardwareBuffer
                        val bitmap = Bitmap.wrapHardwareBuffer(hardwareBuffer, screenshotResult.colorSpace)
                        if (bitmap != null) {
                            saveScreenshotAndShowOverlay(bitmap)
                        }
                        screenshotResult.hardwareBuffer.close()
                    }

                    override fun onFailure(errorCode: Int) {
                        showSystemToast("Screenshot failed: \$errorCode")
                        if (wasOpen) {
                            showChatOverlay()
                        }
                    }
                })
            }, 150)
        }
    }

    private fun saveScreenshotAndShowOverlay(bitmap: Bitmap) {
        try {
            val timestamp = System.currentTimeMillis()
            val file = File(cacheDir, "assistive_screenshot_\$timestamp.png")
            val out = FileOutputStream(file)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.flush()
            out.close()

            currentImagePath = file.absolutePath
            showChatOverlay()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun showChatOverlay() {
        Handler(Looper.getMainLooper()).post {
            if (chatOverlayView != null) {
                hideChatOverlay()
            }
            
            if (flutterEngine == null) {
                setupFlutterEngine()
            }

            // Notify flutter of the new image path
            methodChannel?.invokeMethod("onAssistiveTouch", mapOf("imagePath" to currentImagePath))

            chatOverlayView = object : FrameLayout(this) {
                override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
                    if (ev.action == MotionEvent.ACTION_OUTSIDE) {
                        hideChatOverlay()
                        return true
                    }
                    return super.dispatchTouchEvent(ev)
                }
                override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                    if (event.keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                        hideChatOverlay()
                        return true
                    }
                    return super.dispatchKeyEvent(event)
                }
            }

            flutterView = FlutterView(this)
            flutterView?.attachToFlutterEngine(flutterEngine!!)
            
            chatOverlayView?.addView(flutterView)

            val dm = resources.displayMetrics
            val w = dm.widthPixels - (16 * dm.density).toInt() // small margin
            val h = (dm.heightPixels * 0.55).toInt()
            
            val params = WindowManager.LayoutParams(
                w,
                h,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or 
                WindowManager.LayoutParams.FLAG_DIM_BEHIND,
                PixelFormat.TRANSLUCENT
            )
            params.dimAmount = 0.4f
            params.gravity = Gravity.CENTER

            try {
                windowManager?.addView(chatOverlayView, params)
                // Force flutter to paint/resume
                flutterEngine?.lifecycleChannel?.appIsResumed()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun hideChatOverlay() {
        if (chatOverlayView != null) {
            try {
                flutterView?.detachFromFlutterEngine()
                windowManager?.removeView(chatOverlayView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            chatOverlayView = null
            flutterView = null
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onDestroy() {
        if (floatingView != null) {
            try {
                windowManager?.removeView(floatingView)
            } catch (e: Exception) {}
            floatingView = null
        }
        hideChatOverlay()
        flutterEngine?.destroy()
        flutterEngine = null
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }

    fun getSimplifiedTree(): Map<String, Any>? {
        val root = rootInActiveWindow ?: return null
        val tree = parseNode(root, "0")
        root.recycle()
        return tree
    }

    fun getActivePackage(): String {
        return rootInActiveWindow?.packageName?.toString() ?: ""
    }

    fun performGlobalActionByName(actionName: String): Boolean {
        return when (actionName) {
            "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
            "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
            "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
            else -> false
        }
    }

    private fun parseNode(node: AccessibilityNodeInfo, path: String): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        map["id"] = path
        map["className"] = node.className?.toString() ?: ""
        map["text"] = node.text?.toString() ?: ""
        map["contentDescription"] = node.contentDescription?.toString() ?: ""
        map["isClickable"] = node.isClickable
        map["isScrollable"] = node.isScrollable
        map["isEditable"] = node.isEditable
        
        val rect = Rect()
        node.getBoundsInScreen(rect)
        map["bounds"] = listOf(rect.left, rect.top, rect.right, rect.bottom)
        
        val children = mutableListOf<Map<String, Any>>()
        var validChildIndex = 0
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                if (child.isVisibleToUser) {
                    val childPath = "$path.$validChildIndex"
                    children.add(parseNode(child, childPath))
                    validChildIndex++
                }
                child.recycle()
            }
        }
        map["children"] = children
        return map
    }

    private fun findNodeByPath(current: AccessibilityNodeInfo, currentPath: String, targetPath: String): AccessibilityNodeInfo? {
        if (currentPath == targetPath) {
            return AccessibilityNodeInfo.obtain(current)
        }
        if (!targetPath.startsWith("$currentPath.")) {
            return null
        }
        
        var validChildIndex = 0
        for (i in 0 until current.childCount) {
            val child = current.getChild(i)
            if (child != null) {
                if (child.isVisibleToUser) {
                    val childPath = "$currentPath.$validChildIndex"
                    val found = findNodeByPath(child, childPath, targetPath)
                    if (found != null) {
                        child.recycle()
                        return found
                    }
                    validChildIndex++
                }
                child.recycle()
            }
        }
        return null
    }

    fun performNodeAction(path: String, actionType: String, arg: String?): Boolean {
        val root = rootInActiveWindow ?: return false
        val node = findNodeByPath(root, "0", path)
        if (node == null) {
            root.recycle()
            return false
        }
        
        var success = false
        when (actionType) {
            "click" -> {
                success = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (!success) {
                    val p = node.parent
                    if (p != null && p.isClickable) {
                        success = p.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    }
                    p?.recycle()
                }
            }
            "scroll_forward" -> {
                success = node.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
            }
            "scroll_backward" -> {
                success = node.performAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)
            }
            "set_text" -> {
                val bundle = Bundle()
                bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, arg ?: "")
                success = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
            }
        }
        
        node.recycle()
        root.recycle()
        return success
    }

    fun tapOnCoordinate(x: Float, y: Float): Boolean {
        val path = Path()
        path.moveTo(x, y)
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    fun showSystemToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            try {
                val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
                val textView = android.widget.TextView(this).apply {
                    text = message
                    setBackgroundColor(Color.parseColor("#CC000000"))
                    setTextColor(Color.WHITE)
                    setPadding(32, 24, 32, 24)
                    textSize = 14f
                    gravity = Gravity.CENTER
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                    y = 200
                }

                windowManager.addView(textView, params)

                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        windowManager.removeView(textView)
                    } catch (e: Exception) {}
                }, 2500)
            } catch (e: Exception) {
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            }
        }
    }
}
