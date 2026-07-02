// This is a basic Flutter widget test for the SplitApp application.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:split_frontend/api_service.dart';
import 'package:split_frontend/main.dart';

void main() {
  testWidgets('SplitApp login screen smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences values so ApiService doesn't throw during loading.
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ApiService(),
        child: const SplitApp(),
      ),
    );

    // Wait for the asynchronous _loadSession to finish and rebuild the tree.
    await tester.pumpAndSettle();

    // Verify that the login screen is displayed.
    expect(find.text('Splitify'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
  });
}
