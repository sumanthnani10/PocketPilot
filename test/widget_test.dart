import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketpilot/main.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: '''GEMINI_API_KEY=''');
    // Mock SharedPreferences for the initial load
    SharedPreferences.setMockInitialValues({});

    // Mock the MethodChannel so the UI doesn't crash when checking accessibility status
    const MethodChannel channel = MethodChannel('pocketpilot/accessibility');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return true; // Simulate that any channel call (like showToast or isServiceEnabled) succeeds
    });
  });

  group('MainScreen Widget Tests', () {
    testWidgets('PocketPilot app renders essential UI elements', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const PocketPilotApp());
      await tester.pump(); // Cannot use pumpAndSettle due to infinite pulse animation
      await tester.pump(const Duration(milliseconds: 50)); 

      // Verify the application title is present
      expect(find.text('PocketPilot'), findsOneWidget);

      // Verify the status banner shows active status due to our mock
      expect(find.text('Service is Active & Ready'), findsOneWidget);

      // Verify task input card is rendered
      expect(find.text('Task Prompt'), findsOneWidget);
      expect(find.byType(ShadInput), findsOneWidget);

      // Verify the start button exists
      expect(find.text('Initialize Run'), findsOneWidget);
      
      // Verify logs section exists
      expect(find.text('Execution Telemetry'), findsOneWidget);
      expect(find.text('Awaiting instructions...'), findsOneWidget);
    });

    testWidgets('Tapping Initialize without task shows error log', (WidgetTester tester) async {
      await tester.pumpWidget(const PocketPilotApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap the run button
      await tester.tap(find.text('Initialize Run'));
      await tester.pump(); // Advance a frame to register tap
      await tester.pump(const Duration(milliseconds: 100)); // Advance to allow setState and log render

      // Because we didn't enter an API Key, it should log a toast/telemetry.
      // E.g., "Please enter a Gemini API Key."
      expect(find.textContaining('Please enter a Gemini API Key.'), findsWidgets);
    });
  });
}
