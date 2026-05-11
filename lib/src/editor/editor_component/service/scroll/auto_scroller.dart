import 'package:flutter/material.dart';

abstract class AutoScrollerService {
  void startAutoScroll(
    Offset offset, {
    double edgeOffset = 200,
    AxisDirection? direction,
  });

  void stopAutoScroll();
}

/// Wraps Flutter's [EdgeDraggingAutoScroller] with the shape the editor uses:
/// you give it a global cursor offset (optionally with a direction) and an
/// "edge zone" thickness, and it auto-scrolls the nearest [Scrollable] when
/// the cursor falls inside the zone near the viewport edges.
///
/// In framework 3.x `EdgeDraggingAutoScroller` only takes `velocityScalar`,
/// which controls the per-tick duration (`1000 / velocityScalar` ms). The
/// old fork-vendored copy used to expose
/// `minimumAutoScrollDelta`, `maxAutoScrollDelta`, and `animationDuration`
/// as well, plus per-call duration overrides on `startAutoScrollIfNecessary`.
/// None of that survives in the framework class; callers must tune
/// `velocityScalar` instead.
class AutoScroller extends EdgeDraggingAutoScroller
    implements AutoScrollerService {
  AutoScroller(
    super.scrollable, {
    super.onScrollViewScrolled,
    super.velocityScalar = _kDefaultAutoScrollVelocityScalar,
  });

  /// Framework semantics: `velocityScalar` doubles as the inverse of the
  /// per-tick duration (`1000 / velocityScalar` ms). 50 → 20ms tick → up to
  /// 1000 px/s scroll. Tune at each call site (see `editor_state` and
  /// `auto_scrollable_widget`); this default is only used by the no-arg
  /// constructor and isn't hit in practice.
  static const double _kDefaultAutoScrollVelocityScalar = 50.0;

  Offset? lastOffset;
  double? lastEdgeOffset;
  AxisDirection? lastDirection;

  @override
  void startAutoScroll(
    Offset offset, {
    double edgeOffset = 200,
    AxisDirection? direction,
  }) {
    lastOffset = offset;
    lastEdgeOffset = edgeOffset;
    lastDirection = direction;
    if (direction == AxisDirection.up) {
      return startAutoScrollIfNecessary(
        Rect.fromLTWH(offset.dx, offset.dy - edgeOffset, 1, edgeOffset),
      );
    }

    if (direction == AxisDirection.down) {
      return startAutoScrollIfNecessary(
        Rect.fromLTWH(offset.dx, offset.dy, 1, edgeOffset),
      );
    }

    final dragTarget = Rect.fromCenter(
      center: offset,
      width: edgeOffset,
      height: edgeOffset,
    );

    startAutoScrollIfNecessary(dragTarget);
  }

  @override
  void stopAutoScroll() {
    lastOffset = null;
    lastEdgeOffset = null;
    lastDirection = null;
    super.stopAutoScroll();
  }

  void continueToAutoScroll() {
    final cursor = lastOffset;
    if (cursor != null) {
      startAutoScroll(
        cursor,
        edgeOffset: lastEdgeOffset ?? 200,
        direction: lastDirection,
      );
    }
  }
}
