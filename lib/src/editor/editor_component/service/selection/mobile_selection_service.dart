import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'mobile/mobile_gesture_strategy.dart';
import 'mobile/mobile_gesture_strategy_android.dart';
import 'mobile/mobile_gesture_strategy_ios.dart';
import 'mobile/mobile_selection_auto_scroller.dart';
import 'mobile/mobile_selection_overlays.dart';
import 'mobile/pan_drag_state.dart';
import 'shared.dart';
import '../../../util/platform_extension.dart';
import '../../../../render/selection/mobile_basic_handle.dart';
import '../../../../service/selection/mobile_selection_gesture.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// only used in mobile
///
/// this will notify the developers when the selection is not collapsed.
StreamController<int> appFlowyEditorOnTapSelectionArea =
    StreamController<int>.broadcast();

// MobileSelectionDragMode and selectionDragModeKey moved to
// lib/src/editor_state/selection_drag_mode.dart so the editor_state
// layer can compare against them directly. Re-exported via the barrel.
bool disableIOSSelectWordEdgeOnTap = false;

/// Mobil long-press / cursor drag sırasında gösterilen magnifier'ı
/// kapatır. Varsayılan `true` — magnifier görsel gürültü yarattığı için
/// ve ileride node-level drag handle gesture'larına yer açmak için
/// kapalı geliyor. Tüketici uygulama `disableMagnifier = false` diyerek
/// açık geri alabilir.
bool disableMagnifier = true;

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

    // iOS leaves onPanUpdate/onPanEnd null so the PanGestureRecognizer
    // (always installed by MobileSelectionGestureDetector) receives no
    // callbacks — matches the pre-refactor behavior, which omitted these
    // arguments entirely on iOS.
    final isIOS = PlatformExtension.isIOS;
    return MobileSelectionGestureDetector(
      onTapUp: _gestureStrategy.onTapUp,
      onDoubleTapUp: _gestureStrategy.onDoubleTapUp,
      onTripleTapUp: _gestureStrategy.onTripleTapUp,
      onLongPressStart: _gestureStrategy.onLongPressStart,
      onLongPressMoveUpdate: _gestureStrategy.onLongPressMoveUpdate,
      onLongPressEnd: _gestureStrategy.onLongPressEnd,
      onPanUpdate: isIOS ? null : _gestureStrategy.onPanUpdate,
      onPanEnd: isIOS ? null : _gestureStrategy.onPanEnd,
      child: stack,
    );
  }

  @override
  void updateSelection(Selection? selection) {
    if (currentSelection.value == selection) {
      return;
    }

    selectionRects.clear();

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

    selectionRects.clear();
  }

  @override
  void clearCursor() {
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
    _pan.panStartScrollDy = editorState.scrollService?.dy;

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

    final dy = editorState.scrollService?.dy;
    final panStartOffset = dy == null
        ? _pan.panStartOffset!
        : _pan.panStartOffset!.translate(0, _pan.panStartScrollDy! - dy);
    final end = getNodeInOffset(
      panEndOffset,
    )?.selectable?.getSelectionInRange(panStartOffset, panEndOffset).end;

    final lastPanOffsetBefore = _pan.lastPanOffset.value;
    final dyDelta = lastPanOffsetBefore == null
        ? 0.0
        : panEndOffset.dy - lastPanOffsetBefore.dy;
    // "Reversal" is mode-specific: rightHandle's natural direction is DOWN,
    // so going UP is a reverse; leftHandle's natural direction is UP, so
    // going DOWN is a reverse. >1px threshold filters touch noise.
    final reversedForHandle =
        lastPanOffsetBefore != null &&
        switch (_pan.dragMode) {
          MobileSelectionDragMode.rightSelectionHandle => dyDelta < -1.0,
          MobileSelectionDragMode.leftSelectionHandle => dyDelta > 1.0,
          _ => false,
        };
    debugPrint(
      '[SELECTION_FIX] PAN.update '
      '${reversedForHandle ? '*** REVERSED *** ' : ''}'
      'mode=$mode '
      'panEndOffset=$panEndOffset '
      'dyDelta=${dyDelta.toStringAsFixed(1)} '
      'end=${end == null ? 'null' : end.toString()} '
      'lastPanOffset.before=$lastPanOffsetBefore',
    );

    // Spurious-reversal-extension guard. When the user reverses finger
    // direction while autoscroll is active, the viewport keeps scrolling
    // and `getNodeInOffset(finger_below_viewport)` keeps resolving to a
    // newly-revealed "deepest visible" node — so the resolved `end`
    // drifts FURTHER away from the original selection anchor even as the
    // finger moves BACK toward it. Selection chases the new deep node,
    // selection-rect-driven autoscroll re-fires on the resulting
    // `_onSelectionChanged`, viewport scrolls more, loop continues. Log
    // signature: dyDelta < 0 (going up) but end.path > current end.path.
    //
    // Fix: when the finger has reversed AND the resolved end is spurious
    // (further from anchor instead of closer), drop this tick and stop
    // the framework autoscroll loop. Selection freezes at last-known-good
    // until finger crosses back into viewport, at which point
    // `getNodeInOffset(finger_in_viewport)` resolves to a node closer to
    // the anchor → spurious check fails → normal path resumes →
    // selection follows finger. Mirror logic for leftSelectionHandle.
    final currentSelection = editorState.selection?.normalized;
    if (reversedForHandle && end != null && currentSelection != null) {
      final isRight =
          _pan.dragMode == MobileSelectionDragMode.rightSelectionHandle;
      final isLeft =
          _pan.dragMode == MobileSelectionDragMode.leftSelectionHandle;
      final spurious =
          (isRight && end.path > currentSelection.end.path) ||
          (isLeft && end.path < currentSelection.start.path);
      if (spurious) {
        editorState.autoScroller?.stopAutoScroll();
        _pan.lastPanOffset.value = panEndOffset;
        debugPrint(
          '[SELECTION_FIX] PAN.update reversal-suppress: '
          'end.path=${end.path} drifting away from anchor '
          '(currentSel=${currentSelection.start.path}..${currentSelection.end.path}) '
          '— frozen + stopAutoScroll',
        );
        return editorState.selection;
      }
    }

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

    debugPrint(
      '[SELECTION_FIX] PAN.update '
      '  → newSelection=${newSelection?.toString() ?? 'null'} '
      'lastPanOffset.after=${_pan.lastPanOffset.value}',
    );

    if (newSelection != null) {
      updateSelection(newSelection);
    }

    return newSelection;
  }

  @override
  void onPanEnd(DragEndDetails details, MobileSelectionDragMode mode) {
    debugPrint(
      '[SELECTION_FIX] PAN.end '
      'mode=$mode '
      'velocity=${details.velocity.pixelsPerSecond}',
    );
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
