import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class ParagraphBlockKeys {
  ParagraphBlockKeys._();

  static const String type = 'paragraph';

  static const String delta = blockComponentDelta;

  static const String backgroundColor = blockComponentBackgroundColor;

  static const String textDirection = blockComponentTextDirection;
}

Node paragraphNode({
  String? text,
  Delta? delta,
  String? textDirection,
  Attributes? attributes,
  Iterable<Node> children = const [],
}) {
  return Node(
    type: ParagraphBlockKeys.type,
    attributes: {
      ParagraphBlockKeys.delta: (delta ?? (Delta()..insert(text ?? '')))
          .toJson(),
      ...?attributes,
      ParagraphBlockKeys.textDirection: ?textDirection,
    },
    children: children,
  );
}

typedef ShowPlaceholder = bool Function(EditorState editorState, Node node);

class ParagraphBlockComponentBuilder extends BlockComponentBuilder {
  ParagraphBlockComponentBuilder({super.configuration, this.showPlaceholder});

  final ShowPlaceholder? showPlaceholder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;

    return ParagraphBlockComponentWidget(
      node: node,
      key: node.key,
      configuration: configuration,
      showActions: showActions(node),
      showPlaceholder: showPlaceholder,
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class ParagraphBlockComponentWidget extends BlockComponentStatefulWidget {
  const ParagraphBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.showPlaceholder,
  });

  final ShowPlaceholder? showPlaceholder;

  @override
  State<ParagraphBlockComponentWidget> createState() =>
      _ParagraphBlockComponentWidgetState();
}

class _ParagraphBlockComponentWidgetState
    extends State<ParagraphBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: ParagraphBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  bool _showPlaceholder = false;

  @override
  void initState() {
    super.initState();
    editorState.selectionNotifier.addListener(_onSelectionChange);

    _onSelectionChange();
  }

  @override
  void dispose() {
    editorState.selectionNotifier.removeListener(_onSelectionChange);

    super.dispose();
  }

  void _onSelectionChange() {
    final selection = editorState.selection;

    if (widget.showPlaceholder != null) {
      setState(() {
        _showPlaceholder = widget.showPlaceholder!(editorState, node);
      });
    } else {
      final showPlaceholder =
          selection != null &&
          (selection.isSingle && selection.start.path.equals(node.path));
      if (showPlaceholder != _showPlaceholder) {
        setState(() => _showPlaceholder = showPlaceholder);
      }
    }
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          AppFlowyRichText(
            key: forwardKey,
            delegate: this,
            node: widget.node,
            editorState: editorState,
            textAlign: alignment?.toTextAlign ?? textAlign,
            placeholderText: _showPlaceholder ? placeholderText : ' ',
            textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
              textStyleWithTextSpan(textSpan: textSpan),
            ),
            placeholderTextSpanDecorator: (textSpan) =>
                textSpan.updateTextStyle(
                  placeholderTextStyleWithTextSpan(textSpan: textSpan),
                ),
            textDirection: textDirection,
            cursorColor: editorState.editorStyle.cursorColor,
            selectionColor: editorState.editorStyle.selectionColor,
            highlightColor: editorState.editorStyle.highlightColor,
            highlightAreaColor: editorState.editorStyle.highlightAreaColor,
            cursorWidth: editorState.editorStyle.cursorWidth,
          ),
        ],
      ),
    );

    child = Container(
      key: blockComponentKey,
      decoration: withBackgroundColor ? decoration : null,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      highlight: editorState.highlightNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      highlightColor: editorState.editorStyle.highlightColor,
      highlightAreaColor: editorState.editorStyle.highlightAreaColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }
}

// mixin IsNodeHighlightedMixin<T extends BlockComponentStatefulWidget>
//     on
//         State<T>,
//         BlockComponentBackgroundColorMixin,
//         BlockComponentTextDirectionMixin {
//   bool isNodeHighlighted = false;

//   @override
//   void initState() {
//     super.initState();
//     final editorState = Provider.of<EditorState>(context, listen: false);
//     editorState.highlightedNodeIdNotifier
//         .addListener(_onHighlightedNodeIdChange);

//     isNodeHighlighted = editorState.highlightedNodeId == node.id;
//   }

//   void _onHighlightedNodeIdChange() {
//     final editorState = Provider.of<EditorState>(context, listen: false);

//     final highlightedNodeId = editorState.highlightedNodeId;
//     if (highlightedNodeId == node.id) {
//       if (!isNodeHighlighted) {
//         setState(() {
//           isNodeHighlighted = true;
//         });
//       }
//     } else {
//       if (isNodeHighlighted) {
//         setState(() {
//           isNodeHighlighted = false;
//         });
//       }
//     }
//   }

//   @override
//   void dispose() {
//     editorState.highlightedNodeIdNotifier
//         .removeListener(_onHighlightedNodeIdChange);
//     super.dispose();
//   }
// }
