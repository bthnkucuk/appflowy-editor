// Decomposes the 820μs/update measurement: how much is `tester.pump()`
// overhead itself vs. work driven by the selection change?
//
// Setting `editorState.selection` once with no listeners → pure
// PropertyValueNotifier path (~5μs).
// Setting it once on the real editor → fan-out + rebuilds.
// `tester.pump()` with no changes → baseline pump cost.

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/testable_editor.dart';

void main() {
  testWidgets('attribution: tester.pump() with no changes (50×)', (tester) async {
    final editor = tester.editor..addParagraph(initialText: 'X');
    await editor.startTesting();

    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }

    final sw = Stopwatch()..start();
    for (var i = 0; i < 50; i++) {
      await tester.pump();
    }
    sw.stop();
    debugPrint('[ATTR] pure tester.pump() no-op: '
        '${(sw.elapsedMicroseconds / 50).toStringAsFixed(1)}μs/pump');

    await editor.dispose();
  });

  testWidgets('attribution: selection setter only (no pump) 5000×', (tester) async {
    final editor = tester.editor..addParagraph(initialText: 'Sample text here');
    await editor.startTesting();
    final editorState = editor.editorState;

    for (var i = 0; i < 100; i++) {
      editorState.selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: (i % 10) + 1,
      );
    }

    final sw = Stopwatch()..start();
    for (var i = 0; i < 5000; i++) {
      editorState.selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: (i % 10) + 1,
      );
    }
    sw.stop();
    debugPrint('[ATTR] selection setter (no pump): '
        '${(sw.elapsedMicroseconds * 1000 / 5000).toStringAsFixed(1)}ns/set');

    // One final pump to flush.
    await tester.pump();
    await editor.dispose();
  });

  testWidgets('attribution: setter + pump 100×', (tester) async {
    final editor = tester.editor..addParagraph(initialText: 'Sample text here');
    await editor.startTesting();
    final editorState = editor.editorState;

    for (var i = 0; i < 10; i++) {
      editorState.selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: i + 1,
      );
      await tester.pump();
    }

    final sw = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      editorState.selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: (i % 10) + 1,
      );
      await tester.pump();
    }
    sw.stop();
    debugPrint('[ATTR] setter + pump: '
        '${(sw.elapsedMicroseconds / 100).toStringAsFixed(1)}μs/iter');

    await editor.dispose();
  });
}
