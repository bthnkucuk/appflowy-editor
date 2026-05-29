import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

EditorState _makeEditorState({int paragraphs = 20}) {
  return EditorState(
    document: Document.blank()
      ..insert(
        [0],
        List.generate(paragraphs, (i) => paragraphNode(text: 'Paragraph $i')),
      ),
  );
}

/// In shrinkWrap mode the editor uses a `SingleChildScrollView` that
/// doesn't bind to `EditorScrollController.scrollController`. To exercise
/// the pixel-jump path in isolation we attach the controller to our own
/// scroll view of equivalent shape.
Widget _shrinkWrapHost(ScrollController controller) {
  return _wrap(
    SingleChildScrollView(
      controller: controller,
      child: const SizedBox(width: 100, height: 5000),
    ),
  );
}

void main() {
  group('EditorScrollController.jumpToPixels', () {
    testWidgets('scrolls to the given pixel offset in shrinkWrap mode', (
      tester,
    ) async {
      final editorState = _makeEditorState();
      final controller = EditorScrollController(
        editorState: editorState,
        shrinkWrap: true,
      );
      await tester.pumpWidget(_shrinkWrapHost(controller.scrollController));

      controller.jumpToPixels(200);
      await tester.pump();

      expect(controller.scrollController.offset, 200);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      controller.dispose();
      editorState.dispose();
    });

    testWidgets('clamps to maxScrollExtent', (tester) async {
      final editorState = _makeEditorState();
      final controller = EditorScrollController(
        editorState: editorState,
        shrinkWrap: true,
      );
      await tester.pumpWidget(_shrinkWrapHost(controller.scrollController));

      controller.jumpToPixels(1e9);
      await tester.pump();

      expect(
        controller.scrollController.offset,
        controller.scrollController.position.maxScrollExtent,
      );

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      controller.dispose();
      editorState.dispose();
    });

    testWidgets('no-op in non-shrinkWrap mode', (tester) async {
      final editorState = _makeEditorState(paragraphs: 30);
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

      final before = controller.scrollController.offset;
      controller.jumpToPixels(500);
      await tester.pump();
      expect(controller.scrollController.offset, before);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      controller.dispose();
      editorState.dispose();
    });
  });

  group('EditorScrollController.jumpToIndex', () {
    testWidgets('jumps to the target index in non-shrinkWrap mode', (
      tester,
    ) async {
      final editorState = _makeEditorState(paragraphs: 50);
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

      controller.jumpToIndex(index: 25);
      await tester.pumpAndSettle();

      final (start, end) = controller.visibleRangeNotifier.value;
      expect(start, lessThanOrEqualTo(25));
      expect(end, greaterThanOrEqualTo(25));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      controller.dispose();
      editorState.dispose();
    });
  });

  group('EditorScrollController.jumpTo (deprecated)', () {
    testWidgets('forwards to jumpToPixels in shrinkWrap mode', (tester) async {
      final editorState = _makeEditorState();
      final controller = EditorScrollController(
        editorState: editorState,
        shrinkWrap: true,
      );
      await tester.pumpWidget(_shrinkWrapHost(controller.scrollController));

      // ignore: deprecated_member_use_from_same_package
      controller.jumpTo(offset: 150);
      await tester.pump();

      expect(controller.scrollController.offset, 150);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      controller.dispose();
      editorState.dispose();
    });

    testWidgets('forwards to jumpToIndex in non-shrinkWrap mode', (
      tester,
    ) async {
      final editorState = _makeEditorState(paragraphs: 50);
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

      // ignore: deprecated_member_use_from_same_package
      controller.jumpTo(offset: 25);
      await tester.pumpAndSettle();

      final (start, end) = controller.visibleRangeNotifier.value;
      expect(start, lessThanOrEqualTo(25));
      expect(end, greaterThanOrEqualTo(25));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      controller.dispose();
      editorState.dispose();
    });
  });
}
