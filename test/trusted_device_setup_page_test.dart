import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintapp/pages/trusted_device_setup_page.dart';

void main() {
  testWidgets('PIN setup rejects mismatched confirmation before registration', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TrustedDeviceSetupPage()));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), '654321');
    await tester.tap(find.text('Set up trusted device'));
    await tester.pump();

    expect(find.text('PINs do not match.'), findsOneWidget);
  });

  testWidgets('PIN setup rejects non-six-digit PIN', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrustedDeviceSetupPage()));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '12345');
    await tester.enterText(fields.at(1), '12345');
    await tester.tap(find.text('Set up trusted device'));
    await tester.pump();

    expect(find.text('Enter a 6-digit PIN.'), findsOneWidget);
  });
}
