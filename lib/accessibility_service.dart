import 'package:flutter/services.dart';

class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('pocketpilot/accessibility');

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
}
