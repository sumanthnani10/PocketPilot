import 'package:flutter/services.dart';

class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('pocketpilot/accessibility');

  static Function(String)? onStartTask;

  static void initialize(Function(String) onAssistiveTouchClicked) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAssistiveTouch') {
        final String? imagePath = call.arguments['imagePath'];
        if (imagePath != null) {
          onAssistiveTouchClicked(imagePath);
        }
      } else if (call.method == 'startTaskFromOverlay') {
        final task = call.arguments['task'] as String?;
        if (task != null && onStartTask != null) {
          onStartTask!(task);
        }
      }
    });
  }

  static Future<bool> isServiceEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isServiceEnabled');
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } on PlatformException catch (e) {
      print("Failed to open settings: '${e.message}'.");
    }
  }

  static Future<Map<dynamic, dynamic>?> getUITree() async {
    try {
      final Map<dynamic, dynamic>? tree = await _channel.invokeMethod('getUITree');
      return tree;
    } on PlatformException catch (e) {
      print("Failed to get UI tree: '${e.message}'.");
      return null;
    }
  }

  static Future<bool> performAction(String path, String action, {String? arg}) async {
    try {
      final bool result = await _channel.invokeMethod('performAction', {
        'path': path,
        'action': action,
        'arg': arg,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to perform action: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> moveTaskToBack() async {
    try {
      final bool result = await _channel.invokeMethod('moveTaskToBack');
      return result;
    } on PlatformException catch (e) {
      print("Failed to move task to back: '${e.message}'.");
      return false;
    }
  }

  static Future<void> closeOverlay() async {
    try {
      await _channel.invokeMethod('closeOverlay');
    } on PlatformException catch (e) {
      print("Failed to close overlay: '${e.message}'.");
    }
  }

  static Future<void> startTaskLoop(String task) async {
    try {
      await _channel.invokeMethod('startTaskLoop', {'task': task});
    } on PlatformException catch (e) {
      print("Failed to forward task loop overlay map hook: '${e.message}'.");
    }
  }

  static Future<bool> performGlobalAction(String action) async {
    try {
      final bool result = await _channel.invokeMethod('performGlobalAction', {
        'action': action,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to perform global action: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> tapOnCoordinate(double x, double y) async {
    try {
      final bool result = await _channel.invokeMethod('tapOnCoordinate', {
        'x': x,
        'y': y,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to tap coordinate: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> showGlobalToast(String message) async {
    try {
      final bool result = await _channel.invokeMethod('showToast', {
        'message': message,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to show toast: '${e.message}'.");
      return false;
    }
  }
}
