part of '../editor_state.dart';

/// Scroll-side state owned by [EditorState] — auto-scroller instance,
/// scroll listener set, the auto-scroll-highlight toggle, and the
/// selection-geometry helpers (`selectionRects`, `highlightRects`) that
/// scroll code consumes to position auto-scroll targets.
///
/// Declared as a mixin with abstract dependencies (rather than an `on`
/// clause) because EditorState applies several mixins (`EditorChromeMixin`,
/// `HistoryMixin`, `SelectionStyleMixin`, this one) and an `on` clause
/// referencing EditorState would tangle the mixin-application chain. The
/// abstract members below are satisfied by EditorState directly (`service`,
/// `getNodesInSelection`) or by [SelectionStyleMixin] (`selection`,
/// `highlight`, `selectionExtraInfo`).
mixin ScrollCoordinatorMixin {
  // ---------------------------------------------------------------------------
  // Abstract dependencies (provided by EditorState + other mixins)
  // ---------------------------------------------------------------------------

  /// Provided by [EditorServiceMixin] — used by [renderBox] to reach
  /// the scrollable's render object.
  GlobalKey get scrollServiceKey;

  /// Provided by [SelectionStyleMixin] — the active selection.
  Selection? get selection;

  /// Provided by [SelectionStyleMixin] — the active highlight (search /
  /// programmatic scroll target).
  Selection? get highlight;

  /// Provided by [SelectionStyleMixin] — extra info carried by the most
  /// recent selection update. Read for drag-mode detection during
  /// auto-scroll.
  Map? get selectionExtraInfo;

  /// Provided by EditorState — document query used by
  /// [selectionRects] / [highlightRects].
  List<Node> getNodesInSelection(Selection selection);

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Whether the editor should disable auto scroll.
  bool disableAutoScroll = false;

  /// The edge offset of the auto scroll.
  double autoScrollEdgeOffset = appFlowyEditorAutoScrollEdgeOffset;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final ValueNotifier<bool> isAutoScrollHighlightNotifier = ValueNotifier(
    false,
  );

  bool get isAutoScrollHighlight => isAutoScrollHighlightNotifier.value;

  set isAutoScrollHighlight(bool value) {
    isAutoScrollHighlightNotifier.value = value;
  }

  /// Auto-scroller stored temporarily for the current scrollable.
  AutoScroller? autoScroller;
  ScrollableState? scrollableState;

  // ---------------------------------------------------------------------------
  // Scroll-view listener set
  // ---------------------------------------------------------------------------

  final Set<VoidCallback> _onScrollViewScrolledListeners = {};

  void addScrollViewScrolledListener(VoidCallback callback) =>
      _onScrollViewScrolledListeners.add(callback);

  void removeScrollViewScrolledListener(VoidCallback callback) =>
      _onScrollViewScrolledListeners.remove(callback);

  void _notifyScrollViewScrolledListeners() {
    for (final listener in Set.of(_onScrollViewScrolledListeners)) {
      listener.call();
    }
  }

  // ---------------------------------------------------------------------------
  // Render box accessor
  // ---------------------------------------------------------------------------

  /// Render box of the scrollable that hosts the editor. Used by
  /// floating toolbars, overlays, and selection-handle positioning.
  RenderBox? get renderBox {
    final renderObject = scrollServiceKey.currentContext?.findRenderObject();
    if (renderObject != null && renderObject is RenderBox) {
      return renderObject;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Auto-scroller construction
  // ---------------------------------------------------------------------------

  void updateAutoScroller(ScrollableState scrollableState) {
    if (this.scrollableState != scrollableState) {
      autoScroller?.stopAutoScroll();
      final bool isDesktopOrWeb = PlatformExtension.isDesktopOrWeb;
      late AutoScroller scroller;
      scroller = AutoScroller(
        scrollableState,
        // Framework EdgeDraggingAutoScroller: per-tick duration is
        // `1000 / velocityScalar` ms, delta per tick is the raw over-drag
        // (capped to 20 px). 50 ≈ 20ms tick → ~1000 px/s top speed when the
        // cursor sits hard against the edge. The old fork value 0.15 (with
        // an 80ms desktop tick) worked out to ~40 px/s, which felt unusably
        // slow on long documents.
        velocityScalar: 50,
        onScrollViewScrolled: () {
          _notifyScrollViewScrolledListeners();
          if (!isDesktopOrWeb) {
            // The field is the untyped `Map?` we publish to the rest of
            // the editor; cast at the boundary so the typed accessor can
            // do its work.
            final info = SelectionExtraInfo.from(
              selectionExtraInfo?.cast<String, Object?>(),
            );
            if (!info.isDraggingSelection) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (autoScroller == scroller) {
                scroller.continueToAutoScroll();
              }
            });
          }
        },
      );
      autoScroller = scroller;
      this.scrollableState = scrollableState;
    }
  }

  // ---------------------------------------------------------------------------
  // Selection geometry — used by scroll-to-highlight and by external
  // consumers (desktop_selection_service, floating_toolbar, color_menu,
  // overlay_util, position_extension, scroll_service_widget).
  // ---------------------------------------------------------------------------

  /// The current selection areas's rect in editor.
  List<Rect> selectionRects() {
    final selection = this.selection;
    if (selection == null) {
      return [];
    }

    final nodes = getNodesInSelection(selection);
    final rects = <Rect>[];

    if (selection.isCollapsed && nodes.length == 1) {
      final selectable = nodes.first.selectable;
      if (selectable != null) {
        final rect = selectable.getCursorRectInPosition(
          selection.end,
          shiftWithBaseOffset: true,
        );
        if (rect != null) {
          rects.add(
            selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true),
          );
        }
      }
    } else {
      for (final node in nodes) {
        final selectable = node.selectable;
        if (selectable == null) {
          continue;
        }
        final nodeRects = selectable.getRectsInSelection(
          selection,
          shiftWithBaseOffset: true,
        );
        if (nodeRects.isEmpty) {
          continue;
        }
        final renderBox = node.renderBox;
        if (renderBox == null) {
          continue;
        }
        for (final rect in nodeRects) {
          final globalOffset = renderBox.localToGlobal(rect.topLeft);
          rects.add(globalOffset & rect.size);
        }
      }
    }

    return rects;
  }

  List<Rect> highlightRects(Selection? selection) {
    if (selection == null) {
      return [];
    }

    final nodes = getNodesInSelection(selection);
    final rects = <Rect>[];

    if (selection.isCollapsed && nodes.length == 1) {
      final selectable = nodes.first.selectable;
      if (selectable != null) {
        final rect = selectable.getCursorRectInPosition(
          selection.end,
          shiftWithBaseOffset: true,
        );
        if (rect != null) {
          rects.add(
            selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true),
          );
        }
      }
    } else {
      for (final node in nodes) {
        final selectable = node.selectable;
        if (selectable == null) {
          continue;
        }
        final nodeRects = selectable.getRectsInSelection(
          selection,
          shiftWithBaseOffset: true,
        );
        if (nodeRects.isEmpty) {
          continue;
        }
        final renderBox = node.renderBox;
        if (renderBox == null) {
          continue;
        }
        for (final rect in nodeRects) {
          final globalOffset = renderBox.localToGlobal(rect.topLeft);
          rects.add(globalOffset & rect.size);
        }
      }
    }

    return rects;
  }

  // ---------------------------------------------------------------------------
  // Scroll-to-highlight helpers
  // ---------------------------------------------------------------------------

  void scrollToHighlight(
    EditorScrollController editorScrollController, {
    Selection? selection,
    bool fromInside = false,
    bool alignToTop = true,
  }) {
    final askedSelection = selection ?? highlight;
    final highlightRects = this.highlightRects(askedSelection);

    final top = highlightRects.firstOrNull?.top;

    if (top != null) {
      editorScrollController.safeAnimateScroll(
        offset: top - 300,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    } else {
      if (fromInside) return;
      final index = askedSelection?.start.path.firstOrNull;
      if (index != null) {
        editorScrollController.jumpToIndex(
          index: index,
          alignment: alignToTop ? 0 : 1,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        Future.delayed(Duration(milliseconds: 0), () {
          scrollToHighlight(
            editorScrollController,
            selection: selection,
            fromInside: true,
          );
        });
      });
    }
  }

  void enableAutoScrollHighlight(
    EditorScrollController editorScrollController,
  ) {
    isAutoScrollHighlightNotifier.value = true;
    highlightChanged(editorScrollController);
  }

  void disableAutoScrollHighlight() {
    isAutoScrollHighlightNotifier.value = false;
  }

  void highlightChanged(EditorScrollController editorScrollController) {
    if (isAutoScrollHighlightNotifier.value) {
      scrollToHighlight(editorScrollController);
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void _disposeScrollCoordinator() {
    isAutoScrollHighlightNotifier.dispose();
    _onScrollViewScrolledListeners.clear();
  }
}
