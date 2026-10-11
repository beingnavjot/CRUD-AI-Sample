import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crud_ai_sample/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app with Firebase disabled for testing to avoid initialization errors
    await tester.pumpWidget(const MyApp(isFirebaseInitialized: false));

    // Verify that the error screen is shown (since we passed false)
    expect(find.text('Firebase Initialization Failed'), findsOneWidget);
  });
}
