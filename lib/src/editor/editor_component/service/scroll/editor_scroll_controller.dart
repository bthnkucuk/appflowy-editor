import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// This class controls the scroll behavior of the editor.
///
/// It must be provided in the widget tree above the [PageComponent].
///
/// You can use [offsetNotifier] to get the current scroll offset, and
/// [visibleRangeNotifier] to get the first level visible items.
///
/// If [shrinkWrap] is true the editor is wrapped in a `SingleChildScrollView`
/// and the document is laid out as a `Column`. Otherwise it is rendered with
/// `SuperListView` and items are virtualized.
class EditorScrollController {
  EditorScrollController({
    required this.editorState,
    this.shrinkWrap = false,
    ScrollController? scrollController,
  }) {
    shouldDisposeScrollController = scrollController == null;
    this.scrollController = scrollController ?? ScrollController();

    if (shrinkWrap) {
      void updateVisibleRange() {
        visibleRangeNotifier.value = (
          0,
          editorState.document.root.children.length - 1,
        );
      }

      updateVisibleRange();
      editorState.document.root.addListener(updateVisibleRange);
    }

    this.scrollController.addListener(_syncOffsetNotifier);

    if (!shrinkWrap) {
      listController.addListener(_onVisibleRangeChanged);
    }
  }

  final EditorState editorState;
  final bool shrinkWrap;

  /// Used by `SingleChildScrollView` when shrinkWrap is true and by the
  /// underlying `SuperListView` when shrinkWrap is false.
  late final ScrollController scrollController;
  bool shouldDisposeScrollController = false;

  /// Drives the `SuperListView` used in non-shrinkWrap mode. Useful for
  /// jumping/animating to a specific item by index.
  final ListController listController = ListController();

  /// Current scroll offset in pixels. Updated whenever the underlying
  /// scrollable reports a new position.
  final ValueNotifier<double> offsetNotifier = ValueNotifier(0);

  /// First-level visible items as `(min, max)` indices.
  ///
  /// Example: with the viewport showing nodes 2..9 of a longer document,
  /// the value would be `(1, 8)` (0-indexed).
  final ValueNotifier<(int, int)> visibleRangeNotifier = ValueNotifier((
    -1,
    -1,
  ));

  void dispose() {
    scrollController.removeListener(_syncOffsetNotifier);
    if (shouldDisposeScrollController) {
      scrollController.dispose();
    }
    if (!shrinkWrap) {
      listController.removeListener(_onVisibleRangeChanged);
    }
    listController.dispose();
    offsetNotifier.dispose();
    visibleRangeNotifier.dispose();
  }

  // ---------------------------------------------------------------------------
  // Offset-based scrolling
  // ---------------------------------------------------------------------------

  Future<void> animateTo({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final target = shrinkWrap
        ? offset.clamp(position.minScrollExtent, position.maxScrollExtent)
        : max(0.0, offset);
    await scrollController.animateTo(target, duration: duration, curve: curve);
  }

  /// Non-animated jump to a pixel offset. Clamps to `[min, max]ScrollExtent`.
  ///
  /// No-op if the underlying scroll controller has no clients or the
  /// editor is in non-shrinkWrap mode (which is virtualized and has no
  /// stable pixel coordinate for an arbitrary node — use [jumpToIndex]
  /// instead).
  void jumpToPixels(double pixels) {
    if (!shrinkWrap) return;
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    scrollController.jumpTo(
      pixels.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  /// Legacy combined entry point. Treated `offset` as pixels in shrinkWrap
  /// mode and as a node index (via `.toInt()`) otherwise — a footgun.
  /// Forwards to [jumpToPixels] or [jumpToIndex] based on [shrinkWrap]
  /// so existing callers keep working.
  @Deprecated('Use jumpToPixels(double) or jumpToIndex(index:) directly')
  void jumpTo({required double offset}) {
    if (shrinkWrap) {
      jumpToPixels(offset);
      return;
    }

    final index = offset.toInt();
    final (start, end) = visibleRangeNotifier.value;

    if (index < start || index > end) {
      jumpToIndex(index: max(0, index), alignment: 0);
    }
  }

  /// Relative animated scroll, clamped to `[min, max]ScrollExtent`. The
  /// "safe" prefix is preserved from the pre-migration API; callers
  /// (e.g. `editor_state.scrollToHighlight`) use this to nudge the
  /// viewport by an amount that should never overshoot either edge.
  Future<void> safeAnimateScroll({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final target = (scrollController.offset + offset).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await scrollController.animateTo(target, duration: duration, curve: curve);
  }

  /// Relative non-animated scroll, clamped to `maxScrollExtent` (legacy
  /// behavior — does not clamp at the top).
  void safeJumpTo({required double offset}) {
    if (!scrollController.hasClients) return;
    final target = scrollController.offset + offset;
    final maxExtent = scrollController.position.maxScrollExtent;
    scrollController.jumpTo(target > maxExtent ? maxExtent : target);
  }

  /// Relative animated scroll without clamping. Mirrors the old
  /// `ScrollOffsetController.animateScroll` semantics, kept because
  /// `MobileScrollService.scrollTo` still calls it.
  Future<void> animateScroll({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(
      scrollController.offset + offset,
      duration: duration,
      curve: curve,
    );
  }

  // ---------------------------------------------------------------------------
  // Index-based scrolling
  // ---------------------------------------------------------------------------

  /// Jump to the node at [index]. [alignment] is `0` for top, `0.5` for
  /// middle, `1` for bottom of the viewport.
  void jumpToIndex({required int index, double alignment = 0}) {
    if (!listController.isAttached) return;
    listController.jumpToItem(
      index: max(0, index),
      scrollController: scrollController,
      alignment: alignment,
    );
  }

  /// Animate to the node at [index].
  void scrollToIndex({
    required int index,
    double alignment = 0,
    required Duration duration,
    Curve curve = Curves.linear,
  }) {
    if (!listController.isAttached) return;
    listController.animateToItem(
      index: max(0, index),
      scrollController: scrollController,
      alignment: alignment,
      duration: (_) => duration,
      curve: (_) => curve,
    );
  }

  void jumpToTop() {
    if (shrinkWrap) {
      if (scrollController.hasClients) scrollController.jumpTo(0);
    } else {
      jumpToIndex(index: 0);
    }
  }

  void jumpToBottom() {
    if (shrinkWrap) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    } else {
      jumpToIndex(index: editorState.document.root.children.length - 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _syncOffsetNotifier() {
    if (!scrollController.hasClients) return;
    offsetNotifier.value = scrollController.position.pixels;
  }

  void _onVisibleRangeChanged() {
    if (!listController.isAttached) {
      visibleRangeNotifier.value = (-1, -1);
      return;
    }

    final range = listController.visibleRange;
    if (range == null) {
      visibleRangeNotifier.value = (-1, -1);
      return;
    }

    var (min, max) = range;

    // Convert from "list with optional header/footer" indexing to document
    // child indexing. Only `max` is adjusted; `min` is left as-is because the
    // header (if any) at index 0 collapses to the same document min — this
    // matches the semantics of the pre-migration `_listenItemPositions` code.
    if (editorState.showHeader) {
      max--;
    }

    if (editorState.showFooter &&
        max >= editorState.document.root.children.length) {
      max--;
    }

    visibleRangeNotifier.value = (min, max);
  }
}

extension ValidIndexedValueNotifier on ValueNotifier<(int, int)> {
  /// Returns true if the value is valid.
  bool get isValid => value.$1 >= 0 && value.$2 >= 0 && value.$1 <= value.$2;
}
