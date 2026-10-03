// Basic smoke test for the MCQ app. This test is intentionally lightweight;
// the app requires backend connectivity so it only verifies the app boots
// into the splash screen without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcq/app.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    // main() runs the app inside a ProviderScope, so mirror that here or
    // every riverpod lookup inside the widget tree throws "No ProviderScope".
    await tester.pumpWidget(
      const ProviderScope(child: McqApp()),
    );
    expect(find.byType(McqApp), findsOneWidget);
  });
}