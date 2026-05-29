import 'package:appflowy_editor/appflowy_editor.dart';
import 'scroll/desktop_scroll_service.dart';
import 'scroll/mobile_scroll_service.dart';
import '../../util/platform_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScrollServiceWidget extends StatefulWidget {
  const ScrollServiceWidget({super.key, required this.editorScrollController, required this.child});

  final EditorScrollController editorScrollController;

  final Widget child;

  @override
  State<ScrollServiceWidget> createState() => _ScrollServiceWidgetState();
}

class _ScrollServiceWidgetState extends State<ScrollServiceWidget> implements AppFlowyScrollService {
  final _forwardKey = GlobalKey(debugLabel: 'forward_to_platform_scroll_service');
  late AppFlowyScrollService forward = _forwardKey.currentState as AppFlowyScrollService;

  late EditorState editorState = context.read<EditorState>();

  @override
  late ScrollController scrollController = ScrollController();

  Selection? lastSelection;

  @override
  void initState() {
    super.initState();
    editorState.selectionNotifier.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    scrollController.dispose();
    editorState.selectionNotifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[H-DBG] ScrollServiceWidget BUILD');
    return Provider.value(
      value: widget.editorScrollController,
      child: Builder(
        builder: (context) {
          if (PlatformExtension.isDesktopOrWeb) {
            return _buildDesktopScrollService(context);
          } else if (PlatformExtension.isMobile) {
            return _buildMobileScrollService(context);
          }
          throw UnimplementedError();
        },
      ),
    );
  }

  Widget _buildDesktopScrollService(BuildContext context) {
    return DesktopScrollService(key: _forwardKey, child: widget.child);
  }

  Widget _buildMobileScrollService(BuildContext context) {
    return MobileScrollService(key: _forwardKey, child: widget.child);
  }

  // Soft-keyboard inset read that's safe to call from listener callbacks
  // and post-frame callbacks where the element may already be deactivated.
  // Replaces the former `KeyboardHeightObserver.currentKeyboardHeight` lookup,
  // which was just a snapshot of the same `viewInsets.bottom` value the
  // platform reports natively.
  double get _currentKeyboardInset => WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;

  void _onSelectionChanged() {
    // should auto scroll after the cursor or selection updated.
    final selection = editorState.selection;

    debugPrint(
      '[SELECTION_FIX] _onSelectionChanged '
      'selection=$selection '
      'reason=${editorState.selectionUpdateReason} '
      'extraInfo=${editorState.selectionExtraInfo} '
      'kbHeight=$_currentKeyboardInset',
    );
    if (selection == null || [SelectionUpdateReason.selectAll].contains(editorState.selectionUpdateReason)) {
      debugPrint('[SELECTION_FIX]   → skipped (null or selectAll)');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectionRects = editorState.selectionRects();
      if (selectionRects.isEmpty) {
        debugPrint('[SELECTION_FIX]   → skipped (empty rects in postFrame)');
        return;
      }

      Rect targetRect;
      AxisDirection? direction;
      final dragMode = SelectionExtraInfo.from(editorState.selectionExtraInfo?.cast<String, Object?>()).dragMode;

      // For desktop: if auto-scroller is already scrolling (from drag-to-select),
      // don't override it here. The desktop_selection_service handles drag scrolling.
      if (PlatformExtension.isDesktopOrWeb && (editorState.autoScroller?.scrolling ?? false)) {
        return;
      }

      switch (dragMode) {
        case MobileSelectionDragMode.leftSelectionHandle:
          targetRect = selectionRects.first;
          // Direction defaults to UP (the "natural" direction for a
          // left-handle drag — user pulling the start of the selection
          // earlier). But once we have a previous selection to compare
          // against, derive direction from how `selection.start`
          // actually moved this tick: if start moved DEEPER in the
          // document, the user is dragging the left handle DOWN (e.g.
          // shrinking the selection from the left), and autoscroll
          // should follow the handle's motion downward when it nears
          // the bottom edge. Mirrors cursor-mode logic below and the
          // symmetric rightSelectionHandle case.
          direction = AxisDirection.up;
          if (lastSelection != null) {
            final isMovingDown =
                selection.start.path > lastSelection!.start.path ||
                (selection.start.path.equals(lastSelection!.start.path) &&
                    selection.start.offset > lastSelection!.start.offset);
            direction = isMovingDown ? AxisDirection.down : AxisDirection.up;
          }
          break;

        case MobileSelectionDragMode.rightSelectionHandle:
          targetRect = selectionRects.last;
          // Direction defaults to DOWN (the natural direction for a
          // right-handle drag — user pulling the end of the selection
          // later). But once we have a previous selection, derive
          // direction from how `selection.end` actually moved: if end
          // moved SHALLOWER, the user is reversing — dragging the right
          // handle UP to shrink the selection from the right — and
          // autoscroll should fire UP when the handle approaches the
          // top edge so the user can keep dragging past the viewport
          // boundary. Without this, the right handle hits the AppBar
          // and selection can never be fully collapsed by drag alone.
          direction = AxisDirection.down;
          if (lastSelection != null) {
            final isMovingUp =
                selection.end.path < lastSelection!.end.path ||
                (selection.end.path.equals(lastSelection!.end.path) &&
                    selection.end.offset < lastSelection!.end.offset);
            direction = isMovingUp ? AxisDirection.up : AxisDirection.down;
          }
          break;

        case MobileSelectionDragMode.cursor:
          targetRect = selectionRects.last;
          if (lastSelection != null) {
            final isMovingUp =
                selection.end.path < lastSelection!.end.path ||
                (selection.end.path.equals(lastSelection!.end.path) && selection.end.offset < lastSelection!.end.offset);
            direction = isMovingUp ? AxisDirection.up : AxisDirection.down;
          }
          break;

        case MobileSelectionDragMode.none:
          // Non-drag selection updates (programmatic, taps, etc.).
          targetRect = selectionRects.last;

          // sometimes moving up in a long single node may be not working
          // so we need to special handle this case.
          final isLastSelectionSingle = lastSelection?.isSingle ?? false;
          final isLastSelectionPathEqual = lastSelection?.start.path.equals(selection.start.path) ?? false;
          final isInSingleNode = isLastSelectionSingle && isLastSelectionPathEqual;
          if (selection.isForward && isInSingleNode) {
            targetRect = selectionRects.first;
          }
      }

      lastSelection = selection;

      final endTouchPoint = targetRect.centerRight;

      if (PlatformExtension.isMobile) {
        // soft keyboard
        // workaround: wait for the soft keyboard to show up
        final keyboardDelay = _currentKeyboardInset == 0 ? const Duration(milliseconds: 250) : Duration.zero;

        debugPrint(
          '[SELECTION_FIX]   mobile branch: '
          'dragMode=$dragMode '
          'targetRect=$targetRect '
          'endTouchPoint=$endTouchPoint '
          'direction=$direction '
          'edgeOffset=${editorState.autoScrollEdgeOffset} '
          'keyboardDelay=${keyboardDelay.inMilliseconds}ms',
        );

        Future.delayed(keyboardDelay, () {
          if (_forwardKey.currentContext == null) {
            return;
          }

          // Universal viewport guard. If the target rect is fully visible
          // inside the viewport, no auto-scroll is needed regardless of
          // dragMode. This prevents the feedback loop where every small
          // selection change during a drag (handle drag, long-press cursor
          // drag) calls startAutoScroll → viewport scrolls → onScroll
          // listener fires → another selection commit → another scroll, ad
          // infinitum. Manifests as the editor scrolling fast vertically
          // when the user drags a handle horizontally, or when the handle
          // is held still.
          //
          // We pick the same handle anchor scroll_service_widget already
          // uses for `targetRect` above: first for left handle, last
          // otherwise (right handle / cursor / default).
          final scrollBox = _forwardKey.currentContext!.findRenderObject() as RenderBox?;
          final freshRects = editorState.selectionRects();
          if (scrollBox != null && freshRects.isNotEmpty) {
            final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
            final viewportBottom = viewportTop + scrollBox.size.height;
            final isLeftHandle = dragMode == MobileSelectionDragMode.leftSelectionHandle;
            final freshTarget = isLeftHandle ? freshRects.first : freshRects.last;
            if (freshTarget.top >= viewportTop && freshTarget.bottom <= viewportBottom) {
              debugPrint(
                '[SELECTION_FIX]   viewport-guard: rect $freshTarget inside '
                '[$viewportTop, $viewportBottom] — skipping scroll '
                '(dragMode=$dragMode)',
              );
              // The framework's EdgeDraggingAutoScroller is a recursive
              // self-driving loop: once `startAutoScrollIfNecessary` has
              // been called with an overflowing rect, it keeps scrolling
              // on its own timer until that stored rect no longer
              // overflows. Returning early here SKIPS calling
              // `startAutoScroll` with the fresh in-viewport rect — so
              // the framework keeps using the LAST stored rect (from
              // when the finger was past the edge) and keeps scrolling
              // even though we've decided we no longer want to. Stop
              // it explicitly. Verified against repro: without this,
              // dragging a handle into the keyboard area and then back
              // up keeps the viewport scrolling and `getNodeInOffset`
              // resolves the finger to ever-deeper newly-revealed nodes
              // → selection extends downward instead of following the
              // finger back up.
              editorState.autoScroller?.stopAutoScroll();
              debugPrint(
                '[SELECTION_FIX]   viewport-guard: stopAutoScroll() called '
                '(framework loop should halt next tick)',
              );
              return;
            }

            debugPrint(
              '[SELECTION_FIX]   viewport-guard: rect $freshTarget OUTSIDE '
              '[$viewportTop, $viewportBottom] — scrolling '
              '(dragMode=$dragMode)',
            );
          }

          debugPrint(
            '[SELECTION_FIX]   → startAutoScroll fired '
            '(endTouchPoint=$endTouchPoint direction=$direction)',
          );
          // Mobile needs to continuously update scroll position/direction during drag
          // Don't skip even if already scrolling, because direction may have changed
          startAutoScroll(endTouchPoint, edgeOffset: editorState.autoScrollEdgeOffset, direction: direction);
        });
      } else {
        if (_forwardKey.currentContext == null) {
          return;
        }
        startAutoScroll(endTouchPoint, edgeOffset: editorState.autoScrollEdgeOffset, direction: direction);
      }
    });
  }

  @override
  void disable() => forward.disable();

  @override
  double get dy => forward.dy;

  @override
  void enable() => forward.enable();

  @override
  double get maxScrollExtent => forward.maxScrollExtent;

  @override
  double get minScrollExtent => forward.minScrollExtent;

  @override
  double? get onePageHeight => forward.onePageHeight;

  @override
  int? get page => forward.page;

  @override
  void scrollTo(double dy, {Duration duration = const Duration(milliseconds: 150)}) =>
      forward.scrollTo(dy, duration: duration);

  @override
  void jumpTo(int index) => forward.jumpTo(index);

  @override
  void jumpToTop() {
    forward.jumpToTop();
  }

  @override
  void jumpToBottom() {
    forward.jumpToBottom();
  }

  @override
  void startAutoScroll(Offset offset, {double edgeOffset = 100, AxisDirection? direction}) {
    forward.startAutoScroll(offset, edgeOffset: edgeOffset, direction: direction);
  }

  @override
  void stopAutoScroll() => forward.stopAutoScroll();

  @override
  void goBallistic(double velocity) => forward.goBallistic(velocity);
}
