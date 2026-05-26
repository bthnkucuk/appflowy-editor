import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// High-level test helpers that read like English, modeled after
/// super_editor's `SuperEditorRobot` extension
/// (`super_editor/lib/src/test/super_editor_test/supereditor_robot.dart`).
///
/// Use these alongside the existing `TestableEditor` infra in
/// `testable_editor.dart`. The pattern:
///
/// ```dart
/// final editor = tester.editor..addParagraphs(5, initialText: 'lorem ipsum');
/// await editor.startTesting(inMobile: true, platform: TargetPlatform.android);
///
/// await tester.placeCaretInParagraph(2, 6);
/// await tester.longPressInParagraph(3, 4);
/// ```
///
/// The robot reads the live `EditorState` out of the mounted
/// `AppFlowyEditor` widget rather than constructing a fresh one each
/// call (which `tester.editorState` would do — see
/// `TestableEditorExtension`).
extension EditorRobot on WidgetTester {
  /// The mounted editor state. Assumes exactly one `AppFlowyEditor` is
  /// in the widget tree (the standard test setup).
  EditorState get _mountedEditorState =>
      widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

  /// Returns the global-coordinate center of the character at
  /// `(nodeIndex, offset)`. Used by gesture helpers to compute where
  /// to tap / press.
  ///
  /// Throws `TestFailure` if the node hasn't laid out yet or doesn't
  /// expose a `selectable`. Pump enough frames before calling.
  Offset characterOffset(int nodeIndex, int offset) {
    final state = _mountedEditorState;
    final node = state.document.nodeAtPath([nodeIndex]);
    if (node == null) {
      throw TestFailure('No node at path [$nodeIndex]');
    }
    final selectable = node.selectable;
    if (selectable == null) {
      throw TestFailure('Node at [$nodeIndex] has no Selectable');
    }
    final rect = selectable.getCursorRectInPosition(
      Position(path: [nodeIndex], offset: offset),
    );
    if (rect == null) {
      throw TestFailure(
        'getCursorRectInPosition returned null for [$nodeIndex]:$offset — '
        'is the paragraph laid out? Try `await tester.pumpAndSettle()` first.',
      );
    }
    final global = selectable.transformRectToGlobal(rect);
    return global.center;
  }

  /// Places the caret at `(nodeIndex, offset)` by writing the selection
  /// directly to the editor state. Equivalent to a precise tap from the
  /// user's perspective, without the gesture-arena round-trip.
  Future<void> placeCaretInParagraph(int nodeIndex, int offset) async {
    _mountedEditorState.updateSelectionWithReason(
      Selection.collapsed(Position(path: [nodeIndex], offset: offset)),
      reason: SelectionUpdateReason.uiEvent,
    );
    await pumpAndSettle();
  }

  /// Simulates a long-press at `(nodeIndex, offset)`. On mobile this
  /// triggers the gesture strategy's `onLongPressStart` — which
  /// typically expands the selection to the word boundary at that
  /// position. Use [dragLongPressBy] to extend further.
  ///
  /// The gesture is NOT released; call [releaseLongPress] when done so
  /// `onLongPressEnd` fires and the drag mode clears.
  Future<TestGesture> longPressInParagraph(int nodeIndex, int offset) async {
    final target = characterOffset(nodeIndex, offset);
    final gesture = await startGesture(target);
    // Wait past the long-press recognizer threshold (Flutter default
    // 500 ms; some platforms tighter, all under 700 ms).
    await pump(const Duration(milliseconds: 700));
    return gesture;
  }

  /// Releases the active long-press gesture. Fires `onLongPressEnd` on
  /// the gesture strategy, which clears `pan.dragMode` and re-attaches
  /// the IME.
  Future<void> releaseLongPress(TestGesture gesture) async {
    await gesture.up();
    await pumpAndSettle();
  }
}
