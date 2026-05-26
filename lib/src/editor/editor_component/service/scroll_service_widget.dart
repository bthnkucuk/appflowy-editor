import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/scroll/desktop_scroll_service.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/scroll/mobile_scroll_service.dart';
import 'package:appflowy_editor/src/editor/toolbar/mobile/utils/keyboard_height_observer.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScrollServiceWidget extends StatefulWidget {
  const ScrollServiceWidget({
    super.key,
    required this.editorScrollController,
    required this.child,
  });

  final EditorScrollController editorScrollController;

  final Widget child;

  @override
  State<ScrollServiceWidget> createState() => _ScrollServiceWidgetState();
}

class _ScrollServiceWidgetState extends State<ScrollServiceWidget>
    implements AppFlowyScrollService {
  final _forwardKey = GlobalKey(
    debugLabel: 'forward_to_platform_scroll_service',
  );
  late AppFlowyScrollService forward =
      _forwardKey.currentState as AppFlowyScrollService;

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

  void _onSelectionChanged() {
    // should auto scroll after the cursor or selection updated.
    final selection = editorState.selection;
    // ignore: avoid_print
    print(
      '[SCROLL-DBG] _onSelectionChanged '
      'selection=$selection '
      'reason=${editorState.selectionUpdateReason} '
      'extraInfo=${editorState.selectionExtraInfo} '
      'kbHeight=${KeyboardHeightObserver.currentKeyboardHeight}',
    );
    if (selection == null ||
        [
          SelectionUpdateReason.selectAll,
        ].contains(editorState.selectionUpdateReason)) {
      // ignore: avoid_print
      print('[SCROLL-DBG]   → skipped (null or selectAll)');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectionRects = editorState.selectionRects();
      if (selectionRects.isEmpty) {
        // ignore: avoid_print
        print('[SCROLL-DBG]   → skipped (empty rects in postFrame)');
        return;
      }

      Rect targetRect;
      AxisDirection? direction;
      final dynamic dragMode =
          editorState.selectionExtraInfo?['selection_drag_mode'];

      // For desktop: if auto-scroller is already scrolling (from drag-to-select),
      // don't override it here. The desktop_selection_service handles drag scrolling.
      if (PlatformExtension.isDesktopOrWeb &&
          (editorState.autoScroller?.scrolling ?? false)) {
        return;
      }

      switch (dragMode?.toString()) {
        case 'MobileSelectionDragMode.leftSelectionHandle':
          targetRect = selectionRects.first;
          direction = AxisDirection.up;
          break;

        case 'MobileSelectionDragMode.rightSelectionHandle':
          targetRect = selectionRects.last;
          direction = AxisDirection.down;
          break;

        case 'MobileSelectionDragMode.cursor':
          targetRect = selectionRects.last;
          if (lastSelection != null) {
            final isMovingUp =
                selection.end.path < lastSelection!.end.path ||
                (selection.end.path.equals(lastSelection!.end.path) &&
                    selection.end.offset < lastSelection!.end.offset);
            direction = isMovingUp ? AxisDirection.up : AxisDirection.down;
          }
          break;

        default:
          targetRect = selectionRects.last;

          // sometimes moving up in a long single node may be not working
          // so we need to special handle this case.
          final isLastSelectionSingle = lastSelection?.isSingle ?? false;
          final isLastSelectionPathEqual =
              lastSelection?.start.path.equals(selection.start.path) ?? false;
          final isInSingleNode =
              isLastSelectionSingle && isLastSelectionPathEqual;
          if (selection.isForward && isInSingleNode) {
            targetRect = selectionRects.first;
          }
      }

      lastSelection = selection;

      final endTouchPoint = targetRect.centerRight;

      if (PlatformExtension.isMobile) {
        // soft keyboard
        // workaround: wait for the soft keyboard to show up
        final keyboardDelay = KeyboardHeightObserver.currentKeyboardHeight == 0
            ? const Duration(milliseconds: 250)
            : Duration.zero;
        // ignore: avoid_print
        print(
          '[SCROLL-DBG]   mobile branch: '
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
          final scrollBox =
              _forwardKey.currentContext!.findRenderObject() as RenderBox?;
          final freshRects = editorState.selectionRects();
          if (scrollBox != null && freshRects.isNotEmpty) {
            final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
            final viewportBottom = viewportTop + scrollBox.size.height;
            final isLeftHandle =
                dragMode?.toString() ==
                'MobileSelectionDragMode.leftSelectionHandle';
            final freshTarget = isLeftHandle
                ? freshRects.first
                : freshRects.last;
            if (freshTarget.top >= viewportTop &&
                freshTarget.bottom <= viewportBottom) {
              // ignore: avoid_print
              print(
                '[SCROLL-DBG]   viewport-guard: rect $freshTarget inside '
                '[$viewportTop, $viewportBottom] — skipping scroll '
                '(dragMode=$dragMode)',
              );
              return;
            }
            // ignore: avoid_print
            print(
              '[SCROLL-DBG]   viewport-guard: rect $freshTarget OUTSIDE '
              '[$viewportTop, $viewportBottom] — scrolling '
              '(dragMode=$dragMode)',
            );
          }

          // ignore: avoid_print
          print(
            '[SCROLL-DBG]   → startAutoScroll fired '
            '(endTouchPoint=$endTouchPoint direction=$direction)',
          );
          // Mobile needs to continuously update scroll position/direction during drag
          // Don't skip even if already scrolling, because direction may have changed
          startAutoScroll(
            endTouchPoint,
            edgeOffset: editorState.autoScrollEdgeOffset,
            direction: direction,
          );
        });
      } else {
        if (_forwardKey.currentContext == null) {
          return;
        }
        startAutoScroll(
          endTouchPoint,
          edgeOffset: editorState.autoScrollEdgeOffset,
          direction: direction,
        );
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
  void scrollTo(
    double dy, {
    Duration duration = const Duration(milliseconds: 150),
  }) => forward.scrollTo(dy, duration: duration);

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
  void startAutoScroll(
    Offset offset, {
    double edgeOffset = 100,
    AxisDirection? direction,
  }) {
    forward.startAutoScroll(
      offset,
      edgeOffset: edgeOffset,
      direction: direction,
    );
  }

  @override
  void stopAutoScroll() => forward.stopAutoScroll();

  @override
  void goBallistic(double velocity) => forward.goBallistic(velocity);
}
