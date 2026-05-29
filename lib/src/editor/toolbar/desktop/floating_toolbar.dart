import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class FloatingToolbarStyle {
  const FloatingToolbarStyle({
    this.backgroundColor = Colors.black,
    this.toolbarActiveColor = Colors.lightBlue,
    this.toolbarIconColor = Colors.white,
    this.toolbarShadowColor,
    this.toolbarElevation = 0,
  });

  final Color backgroundColor;
  final Color toolbarActiveColor;
  final Color toolbarIconColor;
  final Color? toolbarShadowColor;
  final double toolbarElevation;
}

typedef FloatingToolbarBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      VoidCallback onDismiss,
      bool isMetricsChanged,
    );

/// A floating toolbar that displays at the top of the editor when the selection
///   and will be hidden when the selection is collapsed.
///
class FloatingToolbar extends StatefulWidget {
  const FloatingToolbar({
    super.key,
    required this.items,
    required this.editorState,
    required this.editorScrollController,
    required this.textDirection,
    required this.child,
    this.style = const FloatingToolbarStyle(),
    this.tooltipBuilder,
    this.floatingToolbarHeight = 32,
    this.padding,
    this.decoration,
    this.placeHolderBuilder,
    this.toolbarBuilder,
  });

  final List<ToolbarItem> items;
  final EditorState editorState;
  final EditorScrollController editorScrollController;
  final TextDirection? textDirection;
  final Widget child;
  final FloatingToolbarStyle style;
  final ToolbarTooltipBuilder? tooltipBuilder;
  final double floatingToolbarHeight;
  final EdgeInsets? padding;
  final Decoration? decoration;
  final PlaceHolderItemBuilder? placeHolderBuilder;
  final FloatingToolbarBuilder? toolbarBuilder;

  @override
  State<FloatingToolbar> createState() => _FloatingToolbarState();
}

class _FloatingToolbarState extends State<FloatingToolbar>
    with WidgetsBindingObserver {
  // OverlayPortal replaces the previous OverlayEntry. With an Entry we had
  // to insert/remove a node from the root Overlay every show/hide cycle;
  // OverlayPortal owns the child off-tree and just toggles visibility via
  // its controller. Cheaper, fewer lifecycle hooks, and the overlay's
  // position can be driven from `setState` like any other widget instead
  // of being baked into the Entry builder.
  final OverlayPortalController _portalController = OverlayPortalController();
  FloatingToolbarWidget? _toolbarWidget;

  // Position + per-show flags consumed by the overlay child builder. We
  // recompute them in [_refreshToolbar] before flipping the controller on,
  // so the next overlay build picks up the latest anchor. `left`/`right`
  // are nullable to match [calculateToolbarOffset]'s return shape and
  // [Positioned]'s parameter shape — one of the two is typically null
  // depending on which edge the toolbar anchors against.
  double _toolbarTop = 0;
  double? _toolbarLeft;
  double? _toolbarRight;
  bool _showIsMetricsChanged = false;

  EditorState get editorState => widget.editorState;

  double get floatingToolbarHeight => widget.floatingToolbarHeight;

  late Brightness brightness = Theme.of(context).brightness;

  bool hasMetricsChanged = false;
  Selection? lastSelection;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    editorState.selectionNotifier.addListener(_onSelectionChanged);
    lastSelection = editorState.selection;
    widget.editorScrollController.offsetNotifier.addListener(
      _onScrollPositionChanged,
    );
  }

  @override
  void didUpdateWidget(FloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editorState != oldWidget.editorState) {
      editorState.selectionNotifier.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    Debounce.cancel(_debounceKey);

    if (_portalController.isShowing) {
      _portalController.hide();
    }
    editorState.selectionNotifier.removeListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.removeListener(
      _onScrollPositionChanged,
    );
    WidgetsBinding.instance.removeObserver(this);

    _toolbarWidget = null;

    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();

    _clear();
    _toolbarWidget = null;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    hasMetricsChanged = true;
    _showAfterDelay(isMetricsChanged: true);
  }

  @override
  Widget build(BuildContext context) {
    // OverlayPortal owns the toolbar child off-tree and renders it into
    // the nearest [Overlay] when [_portalController.show()] is called.
    // The overlayChildBuilder reads the cached `_toolbarTop / _toolbarLeft
    // / _toolbarRight` written by [_refreshToolbar]. We rebuild the host
    // (this widget) via `setState` whenever those change, which is what
    // drives the overlay child to re-build with the new position.
    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (overlayContext) {
        final child = _buildToolbar(overlayContext);
        return widget.toolbarBuilder?.call(
              overlayContext,
              child,
              _clear,
              _showIsMetricsChanged,
            ) ??
            Positioned(
              top: max(0, _toolbarTop) - floatingToolbarHeight,
              left: _toolbarLeft,
              right: _toolbarRight,
              child: child,
            );
      },
      child: widget.child,
    );
  }

  void _onSelectionChanged() {
    final selection = editorState.selection;
    final selectionType = editorState.selectionType;

    final disableToolbar =
        editorState.selectionExtraInfo?[selectionExtraInfoDisableToolbar] ==
        true;

    if (disableToolbar) {
      _clear();
    }

    if (lastSelection == selection) return;
    lastSelection = selection;

    if (selection == null ||
        selection.isCollapsed ||
        selectionType == SelectionType.block) {
      _clear();
    } else if (!disableToolbar) {
      // uses debounce to avoid the computing the rects too frequently.
      _showAfterDelay(
        duration: const Duration(milliseconds: 200),
        isMetricsChanged: hasMetricsChanged,
      );
      if (hasMetricsChanged) hasMetricsChanged = false;
    }
  }

  void _onScrollPositionChanged() {
    // Only react to scroll when the toolbar is already showing — we
    // never auto-show from scroll. The reactions are:
    //   - selection still on-screen → recompute anchor, setState. The
    //     OverlayPortal keeps the child mounted and just moves it, so
    //     the toolbar tracks the selection smoothly (no flicker).
    //   - selection off-screen      → `_clear()` hides the portal. Once
    //     hidden, subsequent scroll ticks early-return here, so the
    //     toolbar stays gone even if the user scrolls back to bring
    //     the selection into view. Only a NEW selection brings it
    //     back, via [_onSelectionChanged].
    if (!_portalController.isShowing) return;
    _refreshToolbar(isMetricsChanged: false);
  }

  final String _debounceKey = 'show the toolbar';

  void _clear() {
    Debounce.cancel(_debounceKey);

    if (_portalController.isShowing) {
      _portalController.hide();
    }
  }

  void _showAfterDelay({
    Duration duration = Duration.zero,
    bool isMetricsChanged = false,
  }) {
    // [_refreshToolbar] handles both the "validate + show" and the
    // "validate + hide" paths internally, so we no longer need a
    // pre-call `_clear()` here.
    Debounce.debounce(_debounceKey, duration, () {
      _refreshToolbar(isMetricsChanged: isMetricsChanged);
    });
  }

  /// Single-entry "compute anchor + decide show/hide" path. Called by:
  ///
  ///   - [_showAfterDelay]'s debounced callback (selection change /
  ///     metrics change — the original show path).
  ///   - [_onScrollPositionChanged] (scroll tick — track or hide).
  ///
  /// Every early-return route calls [_clear] explicitly, so the toolbar
  /// disappears whenever the selection becomes invalid / unreadable /
  /// off-screen, regardless of which caller drove this tick.
  void _refreshToolbar({required bool isMetricsChanged}) {
    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) {
      _clear();
      return;
    }

    if (editorState.selectionExtraInfo?[selectionExtraInfoDisableToolbar] ==
        true) {
      _clear();
      return;
    }

    if (!editorState.editable) {
      _clear();
      return;
    }

    // check the content is visible
    final nodes = editorState.getSelectedNodes();
    if (nodes.isEmpty ||
        nodes.every((node) {
          final delta = node.delta;

          return delta == null || delta.isEmpty;
        })) {
      _clear();
      return;
    }

    final rects = editorState.selectionRects();
    if (rects.isEmpty) {
      _clear();
      return;
    }

    final rect = _findSuitableRect(rects);
    // [_findSuitableRect] returns [Rect.zero] when every selection
    // rect sits above the editor's render origin — i.e. the user has
    // scrolled the selection completely past the AppBar / top edge.
    // Hide unconditionally; without this the default-Positioned path
    // (no custom `toolbarBuilder`) would plant the toolbar at
    // `top: 0, left: 0` because `calculateToolbarOffset(Rect.zero)`
    // returns the trivially-small offsets — visible as the toolbar
    // sticking to the top-left corner during scroll.
    if (rect == Rect.zero) {
      _clear();
      return;
    }
    final (left, top, right) = calculateToolbarOffset(rect);
    // Legacy off-screen guard, retained for consumers that DO pass a
    // custom `toolbarBuilder` and may rely on this exact branch shape.
    if ((top <= floatingToolbarHeight || (left == 0 && right == 0)) &&
        widget.toolbarBuilder != null) {
      _clear();
      return;
    }
    // Stash the freshly-computed position so the [OverlayPortal]'s
    // overlayChildBuilder picks it up on the next build. setState
    // triggers the host rebuild → portal rebuilds child → toolbar
    // moves. Then flip the controller on if not already showing.
    setState(() {
      _toolbarTop = top;
      _toolbarLeft = left;
      _toolbarRight = right;
      _showIsMetricsChanged = isMetricsChanged;
    });
    if (!_portalController.isShowing) {
      _portalController.show();
    }
  }

  Widget _buildToolbar(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    bool needRefreshToolbar = brightness != this.brightness;
    if (needRefreshToolbar) {
      this.brightness = brightness;
    }
    if (needRefreshToolbar || _toolbarWidget == null) {
      _toolbarWidget = FloatingToolbarWidget(
        items: widget.items,
        editorState: editorState,
        backgroundColor: widget.style.backgroundColor,
        toolbarActiveColor: widget.style.toolbarActiveColor,
        toolbarIconColor: widget.style.toolbarIconColor,
        toolbarElevation: widget.style.toolbarElevation,
        toolbarShadowColor: widget.style.toolbarShadowColor,
        textDirection: widget.textDirection ?? Directionality.of(context),
        tooltipBuilder: widget.tooltipBuilder,
        floatingToolbarHeight: floatingToolbarHeight,
        padding: widget.padding,
        decoration: widget.decoration,
        placeHolderBuilder: widget.placeHolderBuilder,
      );
    }

    return _toolbarWidget!;
  }

  Rect _findSuitableRect(Iterable<Rect> rects) {
    assert(rects.isNotEmpty);

    final editorOffset =
        editorState.renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    // find the min offset with non-negative dy.
    final rectsWithNonNegativeDy = rects.where(
      (element) => element.top >= editorOffset.dy,
    );
    if (rectsWithNonNegativeDy.isEmpty) {
      // if all the rects offset is negative, then the selection is not visible.
      return Rect.zero;
    }

    final minRect = rectsWithNonNegativeDy.reduce((min, current) {
      if (min.top < current.top) {
        return min;
      } else if (min.top == current.top) {
        return min.top < current.top ? min : current;
      } else {
        return current;
      }
    });

    return minRect;
  }

  (double? left, double top, double? right) calculateToolbarOffset(Rect rect) {
    final editorOffset =
        editorState.renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final editorSize = editorState.renderBox?.size ?? Size.zero;
    final editorRect = editorOffset & editorSize;
    final left = (rect.left - editorOffset.dx).abs();
    final right = (rect.right - editorOffset.dx).abs();
    final width = editorSize.width;
    final threshold = width / 3.0;
    final top = rect.top < floatingToolbarHeight
        ? rect.bottom + floatingToolbarHeight
        : rect.top;
    if (left <= threshold) {
      // show in left
      return (rect.left, top, null);
    } else if (left >= threshold && right <= threshold * 2.0) {
      // show in center
      return (editorRect.left + threshold, top, null);
    } else {
      // show in right
      return (null, top, editorRect.right - rect.right);
    }
  }
}
