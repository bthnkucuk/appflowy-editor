import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [textDecorationMobileToolbarItemV2]. Opens the
/// bold/italic/underline/strikethrough/code grid in a
/// [StupidSimpleSheetRoute] instead of the inline keyboard-height menu used
/// by MobileToolbarV2.
final textDecorationMobileToolbarItemV2Sheet = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => AFMobileIcon(
    afMobileIcons: AFMobileIcons.textDecoration,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) {
    final selection = editorState.selection;
    if (selection == null) return;

    editorState.service.keyboardService?.closeKeyboard();
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
                  child: _SheetTextDecorationV2Menu(editorState, selection),
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
          editorState.service.keyboardService?.enableKeyBoard(selection);
        });
  },
);

class _SheetTextDecorationV2Menu extends StatefulWidget {
  const _SheetTextDecorationV2Menu(this.editorState, this.selection);

  final EditorState editorState;
  final Selection selection;

  @override
  State<_SheetTextDecorationV2Menu> createState() =>
      _SheetTextDecorationV2MenuState();
}

class _SheetTextDecorationV2MenuState
    extends State<_SheetTextDecorationV2Menu> {
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

  final _textDecorations = [
    // BIUS
    TextDecorationUnit(
      icon: AFMobileIcons.bold,
      label: AppFlowyEditorL10n.current.bold,
      name: AppFlowyRichTextKeys.bold,
    ),
    TextDecorationUnit(
      icon: AFMobileIcons.italic,
      label: AppFlowyEditorL10n.current.italic,
      name: AppFlowyRichTextKeys.italic,
    ),
    TextDecorationUnit(
      icon: AFMobileIcons.underline,
      label: AppFlowyEditorL10n.current.underline,
      name: AppFlowyRichTextKeys.underline,
    ),
    TextDecorationUnit(
      icon: AFMobileIcons.strikethrough,
      label: AppFlowyEditorL10n.current.strikethrough,
      name: AppFlowyRichTextKeys.strikethrough,
    ),

    // Code
    TextDecorationUnit(
      icon: AFMobileIcons.code,
      label: AppFlowyEditorL10n.current.embedCode,
      name: AppFlowyRichTextKeys.code,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final btnList = _textDecorations.map((currentDecoration) {
      final selection = widget.selection;
      final nodes = widget.editorState.getNodesInSelection(selection);
      final bool isSelected;
      if (selection.isCollapsed) {
        isSelected = widget.editorState.toggledStyle.containsKey(
          currentDecoration.name,
        );
      } else {
        isSelected = nodes.allSatisfyInSelection(selection, (delta) {
          return delta.everyAttributes(
            (attributes) => attributes[currentDecoration.name] == true,
          );
        });
      }

      return MobileToolbarItemMenuBtn(
        icon: AFMobileIcon(
          afMobileIcons: currentDecoration.icon,
          color: MobileToolbarTheme.of(context).iconColor,
        ),
        label: Text(currentDecoration.label),
        isSelected: isSelected,
        onPressed: () {
          setState(() {
            widget.editorState.toggleAttribute(
              currentDecoration.name,
              selection: widget.selection,
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
      children: btnList,
    );
  }
}
