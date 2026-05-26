import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/mobile_gesture_strategy.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/mobile_gesture_strategy_android.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/mobile_gesture_strategy_ios.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/mobile_selection_auto_scroller.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/mobile_selection_overlays.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile/pan_drag_state.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/shared.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:appflowy_editor/src/render/selection/mobile_basic_handle.dart';
import 'package:appflowy_editor/src/service/selection/mobile_selection_gesture.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// only used in mobile
///
/// this will notify the developers when the selection is not collapsed.
StreamController<int> appFlowyEditorOnTapSelectionArea =
    StreamController<int>.broadcast();

enum MobileSelectionDragMode {
  none,
  leftSelectionHandle,
  rightSelectionHandle,
  cursor,
}

enum MobileSelectionHandlerType { leftHandle, rightHandle, cursorHandle }

// the value type is MobileSelectionDragMode
const String selectionDragModeKey = 'selection_drag_mode';
bool disableIOSSelectWordEdgeOnTap = false;
bool disableMagnifier = false;

class MobileSelectionServiceWidget extends StatefulWidget {
  const MobileSelectionServiceWidget({
    super.key,
    this.cursorColor = const Color(0xFF00BCF0),
    this.selectionColor = const Color.fromARGB(53, 111, 201, 231),
    this.showMagnifier = true,
    this.magnifierSize = const Size(72, 48),
    required this.child,
  });

  final Widget child;
  final Color cursorColor;
  final Color selectionColor;

  /// Show the magnifier or not.
  ///
  /// only works on iOS or Android.
  final bool showMagnifier;

  final Size magnifierSize;

  @override
  State<MobileSelectionServiceWidget> createState() =>
      _MobileSelectionServiceWidgetState();
}

class _MobileSelectionServiceWidgetState
    extends State<MobileSelectionServiceWidget>
    with WidgetsBindingObserver
    implements AppFlowySelectionService {
  @override
  final List<Rect> selectionRects = [];

  @override
  ValueNotifier<Selection?> currentSelection = ValueNotifier(null);

  @override
  List<Node> currentSelectedNodes = [];

  final List<SelectionGestureInterceptor> _interceptors = [];

  // the selection from editorState will be updated directly, but the cursor
  // or selection area depends on the layout of the text, so we need to update
  // the selection after the layout.
  final PropertyValueNotifier<Selection?> selectionNotifierAfterLayout =
      PropertyValueNotifier<Selection?>(null);

  final PanDragState _pan = PanDragState();

  late final MobileSelectionAutoScroller _autoScroller;
  late final MobileGestureStrategy _gestureStrategy;

  bool updateSelectionByTapUp = false;

  late EditorState editorState = Provider.of<EditorState>(
    context,
    listen: false,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _autoScroller = MobileSelectionAutoScroller(
      pan: _pan,
      editorState: editorState,
      isMounted: () => mounted,
      getNodeInOffset: getNodeInOffset,
      commitSelection: updateSelection,
    );
    _gestureStrategy = PlatformExtension.isIOS
        ? IOSGestureStrategy(
            pan: _pan,
            editorState: editorState,
            getNodeInOffset: getNodeInOffset,
            getPositionInOffset: getPositionInOffset,
            updateSelection: updateSelection,
            clearSelection: clearSelection,
            isClickOnSelectionArea: _isClickOnSelectionArea,
          )
        : AndroidGestureStrategy(
            pan: _pan,
            editorState: editorState,
            getNodeInOffset: getNodeInOffset,
            getPositionInOffset: getPositionInOffset,
            updateSelection: updateSelection,
            clearSelection: clearSelection,
          );
    editorState.selectionNotifier.addListener(_updateSelection);
    editorState.addScrollViewScrolledListener(_autoScroller.onScroll);
  }

  @override
  void dispose() {
    clearSelection();
    _pan.dispose();
    currentSelection.dispose();
    WidgetsBinding.instance.removeObserver(this);
    selectionNotifierAfterLayout.dispose();
    editorState.selectionNotifier.removeListener(_updateSelection);
    editorState.removeScrollViewScrolledListener(_autoScroller.onScroll);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,

        // magnifier for zoom in the text.
        if (widget.showMagnifier)
          MagnifierOverlay(pan: _pan, size: widget.magnifierSize),

        // the handles for expanding the selection area.
        SelectionHandleOverlay(
          handleType: HandleType.left,
          editorState: editorState,
          pan: _pan,
          selectionNotifierAfterLayout: selectionNotifierAfterLayout,
        ),
        SelectionHandleOverlay(
          handleType: HandleType.right,
          editorState: editorState,
          pan: _pan,
          selectionNotifierAfterLayout: selectionNotifierAfterLayout,
        ),
        CollapsedHandleOverlay(
          editorState: editorState,
          pan: _pan,
          selectionNotifierAfterLayout: selectionNotifierAfterLayout,
        ),
      ],
    );

    return PlatformExtension.isIOS
        ? MobileSelectionGestureDetector(
            onTapUp: _gestureStrategy.onTapUp,
            onDoubleTapUp: _gestureStrategy.onDoubleTapUp,
            onTripleTapUp: _gestureStrategy.onTripleTapUp,
            onLongPressStart: _gestureStrategy.onLongPressStart,
            onLongPressMoveUpdate: _gestureStrategy.onLongPressMoveUpdate,
            onLongPressEnd: _gestureStrategy.onLongPressEnd,
            child: stack,
          )
        : MobileSelectionGestureDetector(
            onTapUp: _gestureStrategy.onTapUp,
            onDoubleTapUp: _gestureStrategy.onDoubleTapUp,
            onTripleTapUp: _gestureStrategy.onTripleTapUp,
            onLongPressStart: _gestureStrategy.onLongPressStart,
            onLongPressMoveUpdate: _gestureStrategy.onLongPressMoveUpdate,
            onLongPressEnd: _gestureStrategy.onLongPressEnd,
            onPanUpdate: _gestureStrategy.onPanUpdate,
            onPanEnd: _gestureStrategy.onPanEnd,
            child: stack,
          );
  }

  @override
  void updateSelection(Selection? selection) {
    if (currentSelection.value == selection) {
      return;
    }

    _clearSelection();

    if (selection != null) {
      if (!selection.isCollapsed) {
        // updates selection area.
        AppFlowyEditorLog.selection.debug('update cursor area, $selection');
        _updateSelectionAreas(selection);
      }
    }

    currentSelection.value = selection;
    editorState.updateSelectionWithReason(
      selection,
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: {
        selectionDragModeKey: _pan.dragMode,
        selectionExtraInfoDoNotAttachTextService:
            _pan.dragMode == MobileSelectionDragMode.cursor,
      },
    );
  }

  @override
  void clearSelection() {
    currentSelectedNodes = [];
    currentSelection.value = null;

    _clearSelection();
  }

  @override
  void clearCursor() {
    _clearSelection();
  }

  void _clearSelection() {
    selectionRects.clear();
  }

  @override
  Node? getNodeInOffset(Offset offset) {
    final List<Node> sortedNodes = editorState.getVisibleNodes(
      context.read<EditorScrollController>(),
    );

    return editorState.getNodeInOffset(
      sortedNodes,
      offset,
      0,
      sortedNodes.length - 1,
    );
  }

  @override
  Position? getPositionInOffset(Offset offset) {
    final node = getNodeInOffset(offset);
    final selectable = node?.selectable;
    if (selectable == null) {
      clearSelection();

      return null;
    }

    return selectable.getPositionInOffset(offset);
  }

  @override
  void registerGestureInterceptor(SelectionGestureInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  @override
  void unregisterGestureInterceptor(String key) {
    _interceptors.removeWhere((element) => element.key == key);
  }

  void _updateSelection() {
    final selection = editorState.selection;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) selectionNotifierAfterLayout.value = selection;
    });

    if (currentSelection.value != selection) {
      clearSelection();

      return;
    }

    if (selection != null) {
      if (!selection.isCollapsed) {
        // updates selection area.
        AppFlowyEditorLog.selection.debug('update cursor area, $selection');
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          selectionRects.clear();
          _clearSelection();
          _updateSelectionAreas(selection);
        });
      }
    }
  }

  @override
  Selection? onPanStart(
    DragStartDetails details,
    MobileSelectionDragMode mode,
  ) {
    _pan.panStartOffset = details.globalPosition.translate(-3.0, 0);
    _pan.panStartScrollDy = editorState.service.scrollService?.dy;

    final selection = editorState.selection;
    _pan.panStartSelection = selection;

    _pan.dragMode = mode;

    return selection;
  }

  @override
  Selection? onPanUpdate(
    DragUpdateDetails details,
    MobileSelectionDragMode mode,
  ) {
    if (_pan.panStartOffset == null || _pan.panStartScrollDy == null) {
      return null;
    }

    // only support selection mode now.
    if (editorState.selection == null ||
        _pan.dragMode == MobileSelectionDragMode.none) {
      return null;
    }

    final panEndOffset = details.globalPosition;

    final dy = editorState.service.scrollService?.dy;
    final panStartOffset = dy == null
        ? _pan.panStartOffset!
        : _pan.panStartOffset!.translate(0, _pan.panStartScrollDy! - dy);
    final end = getNodeInOffset(
      panEndOffset,
    )?.selectable?.getSelectionInRange(panStartOffset, panEndOffset).end;

    Selection? newSelection;

    if (end != null) {
      if (_pan.dragMode == MobileSelectionDragMode.leftSelectionHandle) {
        newSelection = Selection(
          start: _pan.panStartSelection!.normalized.end,
          end: end,
        ).normalized;
      } else if (_pan.dragMode == MobileSelectionDragMode.rightSelectionHandle) {
        newSelection = Selection(
          start: _pan.panStartSelection!.normalized.start,
          end: end,
        ).normalized;
      } else if (_pan.dragMode == MobileSelectionDragMode.cursor) {
        newSelection = Selection.collapsed(end);
      }
      _pan.lastPanOffset.value = panEndOffset;
    }

    if (newSelection != null) {
      updateSelection(newSelection);
    }

    return newSelection;
  }

  @override
  void onPanEnd(DragEndDetails details, MobileSelectionDragMode mode) {
    _pan.clearPan();
    _pan.dragMode = MobileSelectionDragMode.none;

    editorState.updateSelectionWithReason(
      editorState.selection,
      reason: SelectionUpdateReason.uiEvent,
      extraInfo: {selectionExtraInfoDoNotAttachTextService: false},
    );
  }

  // delete this function in the future.
  void _updateSelectionAreas(Selection selection) {
    final nodes = editorState.getNodesInSelection(selection);

    currentSelectedNodes = nodes;

    final backwardNodes = selection.isBackward
        ? nodes
        : nodes.reversed.toList(growable: false);
    final normalizedSelection = selection.normalized;
    assert(normalizedSelection.isBackward);

    AppFlowyEditorLog.selection.debug(
      'update selection areas, $normalizedSelection',
    );

    for (var i = 0; i < backwardNodes.length; i++) {
      final node = backwardNodes[i];

      final selectable = node.selectable;
      if (selectable == null) {
        continue;
      }

      var newSelection = normalizedSelection.copyWith();

      /// In the case of multiple selections,
      ///  we need to return a new selection for each selected node individually.
      ///
      /// < > means selected.
      /// text: abcd<ef
      /// text: ghijkl
      /// text: mn>opqr
      ///
      if (!normalizedSelection.isSingle) {
        if (i == 0) {
          newSelection = newSelection.copyWith(end: selectable.end());
        } else if (i == nodes.length - 1) {
          newSelection = newSelection.copyWith(start: selectable.start());
        } else {
          newSelection = Selection(
            start: selectable.start(),
            end: selectable.end(),
          );
        }
      }

      final rects = selectable.getRectsInSelection(
        newSelection,
        shiftWithBaseOffset: true,
      );
      for (final rect in rects) {
        final selectionRect = selectable.transformRectToGlobal(
          rect,
          shiftWithBaseOffset: true,
        );
        selectionRects.add(selectionRect);
      }
    }
  }

  bool _isClickOnSelectionArea(Offset point) {
    for (final rect in selectionRects) {
      if (rect.contains(point)) {
        return true;
      }
    }

    return false;
  }

  @override
  void removeDropTarget() {
    // Do nothing on mobile
  }

  @override
  void renderDropTargetForOffset(
    Offset offset, {
    DragAreaBuilder? builder,
    DragTargetNodeInterceptor? interceptor,
  }) {
    // Do nothing on mobile
  }

  @override
  DropTargetRenderData? getDropTargetRenderData(
    Offset offset, {
    DragTargetNodeInterceptor? interceptor,
  }) => null;
}
