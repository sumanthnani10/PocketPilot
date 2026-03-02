import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpilot/accessibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('pocketpilot/accessibility');

  setUp(() {
    // Mock the platform channel to return distinct values for our tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isServiceEnabled':
          return true;
        case 'getUITree':
          return '{"nodes": [{"id": "test_node", "text": "Click Me"}]}';
        case 'performAction':
          return true;
        case 'performGlobalAction':
          return true;
        case 'tapOnCoordinate':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AccessibilityService Tests', () {
    test('isServiceEnabled returns true based on platform mock', () async {
      final result = await AccessibilityService.isServiceEnabled();
      expect(result, isTrue);
    });

    test('getUITree returns correctly parsed JSON map', () async {
      final result = await AccessibilityService.getUITree();
      expect(result, isNotNull);
      expect(result!['nodes'], isA<List>());
      expect(result['nodes'][0]['text'], equals('Click Me'));
    });

    test('performAction triggers platform action and returns true', () async {
      final result = await AccessibilityService.performAction('node1', 'click');
      expect(result, isTrue);
    });

    test('performGlobalAction returns true', () async {
      final result = await AccessibilityService.performGlobalAction('home');
      expect(result, isTrue);
    });

    test('tapOnCoordinate triggers successfully', () async {
      final result = await AccessibilityService.tapOnCoordinate(100.5, 200.5);
      expect(result, isTrue);
    });
  });
}
