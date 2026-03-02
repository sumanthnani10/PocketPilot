import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpilot/main.dart';

void main() {
  testWidgets('PocketPilot UI test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PocketPilotApp());

    // Verify that the title exists.
    expect(find.text('PocketPilot'), findsOneWidget);
  });
}
