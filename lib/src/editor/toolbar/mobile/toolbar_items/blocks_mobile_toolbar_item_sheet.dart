import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [blocksMobileToolbarItem]. Opens the heading/list/
/// todo/quote grid in a [StupidSimpleSheetRoute] instead of the inline
/// keyboard-height menu used by MobileToolbarV2.
final blocksMobileToolbarItemSheet = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => ToolbarIcon(
    afMobileIcons: ToolbarIcons.list,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) {
    final selection = editorState.selection;
    if (selection == null) return;

    editorState.keyboardService?.closeKeyboard();
    editorState.updateSelectionWithReason(
      selection,
      extraInfo: {
        selectionExtraInfoDisableMobileToolbarKey: true,
        selectionExtraInfoDisableFloatingToolbar: true,
        selectionExtraInfoDoNotAttachTextService: true,
      },
    );
    keepEditorFocusNotifier.increase();

    Navigator.of(context)
        .push(
          StupidSimpleSheetRoute<void>(
            barrierColor: Colors.transparent,
            originateAboveBottomViewInset: true,
            child: MobileToolbarTheme(
              child: MobileToolbarItemMenu(
                editorState: editorState,
                itemMenuBuilder: () => Padding(
                  padding: EdgeInsets.only(bottom: kBottomNavigationBarHeight),
                  child: _SheetBlocksMenu(editorState, selection),
                ),
              ),
            ),
          ),
        )
        .then((_) {
          editorState.updateSelectionWithReason(
            selection,
            extraInfo: {selectionExtraInfoDisableFloatingToolbar: true},
          );
          editorState.keyboardService?.enableKeyBoard(selection);
        });
  },
);

class _SheetBlocksMenu extends StatefulWidget {
  const _SheetBlocksMenu(this.editorState, this.selection);

  final EditorState editorState;
  final Selection selection;

  @override
  State<_SheetBlocksMenu> createState() => _SheetBlocksMenuState();
}

class _SheetBlocksMenuState extends State<_SheetBlocksMenu> {
  VoidCallback? _selectionWatcher;

  @override
  void initState() {
    super.initState();
    _selectionWatcher = () {
      if (!mounted) return;
      final live = widget.editorState.selection;
      if (live != widget.selection) {
        widget.editorState.updateSelectionWithReason(
          widget.selection,
          extraInfo: {
            selectionExtraInfoDisableMobileToolbarKey: true,
            selectionExtraInfoDisableFloatingToolbar: true,
            selectionExtraInfoDoNotAttachTextService: true,
          },
        );
      }
    };
    widget.editorState.selectionNotifier.addListener(_selectionWatcher!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectionWatcher!());
  }

  @override
  void dispose() {
    if (_selectionWatcher != null) {
      widget.editorState.selectionNotifier.removeListener(_selectionWatcher!);
    }
    super.dispose();
  }

  final _lists = [
    _SheetListUnit(
      icon: ToolbarIcons.h1,
      label: AppFlowyEditorL10n.current.mobileHeading1,
      name: HeadingBlockKeys.type,
      level: 1,
    ),
    _SheetListUnit(
      icon: ToolbarIcons.h2,
      label: AppFlowyEditorL10n.current.mobileHeading2,
      name: HeadingBlockKeys.type,
      level: 2,
    ),
    _SheetListUnit(
      icon: ToolbarIcons.h3,
      label: AppFlowyEditorL10n.current.mobileHeading3,
      name: HeadingBlockKeys.type,
      level: 3,
    ),
    _SheetListUnit(
      icon: ToolbarIcons.bulletedList,
      label: AppFlowyEditorL10n.current.bulletedList,
      name: BulletedListBlockKeys.type,
    ),
    _SheetListUnit(
      icon: ToolbarIcons.numberedList,
      label: AppFlowyEditorL10n.current.numberedList,
      name: NumberedListBlockKeys.type,
    ),
    _SheetListUnit(
      icon: ToolbarIcons.checkbox,
      label: AppFlowyEditorL10n.current.checkbox,
      name: TodoListBlockKeys.type,
    ),
    _SheetListUnit(
      icon: ToolbarIcons.quote,
      label: AppFlowyEditorL10n.current.quote,
      name: QuoteBlockKeys.type,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final children = _lists.map((list) {
      final node = widget.editorState.getNodeAtPath(
        widget.selection.start.path,
      )!;

      final isSelected =
          node.type == list.name &&
          (list.level == null ||
              node.attributes[HeadingBlockKeys.level] == list.level);

      return MobileToolbarItemMenuBtn(
        icon: ToolbarIcon(
          afMobileIcons: list.icon,
          color: MobileToolbarTheme.of(context).iconColor,
        ),
        label: Text(list.label),
        isSelected: isSelected,
        onPressed: () {
          setState(() {
            widget.editorState.formatNode(
              widget.selection,
              (node) => node.copyWith(
                type: isSelected ? ParagraphBlockKeys.type : list.name,
                attributes: {
                  ParagraphBlockKeys.delta: (node.delta ?? Delta()).toJson(),
                  blockComponentBackgroundColor:
                      node.attributes[blockComponentBackgroundColor],
                  if (!isSelected && list.name == TodoListBlockKeys.type)
                    TodoListBlockKeys.checked: false,
                  if (!isSelected && list.name == HeadingBlockKeys.type)
                    HeadingBlockKeys.level: list.level,
                },
              ),
              selectionExtraInfo: {
                selectionExtraInfoDoNotAttachTextService: true,
              },
            );
          });
        },
      );
    }).toList();

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: buildMobileToolbarMenuGridDelegate(
        mobileToolbarStyle: style,
        crossAxisCount: 2,
      ),
      children: children,
    );
  }
}

class _SheetListUnit {
  final ToolbarIcons icon;
  final String label;
  final String name;
  final int? level;

  _SheetListUnit({
    required this.icon,
    required this.label,
    required this.name,
    this.level,
  });
}
