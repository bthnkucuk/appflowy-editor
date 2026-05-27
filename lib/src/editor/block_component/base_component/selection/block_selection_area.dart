import 'package:appflowy_editor/appflowy_editor.dart';
import 'selection_area_painter.dart';
import '../../../../render/selection/cursor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Cheap equality for `List<Rect>?` — Rect already has value equality, so
// only an element-wise scan is needed. Replaces a `DeepCollectionEquality`
// call that's ~3-5x slower for this shape (measured in
// `test/performance/render_layer_benchmark_test.dart`).
bool _rectListEq(List<Rect>? a, List<Rect>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  final n = a.length;
  if (b.length != n) return false;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

enum BlockSelectionType { cursor, selection, highlight, block }

/// Paint-relevant state for a single [BlockSelectionArea]. Captures
/// what — if anything — this block needs to render right now. Equality
/// is value-based so the per-block notifier in
/// [_BlockSelectionAreaState] can short-circuit emit when nothing
/// changed.
///
/// H2.3.a: out-of-selection blocks transition to `null` once and stay
/// there until the selection re-enters their path. Each transition
/// fires the notifier once; equal-to-prev assignments (the common case
/// during a drag, for ~N−1 blocks per tick) are absorbed silently.
@immutable
class _BlockSelectionPaint {
  const _BlockSelectionPaint({
    required this.type,
    this.cursorRect,
    this.selectionRects,
    this.blockRect,
  });

  final BlockSelectionType type;
  final Rect? cursorRect;
  final List<Rect>? selectionRects;
  final Rect? blockRect;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _BlockSelectionPaint &&
        other.type == type &&
        other.cursorRect == cursorRect &&
        other.blockRect == blockRect &&
        _rectListEq(other.selectionRects, selectionRects);
  }

  @override
  int get hashCode => Object.hash(type, cursorRect, blockRect);
}

/// [BlockSelectionArea] is a widget that renders the selection area or the cursor of a block.
class BlockSelectionArea extends StatefulWidget {
  const BlockSelectionArea({
    super.key,
    required this.node,
    required this.delegate,
    required this.listenable,
    required this.cursorColor,
    required this.selectionColor,
    required this.blockColor,
    this.supportTypes = const [
      BlockSelectionType.cursor,
      BlockSelectionType.selection,
    ],
  });

  // get the cursor rect or selection rects from the delegate
  final SelectableMixin delegate;

  // get the selection from the listenable
  final ValueListenable<Selection?> listenable;

  // the color of the cursor
  final Color cursorColor;

  // the color of the selection
  final Color selectionColor;

  final Color blockColor;

  // the node of the block
  final Node node;

  final List<BlockSelectionType> supportTypes;

  /// Diagnostic counter for the H2.3 stutter investigation. Incremented
  /// inside the `ValueListenableBuilder` body — i.e. once per per-block
  /// paint emit. After H2.3.a (derived listenable), this count drops
  /// from ~3N to ~6 per selection notify on an N-block document.
  /// One integer increment per build; production cost is negligible.
  ///
  /// Public (no `@visibleForTesting`) so example apps can wire a
  /// runtime stutter logger without an analyzer escape hatch.
  static int debugBuilderCallCount = 0;

  /// H2.8.e diagnostic: incremented when `initState` schedules a
  /// post-frame `_updateSelectionIfNeeded` call. Pre-fix this happens
  /// for every mounted BSA regardless of whether the block is in the
  /// current selection; post-fix it only happens for blocks whose
  /// path intersects the current selection.
  static int debugInitStateScheduleCount = 0;

  @override
  State<BlockSelectionArea> createState() => _BlockSelectionAreaState();
}

class _BlockSelectionAreaState extends State<BlockSelectionArea> {
  // Forces the Cursor widget's blink ticker to re-sync on every cursor
  // rebuild — kept across paint-state changes via GlobalKey.
  late GlobalKey cursorKey = GlobalKey(
    debugLabel: 'cursor_${widget.node.path}',
  );

  // Cache `supportTypes.toString()`. The ValueListenableBuilder key
  // recomputes on every build (every paint emit); the previous inline
  // expression rebuilt a fresh string each call.
  late String _supportTypesSuffix = widget.supportTypes.toString();

  /// Derived per-block paint state. The outer `widget.listenable`
  /// (= `editorState.selectionNotifier`) fires on every selection
  /// change; that wakes _every_ mounted [BlockSelectionArea] in the
  /// document. By dispatching the builder off this _local_ notifier
  /// instead — and only writing into it when the paint actually
  /// differs (handled by ValueNotifier's `==` short-circuit) — the
  /// rebuild count drops from ~3N per selection notify to ~6 (only the
  /// blocks at the old and new selection boundaries actually transition).
  final ValueNotifier<_BlockSelectionPaint?> _paintNotifier = ValueNotifier(
    null,
  );

  // H2.2: drives _updateSelectionIfNeeded on selection-change instead of
  // self-rescheduling every frame. Pending flag coalesces multiple notifies
  // within one frame into a single post-frame update.
  bool _updatePending = false;

  @override
  void initState() {
    super.initState();

    widget.listenable.addListener(_scheduleUpdate);

    // H2.8.e: only schedule the initial paint-state computation when
    // this block's path actually intersects the current selection.
    // For the common case (selection is collapsed elsewhere or null),
    // the paint state would be `null` after computation anyway — the
    // notifier short-circuits, no rebuild happens, but the closure
    // schedule + `getRectsInSelection`-style queries cost real time on
    // every newly-mounted block. Future selection changes still fire
    // `_scheduleUpdate` via the listener, so this is a pure
    // mount-time optimization.
    final selection = widget.listenable.value?.normalized;
    if (selection == null || !widget.node.path.inSelection(selection)) {
      return;
    }

    BlockSelectionArea.debugInitStateScheduleCount++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelectionIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant BlockSelectionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_scheduleUpdate);
      widget.listenable.addListener(_scheduleUpdate);
    }
    if (!listEquals(oldWidget.supportTypes, widget.supportTypes)) {
      _supportTypesSuffix = widget.supportTypes.toString();
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_scheduleUpdate);
    _paintNotifier.dispose();
    super.dispose();
  }

  void _scheduleUpdate() {
    if (!mounted || _updatePending) return;
    _updatePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePending = false;
      if (mounted) _updateSelectionIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_BlockSelectionPaint?>(
      key: ValueKey(widget.node.id + _supportTypesSuffix),
      valueListenable: _paintNotifier,
      builder: (context, paint, _) {
        BlockSelectionArea.debugBuilderCallCount++;
        if (paint == null) {
          return const SizedBox.shrink();
        }

        switch (paint.type) {
          case BlockSelectionType.block:
            final blockRect = paint.blockRect;
            if (blockRect == null) return const SizedBox.shrink();
            final editorState = context.read<EditorState>();
            final builder = editorState.rendererService.blockComponentBuilder(
              widget.node.type,
            );
            final padding = builder?.configuration.blockSelectionAreaMargin(
              widget.node,
            );
            return Positioned.fromRect(
              rect: blockRect,
              child: Container(
                margin: padding,
                decoration: BoxDecoration(
                  color: widget.blockColor,
                  borderRadius: BorderRadius.all(Radius.circular(4.0)),
                ),
              ),
            );
          case BlockSelectionType.cursor:
            final cursorRect = paint.cursorRect;
            if (cursorRect == null) return const SizedBox.shrink();
            final editorState = context.read<EditorState>();
            final dragMode =
                editorState.selectionExtraInfo?[selectionDragModeKey];
            final shouldBlink =
                widget.delegate.shouldCursorBlink &&
                dragMode != MobileSelectionDragMode.cursor;

            final cursor = Cursor(
              key: cursorKey,
              rect: cursorRect,
              shouldBlink: shouldBlink,
              cursorStyle: widget.delegate.cursorStyle,
              color: widget.cursorColor,
            );
            // Force the cursor to be visible (not mid-blink-off) on each
            // rebuild — equivalent to the pre-refactor `_clearCursorRect`
            // behavior, but now only fires when paint actually differs.
            cursorKey.currentState?.unwrapOrNull<CursorState>()?.show();
            return cursor;
          case BlockSelectionType.selection:
            final rects = paint.selectionRects;
            if (rects == null || rects.isEmpty) {
              return const SizedBox.shrink();
            }
            if (rects.length == 1 && rects.first.width == 0) {
              return const SizedBox.shrink();
            }
            // Optional per-selection corner radius. Used by the
            // find-replace highlight to draw the active match with
            // rounded corners (key is set on the selection extraInfo
            // by SearchServiceV3); regular selections leave it null
            // and fall back to square rects.
            final extraInfo = context
                .read<EditorState>()
                .selectionExtraInfo;
            final radius =
                (extraInfo?[selectionExtraInfoSelectionRadius] as double?) ??
                0.0;
            return SelectionAreaPaint(
              rects: rects,
              selectionColor: widget.selectionColor,
              radius: radius,
            );
          case BlockSelectionType.highlight:
            // BlockSelectionArea doesn't paint the highlight variant —
            // that's BlockHighlightArea's job. Sibling widgets are
            // expected to consume different supportTypes lists.
            return const SizedBox.shrink();
        }
      },
    );
  }

  /// Compute the paint state implied by the current selection and the
  /// owning block's path. Returns `null` if nothing should be rendered
  /// for this block — that's the dominant case on every notify (only
  /// the few blocks intersecting the selection produce a non-null
  /// paint). ValueNotifier's `==` short-circuit absorbs equal-to-prev
  /// assignments silently.
  void _updateSelectionIfNeeded() {
    if (!mounted) {
      return;
    }

    final selection = widget.listenable.value?.normalized;
    final path = widget.node.path;

    if (selection == null || !path.inSelection(selection)) {
      _paintNotifier.value = null;
      return;
    }

    final editorState = context.read<EditorState>();
    final supportTypes = widget.supportTypes;

    if (supportTypes.contains(BlockSelectionType.block) &&
        editorState.selectionType == SelectionType.block) {
      if (!path.inSelection(selection, isSameDepth: true)) {
        _paintNotifier.value = null;
        return;
      }
      final rect = widget.delegate.getBlockRect();
      _paintNotifier.value = _BlockSelectionPaint(
        type: BlockSelectionType.block,
        blockRect: rect,
      );
      return;
    }

    if (supportTypes.contains(BlockSelectionType.cursor) &&
        selection.isCollapsed) {
      final rect = widget.delegate.getCursorRectInPosition(selection.start);
      _paintNotifier.value = _BlockSelectionPaint(
        type: BlockSelectionType.cursor,
        cursorRect: rect,
      );
      return;
    }

    if (supportTypes.contains(BlockSelectionType.selection)) {
      final rects = widget.delegate.getRectsInSelection(selection);
      _paintNotifier.value = _BlockSelectionPaint(
        type: BlockSelectionType.selection,
        selectionRects: rects,
      );
      return;
    }

    _paintNotifier.value = null;
  }
}
