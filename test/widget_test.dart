import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eventhub/models/event.dart';
import 'package:eventhub/screens/home_screen.dart';

void main() {
  testWidgets('Shows a message when no events are available', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          favoritesUserId: 'test-user',
          loadEvents: () async => <Event>[],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('EventHub'), findsOneWidget);
    expect(
      find.text('No upcoming events have been published yet.'),
      findsOneWidget,
    );
  });
}