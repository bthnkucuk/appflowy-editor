import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class TodoListBlockKeys {
  const TodoListBlockKeys._();

  static const String type = 'todo_list';

  /// The checked data of a todo list block.
  ///
  /// The value is a boolean.
  static const String checked = 'checked';

  static const String delta = blockComponentDelta;

  static const String backgroundColor = blockComponentBackgroundColor;

  static const String textDirection = blockComponentTextDirection;
}

Node todoListNode({
  required bool checked,
  String? text,
  Delta? delta,
  String? textDirection,
  Attributes? attributes,
  Iterable<Node>? children,
}) {
  return Node(
    type: TodoListBlockKeys.type,
    attributes: {
      TodoListBlockKeys.checked: checked,
      TodoListBlockKeys.delta: (delta ?? (Delta()..insert(text ?? '')))
          .toJson(),
      ...?attributes,
      TodoListBlockKeys.textDirection: ?textDirection,
    },
    children: children ?? [],
  );
}

typedef TodoListIconBuilder =
    Widget Function(BuildContext context, Node node, VoidCallback onCheck);

class TodoListBlockComponentBuilder extends BlockComponentBuilder {
  TodoListBlockComponentBuilder({
    super.configuration,
    this.textStyleBuilder,
    this.iconBuilder,
    this.toggleChildrenTriggers,
  });

  /// The text style of the todo list block.
  final TextStyle Function(bool checked)? textStyleBuilder;

  final TodoListIconBuilder? iconBuilder;

  final List<LogicalKeyboardKey>? toggleChildrenTriggers;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;

    return TodoListBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      textStyleBuilder: textStyleBuilder,
      iconBuilder: iconBuilder,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
      toggleChildrenTriggers: toggleChildrenTriggers,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class TodoListBlockComponentWidget extends BlockComponentStatefulWidget {
  const TodoListBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.textStyleBuilder,
    this.iconBuilder,
    this.toggleChildrenTriggers,
  });

  final TextStyle Function(bool checked)? textStyleBuilder;
  final TodoListIconBuilder? iconBuilder;
  final List<LogicalKeyboardKey>? toggleChildrenTriggers;

  @override
  State<TodoListBlockComponentWidget> createState() =>
      _TodoListBlockComponentWidgetState();
}

class _TodoListBlockComponentWidgetState
    extends State<TodoListBlockComponentWidget>
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
    debugLabel: TodoListBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  bool get checked =>
      widget.node.attributes[TodoListBlockKeys.checked] ?? false;

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget child = SizedBox(
      width: double.infinity,
      child: Align(
        alignment:
            alignment ??
            (textDirection == TextDirection.ltr
                ? Alignment.centerLeft
                : Alignment.centerRight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          textDirection: textDirection,
          children: [
            widget.iconBuilder != null
                ? widget.iconBuilder!(context, node, checkOrUncheck)
                : _TodoListIcon(checked: checked, onTap: checkOrUncheck),
            Flexible(
              child: AppFlowyRichText(
                key: forwardKey,
                delegate: this,
                node: widget.node,
                editorState: editorState,
                textAlign: alignment?.toTextAlign ?? textAlign,
                placeholderText: placeholderText,
                textDirection: textDirection,
                textSpanDecorator: (textSpan) {
                  return textSpan
                      .updateTextStyle(textStyleWithTextSpan())
                      .updateTextStyle(
                        widget.textStyleBuilder?.call(checked) ??
                            defaultTextStyle(),
                      );
                },
                placeholderTextSpanDecorator: (textSpan) =>
                    textSpan.updateTextStyle(
                      placeholderTextStyleWithTextSpan(textSpan: textSpan),
                    ),
                cursorColor: editorState.editorStyle.cursorColor,
                selectionColor: editorState.editorStyle.selectionColor,
                highlightColor: editorState.editorStyle.highlightColor,
                highlightAreaColor: editorState.editorStyle.highlightAreaColor,
                cursorWidth: editorState.editorStyle.cursorWidth,
              ),
            ),
          ],
        ),
      ),
    );

    child = Container(
      decoration: withBackgroundColor ? decoration : null,
      key: blockComponentKey,
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

  void checkOrUncheck() {
    final transaction = editorState.transaction
      ..updateNode(widget.node, {TodoListBlockKeys.checked: !checked});

    if (widget.toggleChildrenTriggers != null &&
        HardwareKeyboard.instance.logicalKeysPressed.any(
          (element) => widget.toggleChildrenTriggers!.contains(element),
        )) {
      checkOrUncheckChildren(!checked, widget.node);
    }

    editorState.apply(transaction, withUpdateSelection: false);
  }

  void checkOrUncheckChildren(bool checked, Node node) {
    for (final child in node.children) {
      if (child.children.isNotEmpty) {
        checkOrUncheckChildren(checked, child);
      }

      if (child.type == TodoListBlockKeys.type) {
        final transaction = editorState.transaction
          ..updateNode(child, {TodoListBlockKeys.checked: checked});

        editorState.apply(transaction);
      }
    }
  }

  TextStyle? defaultTextStyle() {
    if (!checked) {
      return null;
    }

    return TextStyle(
      decoration: TextDecoration.lineThrough,
      color: Colors.grey.shade400,
    );
  }
}

class _TodoListIcon extends StatelessWidget {
  const _TodoListIcon({required this.onTap, required this.checked});

  final VoidCallback onTap;
  final bool checked;

  // The icon used to be a hardcoded 22-px square with min constraints
  // multiplied by `textScaleFactor`. That worked when the text style was
  // also tied to `textScaleFactor` but ignores per-document body font
  // sizes set via `textStyleConfiguration.text.fontSize`. Now the icon
  // scales off the body font size directly — visually the checkmark
  // tracks the surrounding paragraph at any size.
  //
  // Ratio chosen from the pre-existing 22 / 14 (icon / default body) ≈
  // 1.57. `_iconLineHeight` matches the line height of the first text
  // line so the icon visually centers with that line instead of
  // floating above larger text.
  static const double _iconToFontRatio = 1.4;
  static const double _lineHeight = 1.5;

  @override
  Widget build(BuildContext context) {
    final style = context.read<EditorState>().editorStyle;
    final baseFontSize =
        style.textStyleConfiguration.text.fontSize ?? 14.0;
    final scaled = baseFontSize * style.textScaleFactor;
    final iconSize = scaled * _iconToFontRatio;
    final lineHeight = scaled * _lineHeight;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: SizedBox(
            // Box height matches the surrounding text's first-line
            // height; `Center` then vertically aligns the icon with the
            // text baseline rather than the top-of-line.
            height: lineHeight,
            child: Center(
              child: ToolbarIcon(
                size: iconSize,
                afMobileIcons: checked
                    ? ToolbarIcons.check
                    : ToolbarIcons.uncheck,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
