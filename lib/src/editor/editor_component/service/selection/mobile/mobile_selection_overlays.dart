import 'dart:async';

import 'package:appflowy_editor/src/core/location/selection.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/pan_drag_state.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_magnifier.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    show MobileSelectionDragMode, disableMagnifier;
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:appflowy_editor/src/editor/util/property_notifier.dart';
import 'package:appflowy_editor/src/editor_state.dart';
import 'package:appflowy_editor/src/extensions/node_extensions.dart';
import 'package:appflowy_editor/src/render/selection/mobile_basic_handle.dart';
import 'package:appflowy_editor/src/render/selection/mobile_collapsed_handle.dart';
import 'package:appflowy_editor/src/render/selection/mobile_selection_handle.dart';
import 'package:flutter/material.dart';

/// The lens that follows the user's finger during a long-press / drag on
/// mobile. Listens to [PanDragState.lastPanOffset] and renders nothing
/// when the offset is null or [disableMagnifier] is set.
class MagnifierOverlay extends StatelessWidget {
  const MagnifierOverlay({super.key, required this.pan, required this.size});

  final PanDragState pan;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset?>(
      valueListenable: pan.lastPanOffset,
      builder: (_, offset, _) {
        if (offset == null || disableMagnifier) {
          return const SizedBox.shrink();
        }
        // Convert in the ANCESTOR render box's coordinate space (the
        // surrounding Stack), not this overlay's own render box —
        // findRenderObject() on this widget's context returns the
        // magnifier's own bounds, which is the wrong frame of reference.
        final renderBox = context.findAncestorRenderObjectOfType<RenderBox>();
        if (renderBox == null) {
          return const SizedBox.shrink();
        }
        final local = renderBox.globalToLocal(offset);

        return MobileMagnifier(size: size, offset: local);
      },
    );
  }
}

/// The left or right drag handle anchoring an active selection. Rebuilds
/// when [selectionNotifierAfterLayout] fires (post-layout, so the
/// anchor rect is valid). Hides itself when the selection is collapsed
/// and no handle is being dragged.
class SelectionHandleOverlay extends StatelessWidget {
  const SelectionHandleOverlay({
    super.key,
    required this.handleType,
    required this.editorState,
    required this.pan,
    required this.selectionNotifierAfterLayout,
  }) : assert(
         handleType == HandleType.left || handleType == HandleType.right,
         'SelectionHandleOverlay only supports left or right',
       );

  final HandleType handleType;
  final EditorState editorState;
  final PanDragState pan;
  final PropertyValueNotifier<Selection?> selectionNotifierAfterLayout;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Selection?>(
      valueListenable: selectionNotifierAfterLayout,
      builder: (context, selection, _) {
        if (selection == null) {
          return const SizedBox.shrink();
        }

        if (selection.isCollapsed &&
            [
              MobileSelectionDragMode.none,
              MobileSelectionDragMode.cursor,
            ].contains(pan.dragMode)) {
          return const SizedBox.shrink();
        }

        final isCollapsedWhenDraggingHandle =
            selection.isCollapsed &&
            [
              MobileSelectionDragMode.leftSelectionHandle,
              MobileSelectionDragMode.rightSelectionHandle,
            ].contains(pan.dragMode);

        final normalized = selection.normalized;

        final node = editorState.getNodeAtPath(
          handleType == HandleType.left
              ? normalized.start.path
              : normalized.end.path,
        );
        final selectable = node?.selectable;

        // get the cursor rect when the selection is collapsed.
        final rects = isCollapsedWhenDraggingHandle
            ? [
                selectable?.getCursorRectInPosition(
                      normalized.start,
                      shiftWithBaseOffset: true,
                    ) ??
                    Rect.zero,
              ]
            : selectable?.getRectsInSelection(
                normalized,
                shiftWithBaseOffset: true,
              );

        if (node == null || rects == null || rects.isEmpty) {
          return const SizedBox.shrink();
        }

        final editorStyle = editorState.editorStyle;

        return MobileSelectionHandle(
          layerLink: node.layerLink,
          rect: handleType == HandleType.left ? rects.first : rects.last,
          handleType: handleType,
          handleColor: isCollapsedWhenDraggingHandle
              ? Colors.transparent
              : editorStyle.dragHandleColor,
          handleWidth: editorStyle.mobileDragHandleWidth,
          handleBallWidth: editorStyle.mobileDragHandleBallSize.width,
          enableHapticFeedbackOnAndroid:
              editorStyle.enableHapticFeedbackOnAndroid,
        );
      },
    );
  }
}

/// The cursor handle shown when the selection is collapsed. Owns its own
/// Android auto-dismiss timer — the handle hides after
/// [EditorStyle.autoDismissCollapsedHandleDuration] of no user interaction.
/// iOS hides it implicitly when the selection becomes non-collapsed.
class CollapsedHandleOverlay extends StatefulWidget {
  const CollapsedHandleOverlay({
    super.key,
    required this.editorState,
    required this.pan,
    required this.selectionNotifierAfterLayout,
  });

  final EditorState editorState;
  final PanDragState pan;
  final PropertyValueNotifier<Selection?> selectionNotifierAfterLayout;

  @override
  State<CollapsedHandleOverlay> createState() => _CollapsedHandleOverlayState();
}

class _CollapsedHandleOverlayState extends State<CollapsedHandleOverlay> {
  Timer? _autoDismissTimer;
  bool _visible = false;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleAndroidAutoDismiss() {
    if (!PlatformExtension.isAndroid) {
      return;
    }
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(
      widget.editorState.editorStyle.autoDismissCollapsedHandleDuration,
      () {
        if (_visible) {
          widget.editorState.updateSelectionWithReason(
            widget.editorState.selection,
            reason: SelectionUpdateReason.transaction,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Selection?>(
      valueListenable: widget.selectionNotifierAfterLayout,
      builder: (context, selection, _) {
        if (selection == null || !selection.isCollapsed) {
          _visible = false;

          return const SizedBox.shrink();
        }

        // on Android, the drag handle should be updated when typing text.
        if (PlatformExtension.isAndroid &&
            widget.editorState.selectionUpdateReason !=
                SelectionUpdateReason.uiEvent) {
          _visible = false;

          return const SizedBox.shrink();
        }

        if (selection.isCollapsed &&
            [
              MobileSelectionDragMode.leftSelectionHandle,
              MobileSelectionDragMode.rightSelectionHandle,
            ].contains(widget.pan.dragMode)) {
          _visible = false;

          return const SizedBox.shrink();
        }

        final normalized = selection.normalized;

        final node = widget.editorState.getNodeAtPath(normalized.start.path);
        final selectable = node?.selectable;
        final rect = selectable?.getCursorRectInPosition(
          normalized.start,
          shiftWithBaseOffset: true,
        );

        if (node == null || rect == null) {
          _visible = false;

          return const SizedBox.shrink();
        }

        _visible = true;

        _scheduleAndroidAutoDismiss();

        final editorStyle = widget.editorState.editorStyle;

        return MobileCollapsedHandle(
          layerLink: node.layerLink,
          rect: rect,
          handleColor: editorStyle.dragHandleColor,
          handleWidth: editorStyle.mobileDragHandleWidth,
          handleBallWidth: editorStyle.mobileDragHandleBallSize.width,
          enableHapticFeedbackOnAndroid:
              editorStyle.enableHapticFeedbackOnAndroid,
          onDragging: (isDragging) {
            if (isDragging) {
              _autoDismissTimer?.cancel();
              _autoDismissTimer = null;
            } else {
              _scheduleAndroidAutoDismiss();
            }
          },
        );
      },
    );
  }
}
