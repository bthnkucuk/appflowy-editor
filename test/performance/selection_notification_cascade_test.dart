import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/base_component/selection/block_highlight_area.dart';
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

    testWidgets('baseline: a unique selection set fires selectionNotifier once '
        '(200 paragraphs)', (tester) async {
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
    });

    testWidgets('H2.1: identical selection sets short-circuit '
        '(no notify cascade across N blocks)', (tester) async {
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
      debugPrint('H2.1 LOCK — identical-selection notify count');
      debugPrint('=' * 60);
      debugPrint('Document: 200 paragraphs');
      debugPrint('Action: set IDENTICAL selection 10 times');
      debugPrint('selectionNotifier listener calls: $listenerCallCount');
      debugPrint('Expected after H2.1: 0');
      debugPrint('${'=' * 60}\n');

      // Locks in the H2.1 fix: EditorState.selection setter short-circuits
      // when the new value equals the current one, preventing the
      // PropertyValueNotifier always-notify cascade.
      expect(
        listenerCallCount,
        0,
        reason:
            'After H2.1, identical selection assignments must not '
            'trigger selectionNotifier listeners.',
      );

      editorState.selectionNotifier.removeListener(counter);
      await editor.dispose();
    });

    testWidgets(
      'H2.3 baseline: per-block builder fan-out on a single selection set '
      '(200 paragraphs)',
      (tester) async {
        // Counts BlockSelectionArea + BlockHighlightArea
        // ValueListenableBuilder invocations triggered by a single
        // selection assignment on a 200-block document. Establishes the
        // pre-H2.3.a baseline so the derived-listenable refactor can
        // prove its impact (~3N → ~9 expected).
        final editor = await setupEditor(tester, paragraphCount: 200);
        final editorState = editor.editorState;

        // Set + settle an initial selection so warm-up builds don't
        // pollute the measurement.
        editorState.selection = Selection.single(path: [0], startOffset: 0);
        await tester.pump();
        BlockSelectionArea.debugBuilderCallCount = 0;
        BlockHighlightArea.debugBuilderCallCount = 0;

        editorState.selection = Selection.single(path: [50], startOffset: 0);
        await tester.pump();

        final selBuilds = BlockSelectionArea.debugBuilderCallCount;
        final highlightBuilds = BlockHighlightArea.debugBuilderCallCount;

        debugPrint('\n${'=' * 60}');
        debugPrint('H2.3 BASELINE — per-block builder fan-out');
        debugPrint('=' * 60);
        debugPrint('Document: 200 paragraphs');
        debugPrint('Action: set selection ONCE on path [50]');
        debugPrint('BlockSelectionArea builder calls:  $selBuilds');
        debugPrint('BlockHighlightArea builder calls:  $highlightBuilds');
        debugPrint('Total leaf builds: ${selBuilds + highlightBuilds}');
        debugPrint('Expected pre-H2.3.a: ~3N + N = ~800 on 200 blocks');
        debugPrint('Expected post-H2.3.a: ~9 (only blocks at old + new '
            'selection paths transition)');
        debugPrint('${'=' * 60}\n');

        // No assertion yet — this is a diagnostic baseline. Once H2.3.a
        // lands, replace with:
        //   expect(selBuilds + highlightBuilds, lessThanOrEqualTo(20));
        // to lock in the fix as a regression gate.
        expect(
          selBuilds + highlightBuilds,
          greaterThan(0),
          reason: 'Sanity: at least one area must have rebuilt.',
        );

        await editor.dispose();
      },
    );

    testWidgets(
      'H2.8.e baseline: BSA/BHA initState postFrame schedule count on mount '
      '(200 paragraphs, no selection)',
      (tester) async {
        // Hypothesis: BSA + BHA `initState` always schedules a
        // post-frame `_updateSelectionIfNeeded` call, even when this
        // block's path is nowhere near the current selection. For the
        // ~25 paragraphs in the test viewport that's 25 × (3 BSA + 1
        // BHA) = ~100 closure schedules + postFrame fires every time
        // the editor mounts a batch of new blocks (auto-scroll).
        //
        // After H2.8.e the schedule is gated on `path.inSelection`, so
        // with no active selection at mount time the count drops to ~0.
        //
        // Selection is left UNSET on purpose — `editorState.selection`
        // stays null after the editor mounts, so every block's
        // `path.inSelection(null)` is false. Pre-fix every BSA/BHA
        // still scheduled; post-fix none should.
        BlockSelectionArea.debugInitStateScheduleCount = 0;
        BlockHighlightArea.debugInitStateScheduleCount = 0;
        final editor = await setupEditor(tester, paragraphCount: 200);

        final bsaSchedules = BlockSelectionArea.debugInitStateScheduleCount;
        final bhaSchedules = BlockHighlightArea.debugInitStateScheduleCount;
        final total = bsaSchedules + bhaSchedules;

        debugPrint('\n${'=' * 60}');
        debugPrint('H2.8.e — initState postFrame schedule count');
        debugPrint('=' * 60);
        debugPrint('Document: 200 paragraphs, no active selection');
        debugPrint('BSA initState schedules: $bsaSchedules');
        debugPrint('BHA initState schedules: $bhaSchedules');
        debugPrint('Total: $total');
        debugPrint('Pre-H2.8.e: 180  Post-H2.8.e: 0');
        debugPrint('${'=' * 60}\n');

        // Regression gate. Pre-fix value was 180 (36 visible blocks × 5
        // widgets). Post-fix should be 0 because no block intersects
        // null selection. Allow a small slack (≤ 10) for future
        // changes that might tweak supportTypes / container layout.
        expect(
          total,
          lessThanOrEqualTo(10),
          reason:
              'BSA/BHA initState should NOT schedule a postFrame when '
              'this block path is outside the current selection (H2.8.e). '
              'Regression would push this back to ~180 on a 200-paragraph '
              'doc with no active selection.',
        );

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
