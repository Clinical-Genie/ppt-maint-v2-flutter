import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintapp/main.dart';

void main() {
  testWidgets('tap outside a text field removes keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardDismissRegion(
          child: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                Expanded(
                  child: GestureDetector(
                    key: const Key('outside-area'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('outside-area')));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('tapping another text field transfers focus normally', (
    tester,
  ) async {
    final firstFocusNode = FocusNode();
    final secondFocusNode = FocusNode();
    addTearDown(firstFocusNode.dispose);
    addTearDown(secondFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardDismissRegion(
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('first-field'),
                  focusNode: firstFocusNode,
                ),
                TextField(
                  key: const Key('second-field'),
                  focusNode: secondFocusNode,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('first-field')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('second-field')));
    await tester.pump();

    expect(firstFocusNode.hasFocus, isFalse);
    expect(secondFocusNode.hasFocus, isTrue);
  });
}
