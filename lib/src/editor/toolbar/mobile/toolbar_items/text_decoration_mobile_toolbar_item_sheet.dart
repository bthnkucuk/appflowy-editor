import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [textDecorationMobileToolbarItem]. Opens the same
/// bold/italic/underline/strikethrough grid in a [StupidSimpleSheetRoute]
/// instead of the inline keyboard-height menu used by MobileToolbarV2.
final textDecorationMobileToolbarItemSheet = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => ToolbarIcon(
    afMobileIcons: ToolbarIcons.textDecorationBold,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) {
    final selection = editorState.selection;
    if (selection == null) return;

    // Close the keyboard so the sheet animates in from the bottom in the
    // place the keyboard used to occupy. V2's keyboard-height listener will
    // null editorState.selection a frame or two later — the menu's State
    // below installs a watcher that pins the selection back to `selection`
    // for the sheet's lifetime so the selection visual survives.
    editorState.keyboardService?.closeKeyboard();
    editorState.updateSelectionWithReason(
      selection,
      extraInfo: {
        selectionExtraInfoDisableMobileToolbarKey: true,
        selectionExtraInfoDisableFloatingToolbar: true,
        selectionExtraInfoDoNotAttachTextService: true,
      },
    );
    editorState.keepFocusNotifier.increase();

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
                  child: _SheetTextDecorationMenu(editorState, selection),
                ),
              ),
            ),
          ),
        )
        .then((_) {
          // Pair the .increase() above the .push — without this, every
          // sheet open leaks +1 on the counter and the keyboard service
          // permanently skips focus-loss cleanups (cf. heading sheet).
          editorState.keepFocusNotifier.decrease();
          // Drop the "hide toolbar" flag so V2 comes back, and re-open the
          // keyboard so the user can keep typing.
          editorState.updateSelectionWithReason(
            selection,
            extraInfo: {selectionExtraInfoDisableFloatingToolbar: true},
          );
          editorState.keyboardService?.enableKeyBoard(selection);
        });
  },
);

class _SheetTextDecorationMenu extends StatefulWidget {
  const _SheetTextDecorationMenu(this.editorState, this.selection);

  final EditorState editorState;
  final Selection selection;

  @override
  State<_SheetTextDecorationMenu> createState() =>
      _SheetTextDecorationMenuState();
}

class _SheetTextDecorationMenuState extends State<_SheetTextDecorationMenu> {
  VoidCallback? _selectionWatcher;

  @override
  void initState() {
    super.initState();
    // V2's keyboard-height listener nulls editorState.selection a frame or
    // two after closeKeyboard fires. Re-pin the selection any time it
    // diverges from the captured range while this sheet is on top.
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
    // Run once next frame to catch V2's first null.
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
    TextDecorationUnit(
      icon: ToolbarIcons.bold,
      label: aft.bold,
      name: AppFlowyRichTextKeys.bold,
    ),
    TextDecorationUnit(
      icon: ToolbarIcons.italic,
      label: aft.italic,
      name: AppFlowyRichTextKeys.italic,
    ),
    TextDecorationUnit(
      icon: ToolbarIcons.underline,
      label: aft.underline,
      name: AppFlowyRichTextKeys.underline,
    ),
    TextDecorationUnit(
      icon: ToolbarIcons.strikethrough,
      label: aft.strikethrough,
      name: AppFlowyRichTextKeys.strikethrough,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final btnList = _textDecorations.map((decoration) {
      final selection = widget.selection;
      final nodes = widget.editorState.getNodesInSelection(selection);
      final bool isSelected;
      if (selection.isCollapsed) {
        isSelected = widget.editorState.toggledStyle.containsKey(
          decoration.name,
        );
      } else {
        isSelected = nodes.allSatisfyInSelection(selection, (delta) {
          return delta.everyAttributes(
            (attributes) => attributes[decoration.name] == true,
          );
        });
      }

      return MobileToolbarItemMenuBtn(
        icon: ToolbarIcon(
          afMobileIcons: decoration.icon,
          color: MobileToolbarTheme.of(context).iconColor,
          selected: isSelected,
        ),
        label: Text(decoration.label),
        isSelected: isSelected,
        onPressed: () {
          setState(() {
            widget.editorState.toggleAttribute(
              decoration.name,
              selection: widget.selection,
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
