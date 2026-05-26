import 'package:appflowy_editor/src/core/document/node.dart';
import 'package:appflowy_editor/src/core/location/selection.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/pan_drag_state.dart';
import 'package:appflowy_editor/src/editor_state.dart';
import 'package:appflowy_editor/src/extensions/node_extensions.dart';
import 'package:flutter/material.dart';

/// Drives the selection update that happens when the editor scrolls while
/// the user is mid-drag (handle drag or cursor drag). The scroll listener
/// stays subscribed on [EditorState] by the facade, which forwards each
/// tick to [onScroll].
///
/// The post-frame callback inside [onScroll] is intentional: by the time
/// the scroll listener fires, the new scroll offset is known but the
/// rebuilt layout hasn't run yet. Re-deriving the selection in the next
/// frame ensures [getNodeInOffset] sees the post-scroll positions.
class MobileSelectionAutoScroller {
  MobileSelectionAutoScroller({
    required this.pan,
    required this.editorState,
    required this.isMounted,
    required this.getNodeInOffset,
    required this.commitSelection,
  });

  final PanDragState pan;
  final EditorState editorState;
  final bool Function() isMounted;
  final Node? Function(Offset) getNodeInOffset;
  final void Function(Selection) commitSelection;

  /// Wired to [EditorState.addScrollViewScrolledListener] by the facade.
  void onScroll() {
    if (!isMounted() || pan.dragMode == MobileSelectionDragMode.none) {
      return;
    }
    if (pan.panStartOffset == null ||
        pan.panStartSelection == null ||
        pan.lastPanOffset.value == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted() ||
          pan.dragMode == MobileSelectionDragMode.none ||
          pan.panStartOffset == null ||
          pan.panStartSelection == null) {
        return;
      }
      final offset = pan.lastPanOffset.value;
      if (offset == null) {
        return;
      }
      _updateSelectionDuringDrag(offset);
    });
  }

  void _updateSelectionDuringDrag(Offset panEndOffset) {
    if (pan.panStartOffset == null || pan.panStartSelection == null) {
      return;
    }

    final double? dy = editorState.scrollService?.dy;
    final Offset panStartOffset;
    if (dy == null || pan.panStartScrollDy == null) {
      panStartOffset = pan.panStartOffset!;
    } else {
      panStartOffset = pan.panStartOffset!.translate(
        0,
        pan.panStartScrollDy! - dy,
      );
    }

    final selectionInRange = getNodeInOffset(
      panEndOffset,
    )?.selectable?.getSelectionInRange(panStartOffset, panEndOffset);
    final end = selectionInRange?.end;
    if (end == null) {
      return;
    }

    late final Selection newSelection;
    switch (pan.dragMode) {
      case MobileSelectionDragMode.leftSelectionHandle:
        newSelection = Selection(
          start: pan.panStartSelection!.normalized.end,
          end: end,
        ).normalized;
        break;

      case MobileSelectionDragMode.rightSelectionHandle:
        newSelection = Selection(
          start: pan.panStartSelection!.normalized.start,
          end: end,
        ).normalized;
        break;

      case MobileSelectionDragMode.cursor:
        newSelection = Selection.collapsed(end);
        break;

      case MobileSelectionDragMode.none:
        return;
    }

    commitSelection(newSelection);
  }
}
