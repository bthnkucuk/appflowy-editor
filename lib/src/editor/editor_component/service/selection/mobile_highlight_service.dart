import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'shared.dart';
import '../../../util/platform_extension.dart';
import '../../../../service/selection/mobile_selection_gesture.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MobileHighlightServiceWidget extends StatefulWidget {
  const MobileHighlightServiceWidget({
    super.key,
    this.highlightColor = const Color.fromARGB(53, 111, 201, 231),
    required this.child,
  });

  final Widget child;
  final Color highlightColor;

  @override
  State<MobileHighlightServiceWidget> createState() =>
      _MobileHighlightServiceWidgetState();
}

class _MobileHighlightServiceWidgetState
    extends State<MobileHighlightServiceWidget>
    with WidgetsBindingObserver
    implements AppFlowySelectionService {
  //*
  @override
  final List<Rect> selectionRects = [];

  @override
  ValueNotifier<Selection?> currentSelection = ValueNotifier(null);

  @override
  List<Node> currentSelectedNodes = [];

  final List<SelectionGestureInterceptor> _interceptors = [];
  final ValueNotifier<Offset?> _lastPanOffset = ValueNotifier(null);

  // the selection from editorState will be updated directly, but the cursor
  // or selection area depends on the layout of the text, so we need to update
  // the selection after the layout.
  final PropertyValueNotifier<Selection?> selectionNotifierAfterLayout =
      PropertyValueNotifier<Selection?>(null);

  /// Pan
  Offset? _panStartOffset;
  double? _panStartScrollDy;
  Selection? _panStartSelection;

  MobileSelectionDragMode dragMode = MobileSelectionDragMode.none;

  bool updateSelectionByTapUp = false;

  /// Memoised last-seen value of `editorState.selection`. `_updateSelection`
  /// is attached to `highlightNotifier`, so it fires on every highlight
  /// tick — but the body reads the editor's *selection* and only does
  /// real work when the selection actually changed. When the listener
  /// is woken up by a pure highlight change, the cached value still
  /// matches the live selection and we early-return without rescheduling
  /// the post-frame `selectionNotifierAfterLayout` write that would
  /// otherwise drive a cascade of dead rebuilds.
  Selection? _lastObservedSelection;

  late EditorState editorState = Provider.of<EditorState>(
    context,
    listen: false,
  );

  bool isCollapsedHandleVisible = false;

  Timer? collapsedHandleTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    editorState.highlightNotifier.addListener(_updateSelection);
  }

  @override
  void dispose() {
    clearSelection();
    WidgetsBinding.instance.removeObserver(this);
    selectionNotifierAfterLayout.dispose();
    editorState.highlightNotifier.removeListener(_updateSelection);
    collapsedHandleTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[H-DBG] MobileHighlightServiceWidget BUILD');
    final stack = widget.child;
    return PlatformExtension.isIOS
        ? MobileSelectionGestureDetector(
            onTapUp: _onDoubleTapUp,
            // onDoubleTapUp: _onDoubleTapUp,
            // onTripleTapUp: _onTripleTapUp,
            // onLongPressStart: _onLongPressStartIOS,
            // onLongPressMoveUpdate: _onLongPressUpdateIOS,
            // onLongPressEnd: _onLongPressEndIOS,
            child: stack,
          )
        : MobileSelectionGestureDetector(
            onTapUp: _onDoubleTapUp,
            // onDoubleTapUp: _onDoubleTapUp,
            // onTripleTapUp: _onTripleTapUp,
            // onLongPressStart: _onLongPressStartAndroid,
            // onLongPressMoveUpdate: _onLongPressUpdateAndroid,
            // onLongPressEnd: _onLongPressEndAndroid,
            // onPanUpdate: _onPanUpdateAndroid,
            // onPanEnd: _onPanEndAndroid,
            child: stack,
          );
  }

  @override
  void updateSelection(Selection? selection) {
    _applySelection(selection, isTap: false);
  }

  /// Internal: routes both pan-drag and tap-up through one path so the
  /// `currentSelection` / highlight bookkeeping stays in sync.
  ///
  /// [isTap] is true only from the deliberate tap-up handler. When set,
  /// the tap-up selection is published on `editorState.tapEvents` —
  /// a broadcast stream that consumers (TTS read-along, audio-seek
  /// players, etc.) subscribe to. Crucially we do NOT write the
  /// editor's `selection` here: in `highlightable: true` +
  /// `editable: false` viewers writing the selection would make
  /// `BlockSelectionArea` paint a gray rect that nothing clears. The
  /// highlight underlay is already updated via `updateHighlight` a few
  /// lines up. Pan updates do not publish on the stream — the
  /// pre-refactor code fired tap on every pan tick, which was a wart.
  void _applySelection(Selection? selection, {required bool isTap}) {
    debugPrint(
      '[H-DBG] mobile._applySelection isTap=$isTap selection=$selection '
      '(current=${currentSelection.value})',
    );
    if (currentSelection.value == selection) {
      debugPrint('[H-DBG]   → skipped (same as current)');
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
    debugPrint('[H-DBG]   → updateHighlight($selection)');
    editorState.updateHighlight(selection);
    if (isTap && selection != null) {
      debugPrint('[H-DBG]   → notifyTap($selection)');
      editorState.notifyTap(selection);
    }
  }

  @override
  void clearSelection() {
    currentSelectedNodes = [];
    currentSelection.value = null;

    _clearSelection();
  }

  void _clearPanVariables() {
    _panStartOffset = null;
    _panStartSelection = null;
    _panStartScrollDy = null;
    _lastPanOffset.value = null;
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
    // Fix A: this listener is attached to `highlightNotifier`, so it
    // fires on every highlight tick — but the body only cares about
    // changes to the editor's *selection*. When a highlight-only tick
    // wakes us up, the cached value still matches and we bail before
    // scheduling the post-frame work that drives
    // `selectionNotifierAfterLayout`'s `PropertyValueNotifier` notify
    // cascade.
    if (selection == _lastObservedSelection) {
      debugPrint(
        '[H-DBG] mobile._updateSelection skipped (selection unchanged: $selection)',
      );
      return;
    }
    _lastObservedSelection = selection;
    debugPrint(
      '[H-DBG] mobile._updateSelection (highlightNotifier fired) '
      'editorState.selection=$selection currentSelection=${currentSelection.value}',
    );

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) selectionNotifierAfterLayout.value = selection;
    });

    if (currentSelection.value != selection) {
      debugPrint('[H-DBG]   → clearSelection (current != editorState.selection)');
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
    _panStartOffset = details.globalPosition.translate(-3.0, 0);
    _panStartScrollDy = editorState.scrollService?.dy;

    final selection = editorState.selection;
    _panStartSelection = selection;

    dragMode = mode;

    return selection;
  }

  @override
  Selection? onPanUpdate(
    DragUpdateDetails details,
    MobileSelectionDragMode mode,
  ) {
    if (_panStartOffset == null || _panStartScrollDy == null) {
      return null;
    }

    // only support selection mode now.
    if (editorState.selection == null ||
        dragMode == MobileSelectionDragMode.none) {
      return null;
    }

    final panEndOffset = details.globalPosition;

    final dy = editorState.scrollService?.dy;
    final panStartOffset = dy == null
        ? _panStartOffset!
        : _panStartOffset!.translate(0, _panStartScrollDy! - dy);
    final end = getNodeInOffset(
      panEndOffset,
    )?.selectable?.getSelectionInRange(panStartOffset, panEndOffset).end;

    Selection? newSelection;

    if (end != null) {
      if (dragMode == MobileSelectionDragMode.leftSelectionHandle) {
        newSelection = Selection(
          start: _panStartSelection!.normalized.end,
          end: end,
        ).normalized;
      } else if (dragMode == MobileSelectionDragMode.rightSelectionHandle) {
        newSelection = Selection(
          start: _panStartSelection!.normalized.start,
          end: end,
        ).normalized;
      } else if (dragMode == MobileSelectionDragMode.cursor) {
        newSelection = Selection.collapsed(end);
      }
      _lastPanOffset.value = panEndOffset;
    }

    if (newSelection != null) {
      updateSelection(newSelection);
    }

    return newSelection;
  }

  @override
  void onPanEnd(DragEndDetails details, MobileSelectionDragMode mode) {
    _clearPanVariables();
    dragMode = MobileSelectionDragMode.none;

    editorState.updateHighlight(editorState.selection);
  }

  void _onDoubleTapUp(TapUpDetails details) {
    final offset = details.globalPosition;
    final node = getNodeInOffset(offset);

    // final x = node?.selectable?.getWordEdgeInOffset(offset);
    // select word boundary closest to offset
    final selection = node?.selectable?.getWordBoundaryInOffset(offset);
    debugPrint(
      '[H-DBG] mobile.onTapUp @ $offset → node=${node?.path} '
      'wordBoundary=$selection',
    );
    if (selection == null) {
      clearSelection();
      return;
    }
    // Route the tap through the tap-event publishing path; pan
    // updates intentionally use the non-tap path (no stream emission).
    _applySelection(selection, isTap: true);
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
