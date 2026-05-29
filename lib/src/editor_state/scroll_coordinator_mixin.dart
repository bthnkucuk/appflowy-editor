part of '../editor_state.dart';

/// Scroll-side state owned by [EditorState] — auto-scroller instance,
/// scroll listener set, the auto-scroll-highlight toggle, and the
/// selection-geometry helpers (`selectionRects`, `highlightRects`) that
/// scroll code consumes to position auto-scroll targets.
///
/// Declared as a mixin with abstract dependencies (rather than an `on`
/// clause) because EditorState applies several mixins (`_EditorChromeMixin`,
/// `_HistoryMixin`, `_SelectionStyleMixin`, this one) and an `on` clause
/// referencing EditorState would tangle the mixin-application chain. The
/// abstract members below are satisfied by EditorState directly (`service`,
/// `getNodesInSelection`) or by [_SelectionStyleMixin] (`selection`,
/// `highlight`, `selectionExtraInfo`).
mixin _ScrollCoordinatorMixin {
  // ---------------------------------------------------------------------------
  // Abstract dependencies (provided by EditorState + other mixins)
  // ---------------------------------------------------------------------------

  /// Provided by [_EditorServiceMixin] — used by [renderBox] to reach
  /// the scrollable's render object.
  GlobalKey get scrollServiceKey;

  /// Provided by [_SelectionStyleMixin] — the active selection.
  Selection? get selection;

  /// Provided by [_SelectionStyleMixin] — the active highlight (search /
  /// programmatic scroll target).
  Selection? get highlight;

  /// Provided by [_SelectionStyleMixin] — the underlying notifier so
  /// auto-scroll can subscribe to highlight changes directly instead of
  /// relying on every consumer to pair `updateHighlight(s)` with an
  /// explicit scroll-trigger call.
  PropertyValueNotifier<Selection?> get highlightNotifier;

  /// Provided by [_SelectionStyleMixin] — extra info carried by the most
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

  final ValueNotifier<bool> isAutoScrollHighlightNotifier = ValueNotifier(false);

  bool get isAutoScrollHighlight => isAutoScrollHighlightNotifier.value;

  set isAutoScrollHighlight(bool value) {
    isAutoScrollHighlightNotifier.value = value;
  }

  /// Auto-scroller stored temporarily for the current scrollable.
  AutoScroller? autoScroller;
  ScrollableState? scrollableState;

  /// Set in [_disposeScrollCoordinator] so the deferred retry inside
  /// [scrollToHighlight] short-circuits if the editor disposes between
  /// scheduling and the post-frame callback firing.
  bool _scrollCoordinatorDisposed = false;

  /// Controller captured by the most recent [enableAutoScrollHighlight]
  /// call. The internal highlight listener uses this to invoke
  /// [scrollToHighlight] without the consumer having to re-thread the
  /// controller through every highlight tick.
  EditorScrollController? _autoScrollController;

  /// Tracks whether [_onHighlightChangedForAutoScroll] is currently
  /// attached to [highlightNotifier], so repeated calls to
  /// [enableAutoScrollHighlight] don't stack listeners and trigger N
  /// scrolls per highlight change.
  bool _autoScrollListenerAttached = false;

  /// Section the auto-scroll listener has most recently scrolled to.
  /// Used to coalesce per-tick highlight updates that stay inside the
  /// same section — the viewport already shows that block, so animating
  /// to `top - 300` again just stutters. Drops back to "scroll every
  /// time" when the consumer's `Document.sectionParser` isn't installed
  /// (no sections → no coalesce key → preserves the original behaviour
  /// for general highlight viewers).
  Section? _lastAutoScrolledSection;

  // ---------------------------------------------------------------------------
  // Scroll-view listener set
  // ---------------------------------------------------------------------------

  final Set<VoidCallback> _onScrollViewScrolledListeners = {};

  void addScrollViewScrolledListener(VoidCallback callback) => _onScrollViewScrolledListeners.add(callback);

  void removeScrollViewScrolledListener(VoidCallback callback) => _onScrollViewScrolledListeners.remove(callback);

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
            final info = SelectionExtraInfo.from(selectionExtraInfo?.cast<String, Object?>());
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
        final rect = selectable.getCursorRectInPosition(selection.end, shiftWithBaseOffset: true);
        if (rect != null) {
          rects.add(selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true));
        }
      }
    } else {
      for (final node in nodes) {
        final selectable = node.selectable;
        if (selectable == null) {
          continue;
        }
        final nodeRects = selectable.getRectsInSelection(selection, shiftWithBaseOffset: true);
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
        final rect = selectable.getCursorRectInPosition(selection.end, shiftWithBaseOffset: true);
        if (rect != null) {
          rects.add(selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true));
        }
      }
    } else {
      for (final node in nodes) {
        final selectable = node.selectable;
        if (selectable == null) {
          continue;
        }
        final nodeRects = selectable.getRectsInSelection(selection, shiftWithBaseOffset: true);
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
    bool alignToTop = true,
  }) {
    if (_scrollCoordinatorDisposed) return;
    _scrollToHighlight(
      editorScrollController,
      selection: selection,
      alignToTop: alignToTop,
      allowRetry: true,
    );
  }

  void _scrollToHighlight(
    EditorScrollController editorScrollController, {
    Selection? selection,
    required bool alignToTop,
    required bool allowRetry,
  }) {
    final askedSelection = selection ?? highlight;
    final highlightRects = this.highlightRects(askedSelection);

    final top = highlightRects.firstOrNull?.top;

    if (top != null) {
      debugPrint(
        '[H-DBG] _scrollToHighlight: rect-top=$top → animateScroll(${top - 300})',
      );
      editorScrollController.safeAnimateScroll(
        // 300 px headroom above the highlight so the active line sits below
        // the top edge of the viewport, not flush against it.
        offset: top - 300,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
      return;
    }
    debugPrint(
      '[H-DBG] _scrollToHighlight: no rect (off-screen) '
      '${allowRetry ? "→ jumpToIndex+retry" : "→ bail"}',
    );

    if (!allowRetry) return;
    final index = askedSelection?.start.path.firstOrNull;
    if (index != null) {
      editorScrollController.jumpToIndex(index: index, alignment: alignToTop ? 0 : 1);
    }

    // jumpToIndex schedules a relayout; postFrame fires after that layout
    // pass so highlightRects can resolve. One retry only — bail otherwise.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCoordinatorDisposed) return;
      _scrollToHighlight(
        editorScrollController,
        selection: selection,
        alignToTop: alignToTop,
        allowRetry: false,
      );
    });
  }

  /// Engage auto-scroll-to-highlight for [editorScrollController].
  ///
  /// Stores the controller, subscribes once to [highlightNotifier], then
  /// performs an immediate [scrollToHighlight] so the engagement also
  /// catches up to whatever highlight was set before the toggle flipped.
  /// Subsequent [updateHighlight] calls drive the scroll automatically.
  ///
  /// Idempotent: calling multiple times rebinds the controller (last call
  /// wins) but does not stack listeners.
  void enableAutoScrollHighlight(EditorScrollController editorScrollController) {
    _autoScrollController = editorScrollController;
    isAutoScrollHighlightNotifier.value = true;
    if (!_autoScrollListenerAttached) {
      highlightNotifier.addListener(_onHighlightChangedForAutoScroll);
      _autoScrollListenerAttached = true;
    }
    // Seed the coalesce key with the section we're about to scroll to;
    // otherwise the next per-tick highlight inside the same section
    // would fail the identity check and trigger a redundant scroll.
    _lastAutoScrolledSection = _resolveHighlightSection(highlight);
    scrollToHighlight(editorScrollController);
  }

  /// Stop auto-scrolling on highlight changes. Detaches the internal
  /// listener and forgets the controller so a later
  /// [enableAutoScrollHighlight] starts from a clean slate.
  void disableAutoScrollHighlight() {
    if (_autoScrollListenerAttached) {
      highlightNotifier.removeListener(_onHighlightChangedForAutoScroll);
      _autoScrollListenerAttached = false;
    }
    _autoScrollController = null;
    _lastAutoScrolledSection = null;
    isAutoScrollHighlightNotifier.value = false;
  }

  /// Internal: subscribed to [highlightNotifier] while auto-scroll is
  /// engaged. Coalesces per-tick highlights that stay inside the same
  /// section so word-level pipelines (a 350ms timer in a TTS viewer)
  /// don't trigger a fresh 700ms scroll animation on every word. When
  /// no section parser is installed, the section lookup returns null
  /// and we fall back to the original "scroll on every change" path.
  void _onHighlightChangedForAutoScroll() {
    if (_scrollCoordinatorDisposed) return;
    if (!isAutoScrollHighlightNotifier.value) {
      debugPrint('[H-DBG] auto-scroll: skip (toggle off)');
      return;
    }
    final controller = _autoScrollController;
    if (controller == null) {
      debugPrint('[H-DBG] auto-scroll: skip (no controller)');
      return;
    }

    final newSel = highlight;
    if (newSel == null) {
      debugPrint('[H-DBG] auto-scroll: highlight cleared, drop section key');
      _lastAutoScrolledSection = null;
      return;
    }

    final section = _resolveHighlightSection(newSel);
    if (section != null) {
      if (identical(section, _lastAutoScrolledSection)) {
        debugPrint(
          '[H-DBG] auto-scroll: SAME-SECTION coalesce (no scroll) '
          'section.text="${section.text.length > 30 ? "${section.text.substring(0, 30)}…" : section.text}"',
        );
        return;
      }
      debugPrint(
        '[H-DBG] auto-scroll: section CHANGED → scroll '
        'new.text="${section.text.length > 30 ? "${section.text.substring(0, 30)}…" : section.text}"',
      );
      _lastAutoScrolledSection = section;
    } else {
      debugPrint('[H-DBG] auto-scroll: no section parser → fallback scroll');
      _lastAutoScrolledSection = null;
    }

    scrollToHighlight(controller);
  }

  Section? _resolveHighlightSection(Selection? selection) {
    if (selection == null) return null;
    final node = getNodesInSelection(selection).lastOrNull;
    return node?.sectionForSelection(selection);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void _disposeScrollCoordinator() {
    _scrollCoordinatorDisposed = true;
    if (_autoScrollListenerAttached) {
      // Safe: EditorState.dispose() runs _disposeScrollCoordinator
      // first (selection-style mixin owns highlightNotifier and is
      // disposed last), so the notifier is still alive here.
      highlightNotifier.removeListener(_onHighlightChangedForAutoScroll);
      _autoScrollListenerAttached = false;
    }
    _autoScrollController = null;
    _lastAutoScrolledSection = null;
    isAutoScrollHighlightNotifier.dispose();
    _onScrollViewScrolledListeners.clear();
  }
}
