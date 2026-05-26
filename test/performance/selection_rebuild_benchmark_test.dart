// Times the selection-service rebuild path (`_updateSelectionAreas` ->
// `selectable.getRectsInSelection` -> transform + collect into
// `selectionRects`) by performing N selection changes on a real document.
//
// Goal: establish whether the rebuild is a perf hot spot worth optimising
// vs. an already-small cost that should be left alone. No assertions on
// absolute timings — just prints per-update ns for human eyeballing.
//
// Run with:
//   fvm flutter test --concurrency=1 test/performance/selection_rebuild_benchmark_test.dart

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/testable_editor.dart';

void main() {
  group('Selection rebuild cost', () {
    testWidgets('extend collapsed selection 100× within one paragraph', (
      tester,
    ) async {
      // ~80-char paragraph: realistic single-line selection growth.
      const text =
          'The quick brown fox jumps over the lazy dog while a curious cat watches nearby.';
      final editor = tester.editor..addParagraph(initialText: text);
      await editor.startTesting();
      final editorState = editor.editorState;

      // Warm up.
      for (var i = 1; i <= 10; i++) {
        editorState.selection = Selection.single(
          path: [0],
          startOffset: 0,
          endOffset: i,
        );
        await tester.pump();
      }

      final sw = Stopwatch()..start();
      const iters = 100;
      for (var i = 1; i <= iters; i++) {
        editorState.selection = Selection.single(
          path: [0],
          startOffset: 0,
          endOffset: (i % (text.length - 1)) + 1,
        );
        await tester.pump();
      }
      sw.stop();

      _report('single-paragraph selection extend', sw, iters);
      await editor.dispose();
    });

    testWidgets('extend selection 50× across 5 paragraphs', (tester) async {
      // Multi-paragraph: each update walks 1..5 nodes.
      final editor = tester.editor
        ..addParagraphs(5, initialText: 'A paragraph of decent length here.');
      await editor.startTesting();
      final editorState = editor.editorState;

      for (var i = 1; i <= 5; i++) {
        editorState.selection = Selection(
          start: Position(path: [0], offset: 0),
          end: Position(path: [i % 5], offset: 5),
        );
        await tester.pump();
      }

      final sw = Stopwatch()..start();
      const iters = 50;
      for (var i = 1; i <= iters; i++) {
        editorState.selection = Selection(
          start: Position(path: [0], offset: 0),
          end: Position(path: [(i % 5)], offset: (i % 20) + 1),
        );
        await tester.pump();
      }
      sw.stop();

      _report('5-paragraph selection extend', sw, iters);
      await editor.dispose();
    });

    testWidgets(
      'duplicate selection set 100× (no actual change — should short-circuit)',
      (tester) async {
        final editor = tester.editor
          ..addParagraph(initialText: 'Sample text here');
        await editor.startTesting();
        final editorState = editor.editorState;

        final fixedSelection = Selection.single(
          path: [0],
          startOffset: 2,
          endOffset: 10,
        );
        editorState.selection = fixedSelection;
        await tester.pump();

        final sw = Stopwatch()..start();
        const iters = 100;
        for (var i = 0; i < iters; i++) {
          // Same Selection instance — service should detect no change.
          editorState.selection = fixedSelection;
          await tester.pump();
        }
        sw.stop();

        _report('duplicate selection (no-op)', sw, iters);
        await editor.dispose();
      },
    );
  });
}

void _report(String label, Stopwatch sw, int iters) {
  final perOpUs = sw.elapsedMicroseconds / iters;
  // ignore: avoid_print
  debugPrint(
    '[BENCH] $label: ${sw.elapsedMilliseconds}ms total, '
    '${perOpUs.toStringAsFixed(1)}μs/update ($iters updates)',
  );
}
