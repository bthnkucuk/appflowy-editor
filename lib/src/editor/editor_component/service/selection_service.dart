import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Data passed to a custom [DragAreaBuilder] so the builder can render
/// the drop indicator without having to re-derive the geometry from
/// `targetNode.selectable.getBlockRect()` and other internals.
///
/// Two extras over the bare `(targetNode, dragOffset)` pair:
///
/// - [isCloserToStart]: which side of the target block the cursor is
///   closer to. Same predicate the editor uses to compute the actual
///   drop path, so a builder that reads it stays in lockstep with
///   where the dropped node will actually land.
/// - [targetBlockRect]: the target block's full **global screen** rect
///   (top-left + size). Derived from the block's `RenderPadding` and
///   resolved once, before any layout drift that might happen between
///   the comparison call and the overlay's deferred build. Builders
///   read `top`/`bottom` for the horizontal indicator line, or full
///   bounds for richer drop UIs (e.g. left/right insertion).
///
/// `targetBlockRect` is intentionally NOT derived from
/// `selectable.getBlockRect()` — that returns
/// `Offset.zero & (parentSize - childOffset)` for selection-painting
/// purposes, which lands the bottom edge INSIDE the block when the
/// inner BlockSelectionContainer has a non-zero `childOffsetY` (some
/// heading blocks have ~8px). `targetBlockRect.bottom` here is the
/// `RenderPadding`'s actual visual bottom edge.
class DragAreaBuilderData {
  DragAreaBuilderData({
    required this.targetNode,
    required this.dragOffset,
    required this.isCloserToStart,
    required this.targetBlockRect,
  });

  /// The block component the cursor is currently hovering over.
  final Node targetNode;

  /// The cursor's global screen position.
  final Offset dragOffset;

  /// `true` when the cursor is closer to [targetBlockRect]'s top edge
  /// than its bottom edge — i.e. the dropped node will be inserted
  /// BEFORE [targetNode]. `false` for AFTER. Same predicate the editor
  /// uses to compute the drop path; reading this keeps a builder in
  /// lockstep with the actual insertion.
  final bool isCloserToStart;

  /// The target block's full screen-coordinate rect (top-left + size).
  /// Builders typically read `top` for "drop before" indicator Y and
  /// `bottom` for "drop after" Y. Use `left`/`right`/`size.width` for
  /// horizontal layout decisions.
  final Rect targetBlockRect;
}

typedef DragAreaBuilder = Widget Function(BuildContext context, DragAreaBuilderData data);

typedef DragTargetNodeInterceptor = Node Function(BuildContext context, Node node);

/// [AppFlowySelectionService] is responsible for processing
/// the [Selection] changes and updates.
///
/// Usually, this service can be obtained by the following code.
/// ```dart
/// final selectionService = editorState.selectionService;
///
/// /** get current selection value*/
/// final selection = selectionService.currentSelection.value;
///
/// /** get current selected nodes*/
/// final nodes = selectionService.currentSelectedNodes;
/// ```
///
abstract class AppFlowySelectionService {
  /// The current [Selection] in editor.
  ///
  /// The value is null if there is no nodes are selected.
  ValueNotifier<Selection?> get currentSelection;

  /// The current selected [Node]s in editor.
  ///
  /// The order of the result is determined according to the [currentSelection].
  /// The result are ordered from back to front if the selection is forward.
  /// The result are ordered from front to back if the selection is backward.
  ///
  /// For example, Here is an array of selected nodes, `[n1, n2, n3]`.
  /// The result will be `[n3, n2, n1]` if the selection is forward,
  ///   and `[n1, n2, n3]` if the selection is backward.
  ///
  /// Returns empty result if there is no nodes are selected.
  List<Node> get currentSelectedNodes;

  /// Updates the selection.
  ///
  /// The editor will update selection area and toolbar area
  /// if the [selection] is not collapsed,
  /// otherwise, will update the cursor area.
  void updateSelection(Selection? selection);

  /// Clears the selection area, cursor area and the popup list area.
  void clearSelection();

  /// Clears the cursor area.
  void clearCursor();

  /// Returns the [Node] containing to the [offset].
  ///
  /// [offset] must be under the global coordinate system.
  Node? getNodeInOffset(Offset offset);

  /// Returns the [Position] closest to the [offset].
  ///
  /// Returns null if there is no nodes are selected.
  ///
  /// [offset] must be under the global coordinate system.
  Position? getPositionInOffset(Offset offset);

  /// The current selection areas's rect in editor.
  List<Rect> get selectionRects;

  void registerGestureInterceptor(SelectionGestureInterceptor interceptor);

  void unregisterGestureInterceptor(String key);

  /// The functions below are only for mobile.
  Selection? onPanStart(DragStartDetails details, MobileSelectionDragMode mode);

  Selection? onPanUpdate(DragUpdateDetails details, MobileSelectionDragMode mode);

  void onPanEnd(DragEndDetails details, MobileSelectionDragMode mode);

  /// Draws a horizontal line between the nearest nodes to the [offset].
  ///
  /// The [offset] must be under the global coordinate system.
  ///
  /// Should call [removeDropTarget] to remove the line once drop is done.
  ///
  /// If [builder] is provided, the line will be drawn by [builder].
  /// Otherwise, the line will be drawn by default [DropTargetStyle].
  ///
  /// If [interceptor] is provided, the node will be intercepted by [interceptor].
  void renderDropTargetForOffset(Offset offset, {DragAreaBuilder? builder, DragTargetNodeInterceptor? interceptor});

  /// Removes the horizontal line drawn by [renderDropTargetForOffset].
  ///
  void removeDropTarget();

  /// Returns the [DropTargetRenderData] for the [offset].
  ///
  DropTargetRenderData? getDropTargetRenderData(Offset offset, {DragTargetNodeInterceptor? interceptor});
}

class SelectionGestureInterceptor {
  SelectionGestureInterceptor({
    required this.key,
    this.canTap,
    this.canDoubleTap,
    this.canTripleTap,
    this.canPanStart,
    this.canPanUpdate,
    this.canPanEnd,
  });

  final String key;

  bool Function(TapDownDetails details)? canTap;
  bool Function(TapDownDetails details)? canDoubleTap;
  bool Function(TapDownDetails details)? canTripleTap;
  bool Function(DragStartDetails details)? canPanStart;
  bool Function(DragUpdateDetails details)? canPanUpdate;
  bool Function(DragEndDetails details)? canPanEnd;
}

/// Data returned when calling [AppFlowySelectionService.getDropTargetRenderData]
///
/// Includes the position (path) which the drop target is rendered for
/// and the [Node] which the cursor is directly hovering over.
///
class DropTargetRenderData {
  const DropTargetRenderData({this.dropPath, this.cursorNode});

  /// The path which the drop is rendered for,
  /// this is the position in which any content should be
  /// inserted into.
  ///
  final List<int>? dropPath;

  /// The [Node] which the cursor is directly hovering over,
  /// this node __might__ be at same position as [dropPath] but might also
  /// be another [Node] depending on distance to top/bottom of the [Node] to the
  /// cursors offset.
  ///
  /// This is useful in case you want to cancel or pause the drop
  /// for specific [Node]s, in case they as example implement their
  /// own drop logic.
  ///
  final Node? cursorNode;

  @override
  String toString() {
    return 'DropTargetRenderData(dropPath: $dropPath, cursorNode: $cursorNode)';
  }
}
