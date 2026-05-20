import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/testable_editor.dart';

// Baseline / regression-gate measurements for ROADMAP H1.8.
// These tests record the current cost of a single selection mutation in a
// large document, and lock in the *current bug* of PropertyValueNotifier
// notifying even when the new value equals the old one.
//
// After H2.1 lands (selection equality short-circuit), the second test
// must drop from 10 -> 0/1. Update the expectation then to lock in the fix.

void main() {
  group('H1.8 — Selection notification cascade baseline', () {
    Future<TestableEditor> setupEditor(
      WidgetTester tester, {
      required int paragraphCount,
    }) async {
      final editor = tester.editor;
      for (var i = 0; i < paragraphCount; i++) {
        editor.addParagraph(initialText: 'Paragraph $i');
      }
      await editor.startTesting();
      return editor;
    }

    testWidgets(
      'baseline: a unique selection set fires selectionNotifier once '
      '(200 paragraphs)',
      (tester) async {
        final editor = await setupEditor(tester, paragraphCount: 200);
        final editorState = editor.editorState;

        var listenerCallCount = 0;
        void counter() => listenerCallCount++;
        editorState.selectionNotifier.addListener(counter);

        editorState.selection = Selection.single(path: [50], startOffset: 0);
        await tester.pump();

        debugPrint('\n${'=' * 60}');
        debugPrint('BASELINE — unique-selection notify count');
        debugPrint('=' * 60);
        debugPrint('Document: 200 paragraphs');
        debugPrint('Action: set selection ONCE on path [50]');
        debugPrint('selectionNotifier listener calls: $listenerCallCount');
        debugPrint('${'=' * 60}\n');

        expect(
          listenerCallCount,
          1,
          reason: 'A single unique selection set should fire listener once.',
        );

        editorState.selectionNotifier.removeListener(counter);
        await editor.dispose();
      },
    );

    testWidgets(
      'CURRENT BUG: selectionNotifier notifies on every identical set '
      '(regression gate for H2.1)',
      (tester) async {
        final editor = await setupEditor(tester, paragraphCount: 200);
        final editorState = editor.editorState;

        // Establish an initial selection so the first identical set has
        // a non-null prior value to compare against.
        editorState.selection = Selection.single(path: [50], startOffset: 0);
        await tester.pump();

        var listenerCallCount = 0;
        void counter() => listenerCallCount++;
        editorState.selectionNotifier.addListener(counter);

        final identical = Selection.single(path: [50], startOffset: 0);
        for (var i = 0; i < 10; i++) {
          editorState.selection = identical;
        }
        await tester.pump();

        debugPrint('\n${'=' * 60}');
        debugPrint('CURRENT BUG — identical-selection notify count');
        debugPrint('=' * 60);
        debugPrint('Document: 200 paragraphs');
        debugPrint('Action: set IDENTICAL selection 10 times');
        debugPrint('selectionNotifier listener calls: $listenerCallCount');
        debugPrint('Expected today (always-notify): 10');
        debugPrint('Expected after H2.1: 0');
        debugPrint('${'=' * 60}\n');

        // Documents the always-notify behavior. After H2.1 fix, flip this
        // expectation to `equals(0)` (or `lessThan(2)`) to lock the fix in.
        expect(
          listenerCallCount,
          10,
          reason:
              'PropertyValueNotifier currently always notifies, even on '
              'identical values. After H2.1, expect this to drop to 0/1.',
        );

        editorState.selectionNotifier.removeListener(counter);
        await editor.dispose();
      },
    );

    testWidgets(
      'frame settling: pump count to stabilize after a single selection set '
      '(200 paragraphs)',
      (tester) async {
        final editor = await setupEditor(tester, paragraphCount: 200);
        final editorState = editor.editorState;

        editorState.selection = Selection.single(path: [100], startOffset: 0);

        var pumpsToSettle = 0;
        final stopwatch = Stopwatch()..start();
        // Pump until no further frames are scheduled, with a hard cap.
        while (tester.binding.hasScheduledFrame && pumpsToSettle < 50) {
          await tester.pump();
          pumpsToSettle++;
        }
        stopwatch.stop();

        debugPrint('\n${'=' * 60}');
        debugPrint('FRAME SETTLE COST');
        debugPrint('=' * 60);
        debugPrint('Document: 200 paragraphs');
        debugPrint('Action: set selection on path [100] and pump to idle');
        debugPrint('Pumps until idle: $pumpsToSettle');
        debugPrint('Wall time: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('${'=' * 60}\n');

        // Tighten this bound once H2.2 (BlockSelectionArea self-reschedule)
        // fix lands. For now we only assert it doesn't loop forever.
        expect(
          pumpsToSettle,
          lessThan(50),
          reason:
              'Selection set should settle into a steady frame schedule, '
              'not loop indefinitely.',
        );

        await editor.dispose();
      },
    );
  });
}
