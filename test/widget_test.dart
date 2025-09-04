// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sous_chef_app/main.dart';

void main() {
  testWidgets('Sous Chef app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SousChefApp());

    // Wait for the app to load
    await tester.pumpAndSettle();

    // Verify that the app loads with bottom navigation
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    // Tap the Add tab to navigate to add ingredient screen
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Verify we're now on the add ingredient screen
    expect(find.text('Add Ingredient'), findsOneWidget);
  });
}
