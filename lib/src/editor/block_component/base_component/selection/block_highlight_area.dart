import 'package:appflowy_editor/appflowy_editor.dart' hide Path;
import 'package:appflowy_editor/src/render/selection/cursor.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Cheap equality for `List<Rect>?` — see selection_area_painter.dart for
// the same helper. Replaces a `DeepCollectionEquality` call (~3-5x slower
// for this shape, measured in test/performance/render_layer_benchmark_test.dart).
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

/// [BlockHighlightArea] is a widget that renders the selection area or the cursor of a block.
class BlockHighlightArea extends StatefulWidget {
  const BlockHighlightArea({
    super.key,
    required this.node,
    required this.delegate,
    required this.listenable,
    required this.cursorColor,
    required this.highlightColor,
    required this.blockColor,
    required this.highlightAreaColor,
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
  final Color highlightColor;

  final Color highlightAreaColor;

  final Color blockColor;

  // the node of the block
  final Node node;

  final List<BlockSelectionType> supportTypes;

  /// Diagnostic counter for the H2.3 stutter investigation. See
  /// `BlockSelectionArea.debugBuilderCallCount` for rationale — same
  /// pattern, separate counter so a test can attribute calls to the
  /// highlight path independently.
  @visibleForTesting
  static int debugBuilderCallCount = 0;

  @override
  State<BlockHighlightArea> createState() => _BlockSelectionAreaState();
}

/// Paint-relevant state for a single [BlockHighlightArea]. Same shape
/// as [_BlockSelectionPaint] in block_selection_area.dart, but with
/// an extra `sectionRects` slot for the section-highlight layer that
/// BHA stacks behind the main selection paint.
@immutable
class _BlockHighlightPaint {
  const _BlockHighlightPaint({
    required this.type,
    this.cursorRect,
    this.selectionRects,
    this.sectionRects,
    this.blockRect,
  });

  final BlockSelectionType type;
  final Rect? cursorRect;
  final List<Rect>? selectionRects;
  final List<Rect>? sectionRects;
  final Rect? blockRect;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _BlockHighlightPaint &&
        other.type == type &&
        other.cursorRect == cursorRect &&
        other.blockRect == blockRect &&
        _rectListEq(other.selectionRects, selectionRects) &&
        _rectListEq(other.sectionRects, sectionRects);
  }

  @override
  int get hashCode => Object.hash(type, cursorRect, blockRect);
}

class _BlockSelectionAreaState extends State<BlockHighlightArea> {
  // Forces the Cursor widget's blink ticker to re-sync on every cursor
  // rebuild — kept across paint-state changes via GlobalKey.
  late GlobalKey cursorKey = GlobalKey(
    debugLabel: 'cursor_${widget.node.path}',
  );

  // Cache `supportTypes.toString()` — see block_selection_area.dart for the
  // motivation. Avoids re-walking the list on every build. Recomputed in
  // didUpdateWidget when the content actually changes.
  late String _supportTypesSuffix = widget.supportTypes.toString();

  /// Cached section identity to avoid re-running `getRectsInSelection`
  /// against the section when the selection's containing section
  /// hasn't actually changed. Lives outside the paint notifier because
  /// it's a derivation input, not a paint output.
  Selection? _prevSection;
  List<Rect>? _prevSectionRects;

  /// Derived per-block paint state. See `BlockSelectionArea`'s
  /// `_paintNotifier` (block_selection_area.dart) for the rationale —
  /// same H2.3.a treatment, separate notifier so a `BlockHighlightArea`
  /// listening to `highlightNotifier` stays decoupled from a sibling
  /// `BlockSelectionArea` on `selectionNotifier`.
  final ValueNotifier<_BlockHighlightPaint?> _paintNotifier = ValueNotifier(
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelectionIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant BlockHighlightArea oldWidget) {
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
    return ValueListenableBuilder<_BlockHighlightPaint?>(
      key: ValueKey(widget.node.id + _supportTypesSuffix),
      valueListenable: _paintNotifier,
      builder: (context, paint, _) {
        BlockHighlightArea.debugBuilderCallCount++;
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
                  borderRadius: BorderRadius.circular(4),
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
            // Force visibility on each rebuild — see BSA for rationale.
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
            return Stack(
              children: [
                RepaintBoundary(
                  child: HighlightAreaPaint(
                    rects: paint.sectionRects ?? <Rect>[],
                    highlightColor: widget.highlightAreaColor,
                  ),
                ),
                RepaintBoundary(
                  child: HighlightAreaPaint(
                    rects: rects,
                    highlightColor: widget.highlightColor,
                  ),
                ),
              ],
            );
          case BlockSelectionType.highlight:
            // Not surfaced by the current BHA paint pipeline — reserved
            // for downstream consumers that wire their own supportTypes.
            return const SizedBox.shrink();
        }
      },
    );
  }

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
      _paintNotifier.value = _BlockHighlightPaint(
        type: BlockSelectionType.block,
        blockRect: rect,
      );
      return;
    }

    if (supportTypes.contains(BlockSelectionType.cursor) &&
        selection.isCollapsed) {
      final rect = widget.delegate.getCursorRectInPosition(selection.start);
      _paintNotifier.value = _BlockHighlightPaint(
        type: BlockSelectionType.cursor,
        cursorRect: rect,
      );
      return;
    }

    if (supportTypes.contains(BlockSelectionType.selection)) {
      // Section caching: rect lookup against node.sections is cheap, but
      // calling getRectsInSelection on the section selection still walks
      // the RichText layout. Skip it when the section identity didn't
      // change.
      final mid = (selection.start.offset + selection.end.offset) ~/ 2;
      final currentSection = widget.node.sections?.firstWhereOrNull(
        (section) => section.selection.end.offset >= mid,
      );
      final sectionSelection = currentSection?.selection;

      List<Rect>? sectionRects = _prevSectionRects;
      if (sectionSelection != null && _prevSection != sectionSelection) {
        final selectionWithPath = sectionSelection.copyWith(
          start: sectionSelection.start.copyWith(path: widget.node.path),
          end: sectionSelection.end.copyWith(path: widget.node.path),
        );
        sectionRects = widget.delegate.getRectsInSelection(selectionWithPath);
        _prevSection = sectionSelection;
        _prevSectionRects = sectionRects;
      }

      final rects = widget.delegate.getRectsInSelection(selection);
      _paintNotifier.value = _BlockHighlightPaint(
        type: BlockSelectionType.selection,
        selectionRects: rects,
        sectionRects: sectionRects,
      );
      return;
    }

    _paintNotifier.value = null;
  }
}

class HighlightAreaPaint extends StatefulWidget {
  const HighlightAreaPaint({
    super.key,
    required this.rects,
    required this.highlightColor,
    this.delay,
    this.padding,
  });

  final List<Rect> rects;
  final Color highlightColor;
  final Duration? delay;
  final int? padding;

  @override
  State<HighlightAreaPaint> createState() => _HighlightAreaPaintState();
}

class _HighlightAreaPaintState extends State<HighlightAreaPaint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  late List<Rect> _oldRects;
  late List<Rect> _newRects;

  void _forward() {
    if (widget.delay != null) {
      Future.delayed(widget.delay!, () {
        _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _oldRects = widget.rects;
    _newRects = widget.rects;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _forward();
  }

  @override
  void didUpdateWidget(covariant HighlightAreaPaint oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_rectListEq(widget.rects, oldWidget.rects)) {
      _oldRects = oldWidget.rects;
      _newRects = widget.rects;
      _controller.reset();
      _forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Rect> _interpolateRects(double t) {
    final result = <Rect>[];

    for (int i = 0; i < _newRects.length; i++) {
      final newRect = _newRects[i];
      final oldRect = (i < _oldRects.length) ? _oldRects[i] : newRect;

      final interpolated = Rect.lerp(oldRect, newRect, t)!;
      result.add(interpolated);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final currentRects = _interpolateRects(_progress.value);
        return CustomPaint(
          painter: _HighlightAreaPainter(
            rects: currentRects,
            selectionColor: widget.highlightColor,
          ),
        );
      },
    );
  }
}

class _HighlightAreaPainter extends CustomPainter {
  const _HighlightAreaPainter({
    required this.rects,
    required this.selectionColor,
  });

  final List<Rect> rects;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = selectionColor;
    final path = Path();

    // Satır satır grupla
    final rowGroups = _groupByBox(rects);
    final rows = rowGroups.toList();

    // Her satır için path'e ekle
    for (int i = 0; i < rows.length; i++) {
      final rowBoxes = rows[i];
      if (rowBoxes.isEmpty) continue;

      final firstBox = rowBoxes.first;
      final lastBox = rowBoxes.last;

      final previousRow = i > 0 ? rows[i - 1] : null;
      final nextRow = i < rows.length - 1 ? rows[i + 1] : null;

      // Köşe radiuslarını belirle
      final topLeftRadius =
          previousRow == null || firstBox.left < previousRow.first.left
          ? 6.0
          : 0.0;

      final topRightRadius =
          previousRow == null || lastBox.right > previousRow.last.right
          ? 6.0
          : 0.0;

      final bottomLeftRadius =
          nextRow == null || firstBox.left < nextRow.first.left ? 6.0 : 0.0;

      final bottomRightRadius =
          nextRow == null || lastBox.right > nextRow.last.right ? 6.0 : 0.0;

      // Son satır için alt kısmına 4px ekle
      final bottom = nextRow == null ? lastBox.bottom + 4 : lastBox.bottom;
      final rect = Rect.fromLTRB(
        firstBox.left - 4, // Expand left
        firstBox.top - 4, // Expand top
        lastBox.right + 4, // Expand right
        bottom + 0, // Expand bottom
      );

      path.addRSuperellipse(
        RSuperellipse.fromRectAndCorners(
          rect,
          topLeft: topLeftRadius > 0
              ? Radius.circular(topLeftRadius)
              : Radius.zero,
          topRight: topRightRadius > 0
              ? Radius.circular(topRightRadius)
              : Radius.zero,
          bottomLeft: bottomLeftRadius > 0
              ? Radius.circular(bottomLeftRadius)
              : Radius.zero,
          bottomRight: bottomRightRadius > 0
              ? Radius.circular(bottomRightRadius)
              : Radius.zero,
        ),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HighlightAreaPainter oldDelegate) {
    return selectionColor != oldDelegate.selectionColor ||
        !_rectListEq(rects, oldDelegate.rects);
  }
}

List<List<Rect>> _groupByBox(List<Rect> boxes) {
  Map<double, List<Rect>> grouped = {};

  for (var box in boxes) {
    grouped.putIfAbsent(box.bottom, () => []).add(box);
  }

  return grouped.values.toList();
}

/// How bigger the selection highlight box is than the natural selection box
/// of the text in dip.
///
/// [TextSelectionPainter] paints the selection highlight box by using the result
/// of [TextLayout.getBoxesForSelection] and expanding both the top and bottom of
/// each box by this amount.
///
/// This can be used to align other widgets, like the drag handles, with the
/// selection highlight box.
const selectionHighlightBoxVerticalExpansion = 2.0;
