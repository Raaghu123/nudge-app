import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/ui/screens/nl_capture_screen.dart';
import 'package:nudge/ui/screens/nl_confirm_screen.dart';

/// Capture → confirm flow: parse on Preview and prefill the confirm rows.
void main() {
  Future<void> pumpCapture(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NlCaptureScreen()),
    );
  }

  group('NlCaptureScreen → NlConfirmScreen', () {
    testWidgets('thyroid every morning prefills the confirm rows',
        (WidgetTester tester) async {
      await pumpCapture(tester);

      await tester.enterText(
        find.byKey(const Key('nl_input')),
        'remind me to take my thyroid pill every morning',
      );
      await tester.tap(find.byKey(const Key('nl_preview')));
      await tester.pumpAndSettle();

      // Navigated to the confirm screen.
      expect(find.byType(NlConfirmScreen), findsOneWidget);

      final titleField =
          tester.widget<TextField>(find.byKey(const Key('nl_title')));
      expect(titleField.controller?.text ?? '', contains('thyroid'));

      final categoryField = tester.widget<DropdownButton<Category>>(
        find.descendant(
          of: find.byKey(const Key('nl_category')),
          matching: find.byType(DropdownButton<Category>),
        ),
      );
      expect(categoryField.value, equals(Category.medication));

      final whenLabel = tester.widget<Text>(find.byKey(const Key('nl_when')));
      expect(whenLabel.data ?? '', contains('Every day'));
    });

    testWidgets('short input does nothing', (WidgetTester tester) async {
      await pumpCapture(tester);

      await tester.enterText(find.byKey(const Key('nl_input')), 'ab');
      await tester.tap(find.byKey(const Key('nl_preview')));
      await tester.pumpAndSettle();

      expect(find.byType(NlConfirmScreen), findsNothing);
      expect(find.byType(NlCaptureScreen), findsOneWidget);
    });

    testWidgets('sequential range shows Steps row and windowed When',
        (WidgetTester tester) async {
      await pumpCapture(tester);

      await tester.enterText(
        find.byKey(const Key('nl_input')),
        'study topics 1-4 from 6pm to 10pm one by one',
      );
      await tester.tap(find.byKey(const Key('nl_preview')));
      await tester.pumpAndSettle();

      expect(find.byType(NlConfirmScreen), findsOneWidget);

      final steps = tester.widget<Text>(find.byKey(const Key('nl_steps')));
      final lines = (steps.data ?? '').split('\n');
      expect(lines, hasLength(4));
      expect(lines.first, contains('1.'));
      expect(lines.last, contains('4.'));

      final whenLabel = tester.widget<Text>(find.byKey(const Key('nl_when')));
      expect(whenLabel.data ?? '',
          contains('Every day from 6:00 PM to 10:00 PM'));
    });
  });
}
