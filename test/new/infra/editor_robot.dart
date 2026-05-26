import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_magnifier.dart';
import 'package:appflowy_editor/src/render/selection/mobile_basic_handle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'testable_editor.dart';

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

  /// Moves an in-flight long-press to `(nodeIndex, offset)`.
  ///
  /// Use after [longPressInParagraph] to extend the long-press selection
  /// across the document — the Android strategy's
  /// `onLongPressMoveUpdate` runs each `moveTo`, growing the selection
  /// from the original word boundary toward the new global position.
  ///
  /// We pump a 16 ms frame before the move so the
  /// `LongPressGestureRecognizer` has settled into its
  /// move-update-emitting state; without this the first move can be
  /// dropped on the floor.
  Future<void> dragLongPressTo(
    TestGesture gesture,
    int nodeIndex,
    int offset,
  ) async {
    await pump(const Duration(milliseconds: 16));
    final target = characterOffset(nodeIndex, offset);
    await gesture.moveTo(target);
    await pump(const Duration(milliseconds: 16));
  }

  /// Starts a pan gesture from the center of the matching drag handle.
  ///
  /// The mobile drag handles (`_AndroidDragHandle`, `_IOSDragHandle`)
  /// are private classes, so we find them via the public
  /// `HandleType.<x>.key` GlobalKey their topmost SizedBox carries.
  /// Returns the live [TestGesture]; pass it to [dragHandleBy] and
  /// [releaseHandle].
  Future<TestGesture> pressDownOnHandle(HandleType handleType) async {
    if (handleType == HandleType.none) {
      throw ArgumentError('pressDownOnHandle: HandleType.none has no widget');
    }
    final key = handleType.key;
    final context = key.currentContext;
    if (context == null) {
      throw TestFailure(
        'No mounted widget for HandleType.$handleType — is a selection '
        'live and the mobile selection service mounted? Set '
        'PlatformExtension.debugPlatformOverride and call '
        '`startTesting(inMobile: true)` before pumping a selection.',
      );
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      throw TestFailure(
        'HandleType.$handleType render object is not a RenderBox '
        '(got ${renderObject.runtimeType}).',
      );
    }
    final center = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );
    return startGesture(center);
  }

  /// Drags an in-flight handle gesture by a relative delta.
  Future<void> dragHandleBy(TestGesture gesture, Offset delta) async {
    await gesture.moveBy(delta);
    await pump(const Duration(milliseconds: 16));
  }

  /// Releases an in-flight handle gesture.
  Future<void> releaseHandle(TestGesture gesture) async {
    await gesture.up();
    await pumpAndSettle();
  }

  // ---------------------------------------------------------------------------
  // Tap-cluster + IME + magnifier helpers
  //
  // Added in a separate block at the end of the extension to keep diff
  // collisions with the parallel drag-handle helpers minimal.
  // ---------------------------------------------------------------------------

  /// Simulates a double-tap at `(nodeIndex, offset)`.
  ///
  /// Two `tapAt` calls separated by 80 ms — comfortably above
  /// [kDoubleTapMinTime] (40 ms, minimum gap between distinct taps) and
  /// well under [kDoubleTapTimeout] (300 ms, the maximum gap to still
  /// count as a double-tap). Mirrors super_editor's
  /// `doubleTapInParagraph`.
  ///
  /// On mobile this should fire `MobileGestureStrategy.onDoubleTapUp` →
  /// select the word boundary at the tap.
  Future<void> doubleTapInParagraph(int nodeIndex, int offset) async {
    final target = characterOffset(nodeIndex, offset);
    await tapAt(target);
    // Use `pump`, NOT `pumpAndSettle`, between intermediate taps — the
    // settle could advance past the 300 ms double-tap window inside
    // `MobileSelectionGestureDetectorState._tapDownDelegate` and reset
    // the state machine.
    await pump(const Duration(milliseconds: 80));
    await tapAt(target);
    await pumpAndSettle();
  }

  /// Simulates a triple-tap at `(nodeIndex, offset)`.
  ///
  /// Three `tapAt` calls with 80 ms between each — under both the
  /// 300 ms `kDoubleTapTimeout` (Flutter's) and the 500 ms
  /// `kTripleTapTimeout` defined in
  /// `MobileSelectionGestureDetectorState`.
  ///
  /// On mobile this should fire
  /// `MobileGestureStrategy.onTripleTapUp` → select the entire node.
  Future<void> tripleTapInParagraph(int nodeIndex, int offset) async {
    final target = characterOffset(nodeIndex, offset);
    await tapAt(target);
    await pump(const Duration(milliseconds: 80));
    await tapAt(target);
    await pump(const Duration(milliseconds: 80));
    await tapAt(target);
    await pumpAndSettle();
  }

  /// Sends `text` through the live IME channel by delegating to the
  /// existing [MockIMEInput.typeText] on [editor].
  ///
  /// Takes the [TestableEditor] explicitly: the IME's
  /// [TextInputService] is mounted under the editor's
  /// `KeyboardServiceWidget`, and `MockIMEInput` resolves it via the
  /// `WidgetTester`. We can't go through `WidgetTester.editorState`
  /// because [TestableEditorExtension] allocates a fresh
  /// [TestableEditor] each call (see `testable_editor.dart`).
  Future<void> typeImeText(TestableEditor editor, String text) async {
    await editor.ime.typeText(text);
  }

  /// Asserts whether a [MobileMagnifier] is currently rendered.
  ///
  /// The magnifier mounts only on the mobile selection service path
  /// (iOS, in practice) and only when `disableMagnifier == false`,
  /// `showMagnifier` is true on `MobileSelectionServiceWidget`, and
  /// `PanDragState.lastPanOffset` is non-null. After
  /// `onLongPressEnd` the strategy calls `pan.clearPan()` which nulls
  /// the offset, so the overlay collapses to `SizedBox.shrink()`.
  void expectMagnifierVisible({required bool visible}) {
    final finder = find.byType(MobileMagnifier);
    expect(
      finder,
      visible ? findsOneWidget : findsNothing,
      reason: visible
          ? 'Expected MobileMagnifier to be in the tree (long-press in '
                'progress + disableMagnifier=false + iOS strategy).'
          : 'Expected MobileMagnifier to be gone (long-press released, '
                'pan.lastPanOffset null, or disableMagnifier=true).',
    );
  }
}
