import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [listMobileToolbarItem]. Opens the
/// bulleted/numbered choice in a [StupidSimpleSheetRoute] instead of the
/// inline keyboard-height menu used by MobileToolbarV2.
final listMobileToolbarItemSheet = MobileToolbarItem.action(
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
                  child: _SheetListMenu(editorState, selection),
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

class _SheetListMenu extends StatefulWidget {
  const _SheetListMenu(this.editorState, this.selection);

  final EditorState editorState;
  final Selection selection;

  @override
  State<_SheetListMenu> createState() => _SheetListMenuState();
}

class _SheetListMenuState extends State<_SheetListMenu> {
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
    ListUnit(
      icon: ToolbarIcons.bulletedList,
      label: AppFlowyEditorL10n.current.bulletedList,
      name: 'bulleted_list',
    ),
    ListUnit(
      icon: ToolbarIcons.numberedList,
      label: AppFlowyEditorL10n.current.numberedList,
      name: 'numbered_list',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final btnList = _lists.map((currentList) {
      final node = widget.editorState.getNodeAtPath(
        widget.selection.start.path,
      )!;
      final isSelected = node.type == currentList.name;

      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: (size.width - 3 * style.buttonSpacing) / 2,
        ),
        child: MobileToolbarItemMenuBtn(
          icon: ToolbarIcon(
            afMobileIcons: currentList.icon,
            size: 20,
            color: MobileToolbarTheme.of(context).iconColor,
          ),
          label: Text(currentList.label, maxLines: 2),
          isSelected: isSelected,
          onPressed: () {
            setState(() {
              widget.editorState.formatNode(
                widget.selection,
                (node) => node.copyWith(
                  type: isSelected
                      ? ParagraphBlockKeys.type
                      : currentList.name,
                  attributes: {
                    ParagraphBlockKeys.delta: (node.delta ?? Delta()).toJson(),
                  },
                ),
                selectionExtraInfo: {
                  selectionExtraInfoDoNotAttachTextService: true,
                },
              );
            });
          },
        ),
      );
    }).toList();

    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: size.width),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: btnList,
      ),
    );
  }
}
