import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// This class controls the scroll behavior of the editor.
///
/// It must be provided in the widget tree above the [PageComponent].
///
/// You can use [offsetNotifier] to get the current scroll offset.
/// And, you can use [visibleRangeNotifier] to get the first level visible items.
///
/// If the shrinkWrap is true, the scrollController must not be null
///   and the editor should be wrapped in a SingleChildScrollView.
///
/// Implementation note: the editor was previously backed by
/// `scrollable_positioned_list`. This class still exposes the same public
/// surface (itemScrollController/scrollOffsetController) via thin adapters
/// over `super_sliver_list`'s `ListController` + a regular `ScrollController`.
class EditorScrollController {
  EditorScrollController({
    required this.editorState,
    this.shrinkWrap = false,
    ScrollController? scrollController,
  }) {
    shouldDisposeScrollController = scrollController == null;
    this.scrollController = scrollController ?? ScrollController();

    _itemScrollController = EditorItemScrollController._(this);
    _scrollOffsetController = EditorScrollOffsetController._(this);

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

  // Required by [SingleChildScrollView] when shrinkWrap is true and by the
  // `SuperListView` underneath when shrinkWrap is false.
  late final ScrollController scrollController;
  bool shouldDisposeScrollController = false;

  /// Drives the `SuperListView` used in non-shrinkWrap mode. Exposed so other
  /// code (e.g. tests) can introspect, but treat as internal.
  final ListController listController = ListController();

  /// Current scroll offset in pixels. Updated whenever the inner scrollable
  /// reports a new position.
  final ValueNotifier<double> offsetNotifier = ValueNotifier(0);

  /// First-level visible items, e.g.:
  ///
  /// 1. text1
  /// 2. text2 ---
  ///  2.1 text21|
  /// ...        |
  /// 5. text5   | screen
  /// ...        |
  /// 9. text9 ---
  /// 10. text10
  ///
  /// would yield visibleRange = (1, 8), index starting from 0.
  final ValueNotifier<(int, int)> visibleRangeNotifier =
      ValueNotifier((-1, -1));

  late final EditorItemScrollController _itemScrollController;
  late final EditorScrollOffsetController _scrollOffsetController;

  /// Backwards-compatible API: behaves like the old
  /// `scrollable_positioned_list` `ItemScrollController`.
  EditorItemScrollController get itemScrollController {
    if (shrinkWrap) {
      throw UnsupportedError(
        'ItemScrollController is not supported when shrinkWrap is true',
      );
    }
    return _itemScrollController;
  }

  /// Backwards-compatible API: behaves like the old
  /// `scrollable_positioned_list` `ScrollOffsetController`.
  EditorScrollOffsetController get scrollOffsetController {
    if (shrinkWrap) {
      throw UnsupportedError(
        'ScrollOffsetController is not supported when shrinkWrap is true',
      );
    }
    return _scrollOffsetController;
  }

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
    await scrollController.animateTo(
      target,
      duration: duration,
      curve: curve,
    );
  }

  void jumpTo({
    required double offset,
  }) {
    if (shrinkWrap) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(
          offset.clamp(
            scrollController.position.minScrollExtent,
            scrollController.position.maxScrollExtent,
          ),
        );
      }

      return;
    }

    final index = offset.toInt();
    final (start, end) = visibleRangeNotifier.value;

    if (index < start || index > end) {
      _itemScrollController.jumpTo(
        index: max(0, index),
        alignment: 0,
      );
    }
  }

  void jumpToTop() {
    if (shrinkWrap) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    } else {
      _itemScrollController.jumpTo(index: 0);
    }
  }

  void jumpToBottom() {
    if (shrinkWrap) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    } else {
      _itemScrollController.jumpTo(
        index: editorState.document.root.children.length - 1,
      );
    }
  }

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
    // child indexing. Matches the legacy semantics of the previous
    // ItemPositionsListener-based code, including its quirks: only `max` is
    // adjusted; `min` is left as-is because the header (if any) at index 0
    // collapses to the same document min.
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

/// Mimics the public surface of the old `ItemScrollController`. Lives on the
/// owning [EditorScrollController]; do not construct directly.
class EditorItemScrollController {
  EditorItemScrollController._(this._owner);

  final EditorScrollController _owner;

  void jumpTo({required int index, double alignment = 0}) {
    if (!_owner.listController.isAttached) return;
    _owner.listController.jumpToItem(
      index: max(0, index),
      scrollController: _owner.scrollController,
      alignment: alignment,
    );
  }

  Future<void> scrollTo({
    required int index,
    double alignment = 0,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!_owner.listController.isAttached) return;
    _owner.listController.animateToItem(
      index: max(0, index),
      scrollController: _owner.scrollController,
      alignment: alignment,
      duration: (_) => duration,
      curve: (_) => curve,
    );
  }
}

/// Mimics the public surface of the old `ScrollOffsetController`, including
/// the fork-added `safeAnimateScroll` / `safeJumpTo` wrappers.
class EditorScrollOffsetController {
  EditorScrollOffsetController._(this._owner);

  final EditorScrollController _owner;

  double get maxScrollOffset =>
      _owner.scrollController.position.maxScrollExtent;

  double get minScrollOffset =>
      _owner.scrollController.position.minScrollExtent;

  /// Relative scroll, clamped to [[minScrollOffset], [maxScrollOffset]].
  Future<void> safeAnimateScroll({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!_owner.scrollController.hasClients) return;
    final current = _owner.scrollController.offset;
    final target = (current + offset).clamp(minScrollOffset, maxScrollOffset);
    await _owner.scrollController.animateTo(
      target,
      duration: duration,
      curve: curve,
    );
  }

  /// Relative scroll, clamped to max only (legacy behavior).
  void safeJumpTo({required double offset}) {
    if (!_owner.scrollController.hasClients) return;
    final current = _owner.scrollController.offset;
    final target = current + offset;
    _owner.scrollController.jumpTo(
      target > maxScrollOffset ? maxScrollOffset : target,
    );
  }

  /// Relative scroll, no clamp.
  Future<void> animateScroll({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!_owner.scrollController.hasClients) return;
    final current = _owner.scrollController.offset;
    await _owner.scrollController.animateTo(
      current + offset,
      duration: duration,
      curve: curve,
    );
  }

  /// Absolute scroll.
  Future<void> animateTo({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!_owner.scrollController.hasClients) return;
    await _owner.scrollController.animateTo(
      offset,
      duration: duration,
      curve: curve,
    );
  }
}
