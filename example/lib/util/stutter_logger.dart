// Intentional src/ import — BlockHighlightArea is internal to the
// editor package but exposes a diagnostic counter for the H2.3
// investigation, and this dev-only logger is the consumer.
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/block_component/base_component/selection/block_highlight_area.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Per-notify diagnostic logger for the H2.3 selection-drag investigation.
///
/// Attach in a page's `initState`, detach in `dispose`. While the user
/// is dragging a selection handle (or any other interactive selection
/// gesture flagged via `selectionExtraInfo[selectionDragModeKey]`),
/// every `selectionNotifier` fire is printed via `debugPrint`. Each
/// line carries:
///
///   - `#` — running notify count within the current drag
///   - `dt` — milliseconds since the previous notify (60 fps ≈ 16 ms)
///   - `dragMode` — the active drag mode (cursor / leftHandle / rightHandle)
///   - `reason` — `SelectionUpdateReason` (uiEvent / transaction / …)
///   - `BSA+=` — BlockSelectionArea builder calls since the previous notify
///   - `BHA+=` — BlockHighlightArea builder calls since the previous notify
///   - `frameMs` — last GPU+raster frame time (rounded, in ms)
///
/// On drag end we emit a one-line summary so the user can copy/paste it
/// out of `adb logcat | grep STUTTER` without scrolling through the
/// per-tick lines.
///
/// Has no effect in release builds (`kDebugMode` guard).
class StutterLogger {
  StutterLogger(this.editorState) {
    if (!kDebugMode) return;
    _bsaBase = BlockSelectionArea.debugBuilderCallCount;
    _bhaBase = BlockHighlightArea.debugBuilderCallCount;
    editorState.selectionNotifier.addListener(_onSelectionNotify);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  final EditorState editorState;

  DateTime? _lastNotify;
  int _bsaBase = 0;
  int _bhaBase = 0;
  int _notifyCount = 0;
  bool _wasDragging = false;
  Duration? _lastFrameTotal;

  // Per-drag aggregates for the summary line.
  int _dragNotifies = 0;
  int _dragBsa = 0;
  int _dragBha = 0;
  int _dragMaxDt = 0;
  int _dragMaxFrameMs = 0;

  void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    final t = timings.last;
    _lastFrameTotal = t.totalSpan;
  }

  void _onSelectionNotify() {
    final now = DateTime.now();
    final dragMode = editorState
            .selectionExtraInfo?[selectionDragModeKey]
        as MobileSelectionDragMode?;
    final isDragging =
        dragMode != null && dragMode != MobileSelectionDragMode.none;

    final bsaNow = BlockSelectionArea.debugBuilderCallCount;
    final bhaNow = BlockHighlightArea.debugBuilderCallCount;
    final bsaDelta = bsaNow - _bsaBase;
    final bhaDelta = bhaNow - _bhaBase;
    _bsaBase = bsaNow;
    _bhaBase = bhaNow;

    if (isDragging || _wasDragging) {
      final dt = _lastNotify == null
          ? 0
          : now.difference(_lastNotify!).inMilliseconds;
      final frameMs = _lastFrameTotal?.inMilliseconds ?? 0;

      if (!isDragging && _wasDragging) {
        // Drag just ended — emit the summary, then reset aggregates.
        debugPrint(
          '[STUTTER] DRAG END  notifies=$_dragNotifies '
          'BSA=$_dragBsa BHA=$_dragBha '
          'maxDt=${_dragMaxDt}ms maxFrame=${_dragMaxFrameMs}ms',
        );
        _dragNotifies = 0;
        _dragBsa = 0;
        _dragBha = 0;
        _dragMaxDt = 0;
        _dragMaxFrameMs = 0;
        _notifyCount = 0;
      } else {
        _notifyCount++;
        _dragNotifies++;
        _dragBsa += bsaDelta;
        _dragBha += bhaDelta;
        if (dt > _dragMaxDt) _dragMaxDt = dt;
        if (frameMs > _dragMaxFrameMs) _dragMaxFrameMs = frameMs;
        debugPrint(
          '[STUTTER] #$_notifyCount '
          'dt=${dt}ms dragMode=${dragMode?.name ?? 'end'} '
          'reason=${editorState.selectionUpdateReason.name} '
          'BSA+=$bsaDelta BHA+=$bhaDelta '
          'frame=${frameMs}ms',
        );
      }
    }

    _lastNotify = now;
    _wasDragging = isDragging;
  }

  void dispose() {
    if (!kDebugMode) return;
    editorState.selectionNotifier.removeListener(_onSelectionNotify);
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }
}
