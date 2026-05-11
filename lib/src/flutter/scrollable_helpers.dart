// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// coverage:ignore-file
//
// Originally a copy of Flutter's `widgets/scrollable_helpers.dart`. Only
// `EdgeDraggingAutoScroller` is kept (and used — see
// `editor_component/service/scroll/auto_scroller.dart`); the rest of the
// upstream file (`ScrollableDetails`, `ScrollIntent`, `ScrollAction`) is
// unused inside this package and was removed.
//
// This class deviates from the upstream version in deliberate ways that we
// want to preserve (verified against framework 3.41.9):
//
// - The constructor takes `minimumAutoScrollDelta`, `maxAutoScrollDelta`,
//   and `animationDuration`. The framework's `EdgeDraggingAutoScroller`
//   exposes none of these.
// - `startAutoScrollIfNecessary(Rect dragTarget, {Duration? duration})` lets
//   callers override the per-tick animation duration; upstream uses a
//   hardcoded 5ms.
// - `_smoothScrollDelta(overDrag)` lerps each tick toward the new clamped
//   delta (factor 0.35) instead of applying the raw overdrag value, which
//   smooths out auto-scroll acceleration and keeps it from juddering. The
//   framework just uses the raw overdrag.
// - The scroll loop is wrapped in try/catch + debugPrint to swallow errors
//   instead of bubbling them up during a drag.
//
// If you ever want to drop this fork, the right move is probably to extend
// Flutter's `EdgeDraggingAutoScroller` and reimplement the smoothing on top
// — not to delete this file outright.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

export 'package:flutter/physics.dart' show Tolerance;

/// An auto scroller that scrolls the [scrollable] if a drag gesture drags close
/// to its edge.
///
/// The scroll velocity is controlled by the [velocityScalar]:
///
/// velocity = (distance of overscroll) * [velocityScalar].
class EdgeDraggingAutoScroller {
  /// Creates a auto scroller that scrolls the [scrollable].
  EdgeDraggingAutoScroller(
    this.scrollable, {
    this.onScrollViewScrolled,
    required this.velocityScalar,
    double minimumAutoScrollDelta = 1.0,
    double maxAutoScrollDelta = 20.0,
    Duration? animationDuration,
  })  : assert(minimumAutoScrollDelta >= 0),
        assert(maxAutoScrollDelta >= minimumAutoScrollDelta),
        _minimumAutoScrollDelta = minimumAutoScrollDelta,
        _maxAutoScrollDelta = maxAutoScrollDelta,
        _animationDuration =
            animationDuration ?? const Duration(milliseconds: 5);

  /// The [Scrollable] this auto scroller is scrolling.
  final ScrollableState scrollable;

  /// Called when a scroll view is scrolled.
  ///
  /// The scroll view may be scrolled multiple times in a row until the drag
  /// target no longer triggers the auto scroll. This callback will be called
  /// in between each scroll.
  final VoidCallback? onScrollViewScrolled;

  /// {@template flutter.widgets.EdgeDraggingAutoScroller.velocityScalar}
  /// The velocity scalar per pixel over scroll.
  ///
  /// It represents how the velocity scale with the over scroll distance. The
  /// auto-scroll velocity = (distance of overscroll) * velocityScalar.
  /// {@endtemplate}
  final double velocityScalar;

  /// The least amount of scroll delta applied per auto scroll tick.
  ///
  /// When the calculated scroll distance is smaller than this value (but still
  /// non-zero), the auto scroller will nudge by this minimum to keep the view
  /// moving rather than treat it as too small to scroll.
  final double _minimumAutoScrollDelta;
  final double _maxAutoScrollDelta;
  final Duration _animationDuration;
  Duration? _currentDuration;
  double? _previousScrollDelta;

  late Rect _dragTargetRelatedToScrollOrigin;

  /// Whether the auto scroll is in progress.
  bool get scrolling => _scrolling;
  bool _scrolling = false;

  double _offsetExtent(Offset offset, Axis scrollDirection) {
    return switch (scrollDirection) {
      Axis.horizontal => offset.dx,
      Axis.vertical => offset.dy,
    };
  }

  double _sizeExtent(Size size, Axis scrollDirection) {
    return switch (scrollDirection) {
      Axis.horizontal => size.width,
      Axis.vertical => size.height,
    };
  }

  AxisDirection get _axisDirection => scrollable.axisDirection;

  Axis get _scrollDirection => axisDirectionToAxis(_axisDirection);

  /// Starts the auto scroll if the [dragTarget] is close to the edge.
  ///
  /// The scroll starts to scroll the [scrollable] if the target rect is close
  /// to the edge of the [scrollable]; otherwise, it remains stationary.
  ///
  /// If the scrollable is already scrolling, calling this method updates the
  /// previous dragTarget to the new value and continues scrolling if necessary.
  void startAutoScrollIfNecessary(Rect dragTarget, {Duration? duration}) {
    final Offset deltaToOrigin = scrollable.deltaToScrollOrigin;
    _dragTargetRelatedToScrollOrigin =
        dragTarget.translate(deltaToOrigin.dx, deltaToOrigin.dy);
    _currentDuration = duration;
    if (_scrolling) {
      // The change will be picked up in the next scroll.
      return;
    }
    assert(!_scrolling);
    _scroll();
  }

  /// Stop any ongoing auto scrolling.
  void stopAutoScroll() {
    _scrolling = false;
    _previousScrollDelta = null;
    _currentDuration = null;
  }

  Future<void> _scroll() async {
    try {
      final RenderBox scrollRenderBox =
          scrollable.context.findRenderObject()! as RenderBox;
      final Matrix4 transform = scrollRenderBox.getTransformTo(null);
      final Rect globalRect = MatrixUtils.transformRect(
        transform,
        Rect.fromLTWH(
          0,
          0,
          scrollRenderBox.size.width,
          scrollRenderBox.size.height,
        ),
      );
      final Rect transformedDragTarget = MatrixUtils.transformRect(
        transform,
        _dragTargetRelatedToScrollOrigin,
      );

      if ((globalRect.size.width + precisionErrorTolerance) >=
              transformedDragTarget.size.width &&
          (globalRect.size.height + precisionErrorTolerance) >=
              transformedDragTarget.size.height) {
        // do nothing.
      }

      _scrolling = true;
      double? newOffset;
      const double overDragMax = 20.0;

      final Offset deltaToOrigin = scrollable.deltaToScrollOrigin;
      final Offset viewportOrigin =
          globalRect.topLeft.translate(deltaToOrigin.dx, deltaToOrigin.dy);
      final double viewportStart =
          _offsetExtent(viewportOrigin, _scrollDirection);
      final double viewportEnd =
          viewportStart + _sizeExtent(globalRect.size, _scrollDirection);

      final double proxyStart = _offsetExtent(
        _dragTargetRelatedToScrollOrigin.topLeft,
        _scrollDirection,
      );
      final double proxyEnd = _offsetExtent(
        _dragTargetRelatedToScrollOrigin.bottomRight,
        _scrollDirection,
      );
      switch (_axisDirection) {
        case AxisDirection.up:
        case AxisDirection.left:
          if (proxyEnd > viewportEnd &&
              scrollable.position.pixels >
                  scrollable.position.minScrollExtent) {
            final double overDrag =
                math.min(proxyEnd - viewportEnd, overDragMax);
            final double delta = _smoothScrollDelta(overDrag);
            newOffset = math.max(
              scrollable.position.minScrollExtent,
              scrollable.position.pixels - delta,
            );
          } else if (proxyStart < viewportStart &&
              scrollable.position.pixels <
                  scrollable.position.maxScrollExtent) {
            final double overDrag =
                math.min(viewportStart - proxyStart, overDragMax);
            final double delta = _smoothScrollDelta(overDrag);
            newOffset = math.min(
              scrollable.position.maxScrollExtent,
              scrollable.position.pixels + delta,
            );
          }
          break;
        case AxisDirection.right:
        case AxisDirection.down:
          if (proxyStart < viewportStart &&
              scrollable.position.pixels >
                  scrollable.position.minScrollExtent) {
            final double overDrag =
                math.min(viewportStart - proxyStart, overDragMax);
            final double delta = _smoothScrollDelta(overDrag);
            newOffset = math.max(
              scrollable.position.minScrollExtent,
              scrollable.position.pixels - delta,
            );
          } else if (proxyEnd > viewportEnd &&
              scrollable.position.pixels <
                  scrollable.position.maxScrollExtent) {
            final double overDrag =
                math.min(proxyEnd - viewportEnd, overDragMax);
            final double delta = _smoothScrollDelta(overDrag);
            newOffset = math.min(
              scrollable.position.maxScrollExtent,
              scrollable.position.pixels + delta,
            );
          }
          break;
      }

      final double currentPixels = scrollable.position.pixels;
      if (newOffset == null) {
        // Drag should not trigger scroll.
        _scrolling = false;

        return;
      }
      double delta = newOffset - currentPixels;
      if (delta.abs() < _minimumAutoScrollDelta) {
        if (delta.abs() <= precisionErrorTolerance) {
          _scrolling = false;

          return;
        }
        final double direction = delta.sign;
        final double target =
            (currentPixels + direction * _minimumAutoScrollDelta).clamp(
          scrollable.position.minScrollExtent,
          scrollable.position.maxScrollExtent,
        );
        newOffset = target.toDouble();
        delta = newOffset - currentPixels;
        if (delta.abs() <= precisionErrorTolerance) {
          _scrolling = false;

          return;
        }
      }
      await scrollable.position.moveTo(
        newOffset,
        duration: _currentDuration ?? _animationDuration,
        curve: Curves.linear,
        // clamp: true,
      );
      onScrollViewScrolled?.call();
      if (_scrolling) {
        await _scroll();
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _scrolling = false;
    }
  }

  double _smoothScrollDelta(double overDrag) {
    if (overDrag <= precisionErrorTolerance) {
      return 0;
    }
    final double desiredDelta = overDrag * velocityScalar;
    final double clampedDelta = desiredDelta.clamp(
      _minimumAutoScrollDelta,
      _maxAutoScrollDelta,
    );
    if (_previousScrollDelta == null) {
      _previousScrollDelta = clampedDelta;

      return clampedDelta;
    }
    final double smoothed =
        lerpDouble(_previousScrollDelta!, clampedDelta, 0.35)!;
    _previousScrollDelta = smoothed;

    return smoothed;
  }
}
