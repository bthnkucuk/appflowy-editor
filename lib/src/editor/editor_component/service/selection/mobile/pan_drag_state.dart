import 'dart:ui';

import 'package:appflowy_editor/src/core/location/selection.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    show MobileSelectionDragMode;
import 'package:flutter/foundation.dart';

/// Mutable state shared across the mobile selection service, gesture
/// strategies, and the auto-scroller during a pan / long-press drag.
///
/// Only the facade owns the lifetime of this object; helpers receive a
/// reference and mutate it directly. [lastPanOffset] is a [ValueNotifier]
/// because the magnifier overlay listens to it; the rest are plain fields
/// because there are no observers — readers always check them imperatively.
class PanDragState {
  Offset? panStartOffset;
  double? panStartScrollDy;
  Selection? panStartSelection;
  bool? isPanStartHorizontal;
  MobileSelectionDragMode dragMode = MobileSelectionDragMode.none;

  final ValueNotifier<Offset?> lastPanOffset = ValueNotifier(null);

  /// Reset pan-coordinate fields and clear the magnifier offset.
  /// Does NOT reset [dragMode] — callers reset it explicitly when the
  /// drag ends (some flows clear coordinates mid-drag without ending it).
  void clearPan() {
    panStartOffset = null;
    panStartSelection = null;
    panStartScrollDy = null;
    lastPanOffset.value = null;
  }

  void dispose() {
    lastPanOffset.dispose();
  }
}
