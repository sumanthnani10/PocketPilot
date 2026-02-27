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

class PilotAccessibilityService : AccessibilityService() {

    companion object {
        var instance: PilotAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onDestroy() {
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
                val windowManager = getSystemService(WINDOW_SERVICE) as android.view.WindowManager
                val textView = android.widget.TextView(this).apply {
                    text = message
                    setBackgroundColor(android.graphics.Color.parseColor("#CC000000"))
                    setTextColor(android.graphics.Color.WHITE)
                    setPadding(32, 24, 32, 24)
                    textSize = 14f
                    gravity = android.view.Gravity.CENTER
                }

                val params = android.view.WindowManager.LayoutParams(
                    android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                    android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                    android.view.WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    android.graphics.PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL
                    y = 200
                }

                windowManager.addView(textView, params)

                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        windowManager.removeView(textView)
                    } catch (e: Exception) {}
                }, 2500)
            } catch (e: Exception) {
                // Fallback attempt if window overlay fails
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            }
        }
    }
}
