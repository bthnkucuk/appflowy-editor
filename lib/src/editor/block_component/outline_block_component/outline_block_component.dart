import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 1:1 port of AppFlowy's `outline` block (auto table-of-contents) from
/// `appflowy_flutter/lib/plugins/document/presentation/editor_plugins/outline/outline_block_component.dart`.
///
/// Adaptations vs the upstream app-layer original:
///  - `flutter_bloc` / `flowy_infra_ui` imports dropped (we're a library).
///  - `LocaleKeys.*` strings replaced with English literals; consumers
///    can override by passing a custom `BlockComponentConfiguration`.
///  - `FlowyButton`, `HSpace`, `VSpace` swapped for stock `InkWell` and
///    `SizedBox`.
///  - `editorScrollController.itemScrollController.jumpTo(index, alignment)`
///    swapped for `editorState.scrollService?.jumpTo(index)` — our
///    scroll service doesn't take an alignment, but addresses the same
///    top-level index.
///  - Mention spans dropped (we don't ship a mention block); each delta
///    insert renders as a plain `TextSpan`.
///  - Toggle-list heading nodes dropped (we don't ship a toggle block
///    yet); `_availableBlockTypes` is just `HeadingBlockKeys.type`.
class OutlineBlockKeys {
  const OutlineBlockKeys._();

  static const String type = 'outline';
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String depth = 'depth';
}

Node outlineBlockNode() {
  return Node(type: OutlineBlockKeys.type);
}

enum _OutlineBlockStatus { noHeadings, noMatchHeadings, success }

final _availableBlockTypes = [HeadingBlockKeys.type];

class OutlineBlockComponentBuilder extends BlockComponentBuilder {
  OutlineBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return OutlineBlockWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class OutlineBlockWidget extends BlockComponentStatefulWidget {
  const OutlineBlockWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<OutlineBlockWidget> createState() => _OutlineBlockWidgetState();
}

class _OutlineBlockWidgetState extends State<OutlineBlockWidget>
    with
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        SelectableMixin {
  // Maximum heading level the outline can render. Matches AppFlowy.
  static const maxVisibleDepth = 6;

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  late EditorState editorState = context.read<EditorState>();
  late Stream<EditorTransactionValue> stream = editorState.transactionStream;

  final GlobalKey blockComponentKey =
      GlobalKey(debugLabel: OutlineBlockKeys.type);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EditorTransactionValue>(
      stream: stream,
      builder: (context, snapshot) {
        Widget child = _buildOutlineBlock();

        child = BlockSelectionContainer(
          node: node,
          delegate: this,
          listenable: editorState.selectionNotifier,
          // Required by our BlockSelectionContainer signature even
          // though upstream doesn't pass them — pulled straight from
          // editor state so we don't drift from the highlight contract.
          highlight: editorState.highlightNotifier,
          highlightAreaColor: editorState.editorStyle.highlightAreaColor,
          remoteSelection: editorState.remoteSelections,
          blockColor: editorState.editorStyle.selectionColor,
          selectionAboveBlock: true,
          supportTypes: const [BlockSelectionType.block],
          child: child,
        );

        if (widget.showActions && widget.actionBuilder != null) {
          child = BlockComponentActionWrapper(
            node: widget.node,
            actionBuilder: widget.actionBuilder!,
            actionTrailingBuilder: widget.actionTrailingBuilder,
            child: child,
          );
        }

        return child;
      },
    );
  }

  Widget _buildOutlineBlock() {
    final (status, headings) = getHeadingNodes();

    Widget child;

    switch (status) {
      case _OutlineBlockStatus.noHeadings:
        child = Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Add a heading to populate the outline',
            style: configuration.placeholderTextStyle(node),
          ),
        );
      case _OutlineBlockStatus.noMatchHeadings:
        child = Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No headings match the depth filter',
            style: configuration.placeholderTextStyle(node),
          ),
        );
      case _OutlineBlockStatus.success:
        final children = headings
            .map(
              (e) => Container(
                padding: const EdgeInsets.only(bottom: 4.0),
                width: double.infinity,
                child: OutlineItemWidget(node: e),
              ),
            )
            .toList();
        child = Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: Column(children: children),
        );
    }

    return Container(
      key: blockComponentKey,
      constraints: const BoxConstraints(minHeight: 40.0),
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 5.0),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
          color: (decoration as BoxDecoration?)?.color,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Table of contents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            child,
          ],
        ),
      ),
    );
  }

  (_OutlineBlockStatus, Iterable<Node>) getHeadingNodes() {
    final nodes = NodeIterator(
      document: editorState.document,
      startNode: editorState.document.root,
    ).toList();
    final level = node.attributes[OutlineBlockKeys.depth] ?? maxVisibleDepth;
    var headings = nodes.where(_isHeadingNode);
    if (headings.isEmpty) {
      return (_OutlineBlockStatus.noHeadings, []);
    }
    headings = headings.where(
      (e) =>
          e.type == HeadingBlockKeys.type &&
          e.attributes[HeadingBlockKeys.level] <= level,
    );
    if (headings.isEmpty) {
      return (_OutlineBlockStatus.noMatchHeadings, []);
    }
    return (_OutlineBlockStatus.success, headings);
  }

  bool _isHeadingNode(Node node) {
    return node.type == HeadingBlockKeys.type &&
        node.delta?.isNotEmpty == true;
  }

  // SelectableMixin — outline node has no caret. Treats itself as an
  // atomic block (like divider).

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    return getRectsInSelection(Selection.invalid()).first;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    return getRectsInSelection(
      Selection.collapsed(position),
      shiftWithBaseOffset: shiftWithBaseOffset,
    ).firstOrNull;
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final box = _renderBox;
    if (box == null) return [];
    return [Offset.zero & box.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox!.localToGlobal(offset);

  @override
  TextDirection textDirection() => TextDirection.ltr;
}

class OutlineItemWidget extends StatelessWidget {
  OutlineItemWidget({super.key, required this.node}) {
    assert(_availableBlockTypes.contains(node.type));
  }

  final Node node;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => scrollToBlock(context),
      child: Row(
        children: [
          SizedBox(width: node.leftIndent),
          Flexible(child: buildOutlineItemWidget(context)),
        ],
      ),
    );
  }

  void scrollToBlock(BuildContext context) {
    final editorState = context.read<EditorState>();
    editorState.scrollService?.jumpTo(node.path.first);
    editorState.selection = Selection.collapsed(
      Position(path: node.path, offset: node.delta?.length ?? 0),
    );
  }

  Widget buildOutlineItemWidget(BuildContext context) {
    final editorState = context.read<EditorState>();
    final textStyle = editorState.editorStyle.textStyleConfiguration;
    final style = textStyle.href.combine(textStyle.text);

    final textInserted = node.delta?.whereType<TextInsert>();
    if (textInserted == null) {
      return const SizedBox.shrink();
    }

    final children = <InlineSpan>[];
    for (final e in textInserted) {
      children.add(TextSpan(text: e.text, style: style));
    }

    return IgnorePointer(
      child: Text.rich(
        TextSpan(children: children, style: style),
      ),
    );
  }
}

extension on Node {
  double get leftIndent {
    assert(_availableBlockTypes.contains(type));

    if (!_availableBlockTypes.contains(type)) {
      return 0.0;
    }

    final level = attributes[HeadingBlockKeys.level];
    if (level != null) {
      return (level - 1) * 15.0;
    }
    return 0.0;
  }
}
