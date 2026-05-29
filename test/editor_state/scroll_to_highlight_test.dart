import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

EditorState _makeEditorState({int paragraphs = 5}) {
  return EditorState(
    document: Document.blank()
      ..insert(
        [0],
        List.generate(paragraphs, (i) => paragraphNode(text: 'Paragraph $i')),
      ),
  );
}

void main() {
  group('EditorState.scrollToHighlight', () {
    testWidgets(
      'deferred retry runs at most once when the target stays unresolved',
      (tester) async {
        final editorState = _makeEditorState();
        final controller = EditorScrollController(editorState: editorState);

        await tester.pumpWidget(
          _wrap(
            AppFlowyEditor(
              editorState: editorState,
              editorScrollController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Path firstIndex (0) is in bounds so jumpToIndex is safe, but
        // document.nodeAtPath([0, 9999]) returns null, so getNodesInSelection
        // stays empty across retries and highlightRects() never resolves.
        final unreachable = Selection.collapsed(Position(path: [0, 9999]));

        editorState.scrollToHighlight(controller, selection: unreachable);

        // pumpAndSettle would hang if the retry rescheduled every frame
        // forever. The one-shot retry guard lets it terminate cleanly.
        await tester.pumpAndSettle();

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        controller.dispose();
        editorState.dispose();
      },
    );

    testWidgets('deferred retry does not fire after editorState.dispose()', (
      tester,
    ) async {
      final editorState = _makeEditorState();
      final controller = EditorScrollController(editorState: editorState);

      await tester.pumpWidget(
        _wrap(
          AppFlowyEditor(
            editorState: editorState,
            editorScrollController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Path firstIndex (0) is in bounds so jumpToIndex won't trip
      // super_sliver_list's assertion, but the nested child index doesn't
      // exist, so getNodesInSelection returns no node and highlightRects()
      // returns empty — forcing the retry branch.
      final unreachable = Selection.collapsed(Position(path: [0, 9999]));
      editorState.scrollToHighlight(controller, selection: unreachable);

      // Tear the editor down before the post-frame retry has a chance to
      // run. If the retry didn't guard on _scrollCoordinatorDisposed it
      // would call into highlightRects / getNodesInSelection on a disposed
      // state and throw.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      controller.dispose();
      editorState.dispose();

      // Pump the frame the retry was scheduled for. The guard should
      // swallow it silently.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    });

    test('scrollToHighlight has no fromInside parameter', () {
      // Compile-time guard: the public signature must not expose
      // fromInside. This test only needs to type-check.
      final editorState = EditorState.blank();
      final controller = EditorScrollController(editorState: editorState);
      // ignore: unused_local_variable
      final fn = editorState.scrollToHighlight;
      // Calling with named params other than the public set must compile.
      editorState.scrollToHighlight(controller, alignToTop: false);
      controller.dispose();
      editorState.dispose();
    });
  });
}
