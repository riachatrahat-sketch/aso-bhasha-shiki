import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/core/widgets/progress_ring.dart';
import 'package:lingobridge_ai/features/setup/setup_required_app.dart';

/// Smoke tests that need no Firebase. The full app needs a configured
/// Firebase project, so it is not pumped here.
void main() {
  testWidgets('setup screen explains how to configure Firebase', (tester) async {
    await tester.pumpWidget(const SetupRequiredApp(error: 'not configured'));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Firebase'), findsWidgets);
  });

  testWidgets('progress ring builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ProgressRing(value: 0.5, size: 60, child: Text("50%")))),
      ),
    );
    expect(find.byType(ProgressRing), findsOneWidget);
  });
}
