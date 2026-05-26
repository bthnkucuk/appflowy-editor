import 'package:flutter_test/flutter_test.dart';

import '../new/infra/editor_robot.dart';
import '../new/infra/testable_editor.dart';

/// Smoke-test for the `EditorRobot` extension
/// (`test/new/infra/editor_robot.dart`) — a super_editor-style high-
/// level test API. Verifies the basic helper round-trip:
/// place caret, read it back, character offset translation.
///
/// The mobile-gesture-based helpers (`longPressInParagraph`,
/// `releaseLongPress`) are not exercised here — they need
/// `debugDefaultTargetPlatformOverride = TargetPlatform.android` to
/// route through `MobileSelectionService` instead of the desktop
/// service the test host falls back to. That gating will land with
/// the first gesture-driven scenario test that needs it.
void main() {
  group('EditorRobot smoke tests', () {
    testWidgets('placeCaretInParagraph writes a collapsed selection', (
      tester,
    ) async {
      final editor = tester.editor
        ..addParagraphs(
          5,
          initialText: 'The quick brown fox jumps over the lazy dog',
        );
      await editor.startTesting();

      await tester.placeCaretInParagraph(2, 6);

      final selection = editor.selection;
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, isTrue);
      expect(selection.start.path, equals([2]));
      expect(selection.start.offset, equals(6));

      await editor.dispose();
    });

    testWidgets('characterOffset returns a sensible global Offset', (
      tester,
    ) async {
      final editor = tester.editor
        ..addParagraphs(3, initialText: 'Hello world');
      await editor.startTesting();

      // Force a layout pass so cursor rect resolution doesn't return
      // null in debug mode.
      await tester.pumpAndSettle();

      final offsetAtStart = tester.characterOffset(1, 0);
      final offsetAtEnd = tester.characterOffset(1, 11);

      // Sanity: the same-line characters lie on the same horizontal
      // band, and the "end" position is to the right of "start".
      expect(offsetAtEnd.dx, greaterThan(offsetAtStart.dx));
      expect(
        (offsetAtEnd.dy - offsetAtStart.dy).abs(),
        lessThan(5),
        reason: 'Offsets within one line should share roughly the same '
            'vertical position.',
      );

      await editor.dispose();
    });
  });
}
