import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/mobile_gesture_strategy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AndroidGestureStrategy extends MobileGestureStrategy {
  AndroidGestureStrategy({
    required super.pan,
    required super.editorState,
    required super.getNodeInOffset,
    required super.getPositionInOffset,
    required super.updateSelection,
    required super.clearSelection,
  });

  @override
  void onTapUp(TapUpDetails details) {
    final offset = details.globalPosition;

    clearSelection();

    // make a collapsed selection at offset
    final position = getPositionInOffset(offset);
    if (position == null) {
      return;
    }

    editorState.updateSelectionWithReason(
      Selection.collapsed(position),
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: null,
    );
  }

  @override
  void onLongPressStart(LongPressStartDetails details) {
    final offset = details.globalPosition;
    pan.panStartOffset = offset;
    pan.panStartScrollDy = editorState.service.scrollService?.dy;
    final node = getNodeInOffset(offset);
    // select word boundary closest to offset
    final selection = node?.selectable?.getWordBoundaryInOffset(offset);
    if (selection == null) {
      clearSelection();
      return;
    }

    if (editorState.editorStyle.enableHapticFeedbackOnAndroid) {
      HapticFeedback.mediumImpact();
    }

    pan.dragMode = MobileSelectionDragMode.cursor;
    pan.panStartSelection = selection;
    pan.lastPanOffset.value = offset;

    editorState.updateSelectionWithReason(
      selection,
      reason: SelectionUpdateReason.uiEvent,
      extraInfo: {
        selectionDragModeKey: pan.dragMode,
        selectionExtraInfoDisableFloatingToolbar: true,
      },
    );
  }

  @override
  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (pan.panStartOffset == null || pan.panStartScrollDy == null) {
      return;
    }
    if (editorState.selection == null ||
        pan.dragMode == MobileSelectionDragMode.none) {
      return;
    }

    final offset = details.globalPosition;
    pan.lastPanOffset.value = offset;

    final wordBoundary = getNodeInOffset(
      offset,
    )?.selectable?.getWordBoundaryInOffset(offset);

    Selection? newSelection;

    // extend selection from pan.panStartSelection to word boundary closest to offset
    if (wordBoundary != null) {
      final startSelection = pan.panStartSelection!;
      if (wordBoundary.end.path > startSelection.end.path ||
          wordBoundary.end.path.equals(startSelection.end.path) &&
              wordBoundary.end.offset > startSelection.end.offset) {
        newSelection = Selection(
          start: startSelection.start,
          end: wordBoundary.end,
        ).normalized;
      } else if (wordBoundary.start.path < startSelection.start.path ||
          wordBoundary.start.path.equals(startSelection.start.path) &&
              wordBoundary.start.offset < startSelection.start.offset) {
        newSelection = Selection(
          start: startSelection.end,
          end: wordBoundary.start,
        ).normalized;
      } else {
        newSelection = startSelection;
      }
    }

    if (newSelection != null) {
      editorState.updateSelectionWithReason(
        newSelection,
        reason: SelectionUpdateReason.uiEvent,
        extraInfo: {
          selectionDragModeKey: pan.dragMode,
          selectionExtraInfoDisableFloatingToolbar: true,
        },
      );
    }
  }

  @override
  void onLongPressEnd(LongPressEndDetails details) {
    pan.clearPan();
    pan.dragMode = MobileSelectionDragMode.none;

    editorState.updateSelectionWithReason(
      editorState.selection,
      reason: SelectionUpdateReason.uiEvent,
      extraInfo: {selectionExtraInfoDoNotAttachTextService: false},
    );
  }

  @override
  void onPanUpdate(DragUpdateDetails details) {
    // if current pan gesture is not initially horizontal, return
    if (pan.isPanStartHorizontal == false) {
      return;
    }
    // first call to onPanUpdate to determine if current pan gesture is horizontal
    // if not, disable future calls in the guard clause above
    if (details.delta.dx.abs() < details.delta.dy.abs() &&
        (pan.panStartOffset == null || pan.panStartScrollDy == null)) {
      pan.isPanStartHorizontal = false;
      return;
    }
    // first successful call to onPanUpdate, initialize pan variables
    final offset = details.globalPosition;
    if (pan.panStartOffset == null || pan.panStartScrollDy == null) {
      pan.panStartOffset = offset;
      pan.panStartScrollDy = editorState.service.scrollService?.dy;
      pan.dragMode = MobileSelectionDragMode.cursor;
    }

    final position = getPositionInOffset(offset);

    pan.lastPanOffset.value = offset;
    if (position == null) {
      return;
    }

    final selection = Selection.collapsed(position);

    if (editorState.editorStyle.enableHapticFeedbackOnAndroid) {
      HapticFeedback.lightImpact();
    }
    updateSelection(selection);
  }

  @override
  void onPanEnd(DragEndDetails details) {
    pan.clearPan();
    pan.dragMode = MobileSelectionDragMode.none;
    pan.isPanStartHorizontal = null;

    editorState.updateSelectionWithReason(
      editorState.selection,
      reason: SelectionUpdateReason.uiEvent,
      extraInfo: {
        selectionExtraInfoDoNotAttachTextService: false,
        selectionExtraInfoDisableFloatingToolbar: true,
      },
    );
  }
}
