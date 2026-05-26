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

class _BlockSelectionAreaState extends State<BlockHighlightArea> {
  // We need to keep the key to refresh the cursor status when typing continuously.
  late GlobalKey cursorKey = GlobalKey(
    debugLabel: 'cursor_${widget.node.path}',
  );

  // Cache `supportTypes.toString()` — see block_selection_area.dart for the
  // motivation. Avoids re-walking the list on every build. Recomputed in
  // didUpdateWidget when the content actually changes.
  late String _supportTypesSuffix = widget.supportTypes.toString();

  // keep the previous cursor rect to avoid unnecessary rebuild
  Rect? prevCursorRect;
  // keep the previous selection rects to avoid unnecessary rebuild
  List<Rect>? prevSelectionRects;
  // keep the block selection rect to avoid unnecessary rebuild

  // keep the previous section rects to avoid unnecessary rebuild
  Selection? prevSection;
  List<Rect>? sectionRects;

  Rect? prevBlockRect;

  // H2.2: drives _updateSelectionIfNeeded on selection-change instead of
  // self-rescheduling every frame. Pending flag coalesces multiple notifies
  // within one frame into a single post-frame update.
  bool _updatePending = false;

  @override
  void initState() {
    super.initState();

    widget.listenable.addListener(_scheduleUpdate);
    widget.listenable.addListener(_clearCursorRect);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelectionIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant BlockHighlightArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_scheduleUpdate);
      oldWidget.listenable.removeListener(_clearCursorRect);
      widget.listenable.addListener(_scheduleUpdate);
      widget.listenable.addListener(_clearCursorRect);
    }
    if (!listEquals(oldWidget.supportTypes, widget.supportTypes)) {
      _supportTypesSuffix = widget.supportTypes.toString();
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_scheduleUpdate);
    widget.listenable.removeListener(_clearCursorRect);

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
    return ValueListenableBuilder(
      key: ValueKey(widget.node.id + _supportTypesSuffix),
      valueListenable: widget.listenable,
      builder: ((context, value, child) {
        BlockHighlightArea.debugBuilderCallCount++;
        final sizedBox = child ?? const SizedBox.shrink();
        final selection = value?.normalized;

        if (selection == null) {
          return sizedBox;
        }

        final path = widget.node.path;
        if (!path.inSelection(selection)) {
          return sizedBox;
        }

        final editorState = context.read<EditorState>();

        if (editorState.selectionType == SelectionType.block) {
          if (!widget.supportTypes.contains(BlockSelectionType.block) ||
              !path.inSelection(selection, isSameDepth: true) ||
              prevBlockRect == null) {
            return sizedBox;
          }
          final builder = editorState.rendererService
              .blockComponentBuilder(widget.node.type);
          final padding = builder?.configuration.blockSelectionAreaMargin(
            widget.node,
          );
          return Positioned.fromRect(
            rect: prevBlockRect!,
            child: Container(
              margin: padding,
              decoration: BoxDecoration(
                color: widget.blockColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }
        // show the cursor when the selection is collapsed
        else if (selection.isCollapsed) {
          if (!widget.supportTypes.contains(BlockSelectionType.cursor) ||
              prevCursorRect == null) {
            return sizedBox;
          }
          final editorState = context.read<EditorState>();
          final dragMode =
              editorState.selectionExtraInfo?[selectionDragModeKey];
          final shouldBlink =
              widget.delegate.shouldCursorBlink &&
              dragMode != MobileSelectionDragMode.cursor;

          final cursor = Cursor(
            key: cursorKey,
            rect: prevCursorRect!,
            shouldBlink: shouldBlink,
            cursorStyle: widget.delegate.cursorStyle,
            color: widget.cursorColor,
          );
          // force to show the cursor
          cursorKey.currentState?.unwrapOrNull<CursorState>()?.show();
          return cursor;
        } else {
          // show the selection area when the selection is not collapsed
          if (!widget.supportTypes.contains(BlockSelectionType.selection) ||
              prevSelectionRects == null ||
              prevSelectionRects!.isEmpty ||
              (prevSelectionRects!.length == 1 &&
                  prevSelectionRects!.first.width == 0)) {
            return sizedBox;
          }

          return Stack(
            children: [
              RepaintBoundary(
                child: HighlightAreaPaint(
                  rects: sectionRects ?? <Rect>[],
                  highlightColor: widget.highlightAreaColor,
                ),
              ),
              RepaintBoundary(
                child: HighlightAreaPaint(
                  rects: prevSelectionRects ?? <Rect>[],
                  highlightColor: widget.highlightColor,
                ),
              ),
            ],
          );
        }
      }),
      child: const SizedBox.shrink(),
    );
  }

  void _updateSelectionIfNeeded() {
    if (!mounted) {
      return;
    }

    final selection = widget.listenable.value?.normalized;
    final path = widget.node.path;

    // the current path is in the selection
    if (selection != null && path.inSelection(selection)) {
      if (widget.supportTypes.contains(BlockSelectionType.block) &&
          context.read<EditorState>().selectionType == SelectionType.block) {
        if (!path.inSelection(selection, isSameDepth: true)) {
          if (prevBlockRect != null) {
            setState(() {
              prevBlockRect = null;
              prevCursorRect = null;
              prevSelectionRects = null;
            });
          }
        } else {
          final rect = widget.delegate.getBlockRect();
          if (prevBlockRect != rect) {
            setState(() {
              prevBlockRect = rect;
              prevCursorRect = null;
              prevSelectionRects = null;
            });
          }
        }
      } else if (widget.supportTypes.contains(BlockSelectionType.cursor) &&
          selection.isCollapsed) {
        final rect = widget.delegate.getCursorRectInPosition(selection.start);
        if (rect != prevCursorRect) {
          setState(() {
            prevCursorRect = rect;
            prevBlockRect = null;
            prevSelectionRects = null;
          });
        }
      } else if (widget.supportTypes.contains(BlockSelectionType.selection)) {
        final mid = (selection.start.offset + selection.end.offset) ~/ 2;
        final currentSection = widget.node.sections?.firstWhereOrNull(
          (section) => section.selection.end.offset >= mid,
        );

        final selectionWithouthPath = currentSection?.selection;

        if (selectionWithouthPath != null &&
            prevSection != selectionWithouthPath) {
          final selectionWithPath = selectionWithouthPath.copyWith(
            start: selectionWithouthPath.start.copyWith(path: widget.node.path),
            end: selectionWithouthPath.end.copyWith(path: widget.node.path),
          );
          final currentSectionRects = widget.delegate.getRectsInSelection(
            selectionWithPath,
          );
          prevSection = selectionWithouthPath;
          setState(() {
            sectionRects = currentSectionRects;
          });
        }

        final rects = widget.delegate.getRectsInSelection(selection);
        if (!_rectListEq(rects, prevSelectionRects)) {
          setState(() {
            prevSelectionRects = rects;
            prevCursorRect = null;
            prevBlockRect = null;
          });
        }
      }
    } else if (prevBlockRect != null ||
        prevSelectionRects != null ||
        prevCursorRect != null) {
      setState(() {
        prevBlockRect = null;
        prevSelectionRects = null;
        prevCursorRect = null;
      });
    }
  }

  void _clearCursorRect() {
    prevCursorRect = null;
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
