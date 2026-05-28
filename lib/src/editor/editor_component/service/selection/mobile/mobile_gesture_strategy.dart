import '../../../../../core/document/node.dart';
import '../../../../../core/location/position.dart';
import '../../../../../core/location/selection.dart';
import 'pan_drag_state.dart';
import '../../../../../editor_state.dart';
import '../../../../../extensions/node_extensions.dart';
import 'package:flutter/material.dart';

/// Platform-specific gesture routing for the mobile selection service.
///
/// The facade decides iOS vs Android once in [State.build]; the strategy
/// owns the shape of each gesture flow (tap = collapse vs word-edge,
/// long-press = cursor drag vs word-boundary expansion, etc.).
///
/// All strategies share the same [PanDragState] spine — they read and
/// write pan coordinates and [PanDragState.dragMode] directly. Selection
/// writes go through [updateSelection] (the facade's wrapper that keeps
/// `selectionRects` consistent) or, for raw notifications without
/// rect-area recomputation, through [editorState.updateSelectionWithReason]
/// in the strategy itself.
abstract class MobileGestureStrategy {
  MobileGestureStrategy({
    required this.pan,
    required this.editorState,
    required this.getNodeInOffset,
    required this.getPositionInOffset,
    required this.updateSelection,
    required this.clearSelection,
  });

  final PanDragState pan;
  final EditorState editorState;
  final Node? Function(Offset) getNodeInOffset;
  final Position? Function(Offset) getPositionInOffset;
  final void Function(Selection?) updateSelection;
  final void Function() clearSelection;

  void onTapUp(TapUpDetails details);
  void onLongPressStart(LongPressStartDetails details);
  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details);
  void onLongPressEnd(LongPressEndDetails details);

  /// Android only — iOS leaves this as a no-op (its gesture detector
  /// doesn't wire `onPanUpdate`).
  void onPanUpdate(DragUpdateDetails details) {}

  /// Android only — see [onPanUpdate].
  void onPanEnd(DragEndDetails details) {}

  /// Identical on both platforms — select the word boundary at the tap.
  void onDoubleTapUp(TapUpDetails details) {
    final offset = details.globalPosition;
    final node = getNodeInOffset(offset);
    final selection = node?.selectable?.getWordBoundaryInOffset(offset);
    if (selection == null) {
      clearSelection();
      return;
    }
    updateSelection(selection);
  }

  /// Identical on both platforms — select the entire node at the tap.
  void onTripleTapUp(TapUpDetails details) {
    final offset = details.globalPosition;
    final node = getNodeInOffset(offset);
    final selectable = node?.selectable;
    if (selectable == null) {
      clearSelection();
      return;
    }
    updateSelection(
      Selection(start: selectable.start(), end: selectable.end()),
    );
  }
}
