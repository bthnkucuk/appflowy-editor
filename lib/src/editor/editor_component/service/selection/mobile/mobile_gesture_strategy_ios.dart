import 'package:appflowy_editor/src/core/location/selection.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/mobile_gesture_strategy.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    show appFlowyEditorOnTapSelectionArea, disableIOSSelectWordEdgeOnTap;
import 'package:appflowy_editor/src/editor_state.dart';
import 'package:appflowy_editor/src/extensions/node_extensions.dart';
import 'package:flutter/material.dart';

class IOSGestureStrategy extends MobileGestureStrategy {
  IOSGestureStrategy({
    required super.pan,
    required super.editorState,
    required super.getNodeInOffset,
    required super.getPositionInOffset,
    required super.updateSelection,
    required super.clearSelection,
    required this.isClickOnSelectionArea,
  });

  /// Closure into the facade — reads `selectionRects` to detect a tap
  /// inside an active selection. iOS's tap-up emits a stream event in
  /// that case (the floating toolbar listens) and bails without
  /// re-selecting.
  final bool Function(Offset) isClickOnSelectionArea;

  @override
  void onTapUp(TapUpDetails details) {
    final offset = details.globalPosition;

    // if the tap happens on a selection area, don't change the selection
    if (isClickOnSelectionArea(offset)) {
      appFlowyEditorOnTapSelectionArea.add(0);
      return;
    }

    clearSelection();

    Selection? selection;
    if (disableIOSSelectWordEdgeOnTap) {
      final position = getPositionInOffset(offset);
      if (position != null) {
        selection = Selection.collapsed(position);
      }
    } else {
      // get the word edge closest to offset
      final node = getNodeInOffset(offset);
      selection = node?.selectable?.getWordEdgeInOffset(offset);
    }

    if (selection == null) {
      return;
    }

    editorState.updateSelectionWithReason(
      selection,
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: null,
    );
  }

  @override
  void onLongPressStart(LongPressStartDetails details) {
    final offset = details.globalPosition;
    pan.panStartOffset = offset;
    pan.panStartScrollDy = editorState.scrollService?.dy;
    pan.dragMode = MobileSelectionDragMode.cursor;

    // make a collapsed selection at offset with magnifier
    final position = getPositionInOffset(offset);
    if (position == null) {
      return;
    }

    pan.lastPanOffset.value = offset;
    updateSelection(Selection.collapsed(position));
  }

  @override
  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (pan.panStartOffset == null || pan.panStartScrollDy == null) {
      return;
    }

    // make a collapsed selection at offset with magnifier
    final offset = details.globalPosition;
    final position = getPositionInOffset(offset);
    if (position == null) {
      return;
    }

    pan.lastPanOffset.value = offset;
    updateSelection(Selection.collapsed(position));
  }

  @override
  void onLongPressEnd(LongPressEndDetails details) {
    pan.clearPan();
    pan.dragMode = MobileSelectionDragMode.none;

    editorState.updateSelectionWithReason(
      editorState.selection,
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: {selectionExtraInfoDoNotAttachTextService: false},
    );
  }
}
