import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/base_component/selection/block_highlight_area.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderStack;

class BlockSelectionContainer extends StatelessWidget {
  const BlockSelectionContainer({
    super.key,
    required this.node,
    required this.delegate,
    required this.listenable,
    required this.highlight,
    this.remoteSelection,
    this.cursorColor = Colors.black,
    this.selectionColor = Colors.blue,
    this.highlightColor = Colors.blue,
    required this.highlightAreaColor,
    this.blockColor = Colors.blue,
    this.supportTypes = const [
      BlockSelectionType.cursor,
      BlockSelectionType.selection,
    ],
    this.selectionAboveBlock = false,
    required this.child,
  });

  // get the cursor rect, selection rects or block rect from the delegate
  final SelectableMixin delegate;

  // get the selection from the listenable
  final ValueListenable<Selection?> listenable;

  // get the highlight from the editor state
  final ValueListenable<Selection?> highlight;

  // remote selection
  final ValueListenable<List<RemoteSelection>>? remoteSelection;

  // the color of the cursor
  final Color cursorColor;

  // the color of the selection
  final Color selectionColor;

  // the color of the highlight
  final Color highlightColor;

  // the color of the highlight area
  final Color highlightAreaColor;

  // the color of the background of the block
  final Color blockColor;

  // the node of the block
  final Node node;

  final List<BlockSelectionType> supportTypes;

  // the selection area should above the block component
  final bool selectionAboveBlock;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SelectionGeometry(
      alignment: Directionality.of(context) == TextDirection.ltr
          ? AlignmentDirectional.topStart
          : AlignmentDirectional.topEnd,
      builder: (context, geometryChanges) {
        final blockSelectionArea = BlockSelectionArea(
          node: node,
          delegate: delegate,
          listenable: listenable,
          geometryChanges: geometryChanges,
          cursorColor: cursorColor,
          selectionColor: selectionColor,
          blockColor: blockColor,
          supportTypes: supportTypes
              .where((element) => element != BlockSelectionType.cursor)
              .toList(),
        );

        final blockHighlightArea = BlockHighlightArea(
          node: node,
          delegate: delegate,
          listenable: highlight,
          geometryChanges: geometryChanges,
          highlightColor: highlightColor,
          highlightAreaColor: highlightAreaColor,
          cursorColor: cursorColor,
          blockColor: blockColor,
          supportTypes: supportTypes
              .where((element) => element != BlockSelectionType.cursor)
              .toList(),
        );

        return [
          if (remoteSelection != null)
            RemoteBlockSelectionsArea(
              node: node,
              delegate: delegate,
              remoteSelections: remoteSelection!,
              supportTypes: supportTypes
                  .where((element) => element != BlockSelectionType.cursor)
                  .toList(),
            ),
          // block selection or selection area
          if (!selectionAboveBlock) blockSelectionArea,
          blockHighlightArea,

          child,

          // block selection or selection area
          if (selectionAboveBlock) blockSelectionArea,

          // cursor
          // remote cursor
          if (supportTypes.contains(BlockSelectionType.cursor) &&
              remoteSelection != null)
            RemoteBlockSelectionsArea(
              node: node,
              delegate: delegate,
              remoteSelections: remoteSelection!,
              supportTypes: const [BlockSelectionType.cursor],
            ),
          // local cursor
          if (supportTypes.contains(BlockSelectionType.cursor))
            BlockSelectionArea(
              node: node,
              delegate: delegate,
              listenable: listenable,
              geometryChanges: geometryChanges,
              cursorColor: cursorColor,
              selectionColor: selectionColor,
              blockColor: blockColor,
              supportTypes: const [BlockSelectionType.cursor],
            ),
        ];
      },
    );
  }
}

// Keep geometry invalidation local to this block. Changing a parent widget or
// laying out text invalidates its overlays without a global frame callback loop.
class _SelectionGeometry extends StatefulWidget {
  const _SelectionGeometry({required this.alignment, required this.builder});

  final AlignmentGeometry alignment;
  final List<Widget> Function(BuildContext context, Listenable geometryChanges)
  builder;

  @override
  State<_SelectionGeometry> createState() => _SelectionGeometryState();
}

class _SelectionGeometryState extends State<_SelectionGeometry> {
  final _geometryChanges = _SelectionGeometryNotifier();

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(
      _geometryChanges.invalidate,
    );
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(
      _geometryChanges.invalidate,
    );
    _geometryChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SelectionLayoutStack(
    alignment: widget.alignment,
    onLayout: _geometryChanges.invalidate,
    children: widget.builder(context, _geometryChanges),
  );
}

// Observe the stack itself: a proxy outside a tightly constrained stack can
// miss child layout work when that stack is a relayout boundary.
class _SelectionLayoutStack extends Stack {
  const _SelectionLayoutStack({
    required super.alignment,
    required this.onLayout,
    required super.children,
  }) : super(clipBehavior: Clip.none);

  final VoidCallback onLayout;

  @override
  RenderStack createRenderObject(BuildContext context) =>
      _RenderSelectionLayoutStack(
        onLayout: onLayout,
        alignment: alignment,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSelectionLayoutStack renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.onLayout = onLayout;
  }
}

class _RenderSelectionLayoutStack extends RenderStack {
  _RenderSelectionLayoutStack({
    required this.onLayout,
    required super.alignment,
    required super.textDirection,
  }) : super(clipBehavior: Clip.none);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}

class _SelectionGeometryNotifier extends ChangeNotifier {
  void invalidate() => notifyListeners();
}
