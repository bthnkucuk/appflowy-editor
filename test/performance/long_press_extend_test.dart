import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/editor_robot.dart';
import '../new/infra/testable_editor.dart';

/// Smoke + regression tests for the `EditorRobot` extension
/// (`test/new/infra/editor_robot.dart`) and the mobile cursor-drag
/// gesture path it exercises.
///
/// The mobile gesture path normally only mounts when
/// `PlatformExtension.isDesktopOrWeb == false`, which on the macOS
/// test host means it's gated off. We unblock the gate via
/// `PlatformExtension.debugPlatformOverride` (a test-only static
/// patterned after Flutter's `debugDefaultTargetPlatformOverride`).
void main() {
  group('EditorRobot — synthetic helpers', () {
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
      await tester.pumpAndSettle();

      final offsetAtStart = tester.characterOffset(1, 0);
      final offsetAtEnd = tester.characterOffset(1, 11);

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

  group('EditorRobot — Android long-press gesture', () {
    setUp(() {
      PlatformExtension.debugPlatformOverride = DebugPlatform.android;
    });

    tearDown(() {
      PlatformExtension.debugPlatformOverride = null;
    });

    testWidgets(
      'long-press inside a word expands selection to the word boundary',
      (tester) async {
        // Locks in the H2.3.e behavior: a long-press on a word expands
        // selection to the word boundary (not a collapsed cursor at
        // the press position) and stays expanded. Pre-H2.3.e the
        // AutoScroller could overwrite the expanded selection with a
        // collapsed cursor mid-drag.
        final editor = tester.editor
          ..addParagraphs(
            5,
            initialText: 'The quick brown fox jumps over the lazy dog',
          );
        await editor.startTesting(inMobile: true);
        await tester.pumpAndSettle();

        // Long-press in paragraph 2 at offset 6 — mid-word "quick".
        // Android strategy.onLongPressStart should expand the selection
        // to the word boundary covering "quick" (offsets [4, 9]).
        final gesture = await tester.longPressInParagraph(2, 6);

        try {
          final selection = editor.selection;
          expect(
            selection,
            isNotNull,
            reason:
                'A long-press must produce a non-null selection — this is '
                'the entry point for the cursor-drag-extend gesture.',
          );
          expect(selection!.start.path, equals([2]));
          expect(selection.end.path, equals([2]));

          expect(
            selection.isCollapsed,
            isFalse,
            reason:
                'Long-press should expand to a word — not leave a '
                'collapsed cursor. Pre-H2.3.e this could collapse '
                'mid-drag if the AutoScroller fired its cursor-mode '
                'branch.',
          );
          expect(
            selection.start.offset,
            lessThanOrEqualTo(4),
            reason: 'Selection should cover (or start at) the word "quick".',
          );
          expect(
            selection.end.offset,
            greaterThanOrEqualTo(9),
            reason: 'Selection should cover the end of "quick".',
          );
        } finally {
          await tester.releaseLongPress(gesture);
        }

        await editor.dispose();
      },
    );
  });
}
