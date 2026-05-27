import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [textDecorationMobileToolbarItemV2]. Opens the
/// bold/italic/underline/strikethrough/code grid in a
/// [StupidSimpleSheetRoute] instead of the inline keyboard-height menu used
/// by MobileToolbarV2.
final textDecorationMobileToolbarItemV2Sheet = MobileToolbarItem(
  itemIconBuilder: (context, _) => ToolbarIcon(
    icon: ToolbarIcons.textDecorationBold,
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
    editorState.keepFocusNotifier.increase();

    Navigator.of(context)
        .push(
          StupidSimpleSheetRoute<void>(
            barrierColor: Colors.transparent,
            originateAboveBottomViewInset: true,
            child: MobileToolbarTheme(
              child: EditorToolbarSheetScaffold(
                child: _SheetTextDecorationV2Menu(editorState, selection),
              ),
            ),
          ),
        )
        .then((_) {
          // Pair the .increase() above the .push — without this every
          // sheet open leaks +1 on the counter (cf. heading sheet).
          editorState.keepFocusNotifier.decrease();
          editorState.updateSelectionWithReason(
            selection,
            extraInfo: {selectionExtraInfoDisableFloatingToolbar: true},
          );
          editorState.keyboardService?.enableKeyBoard(selection);
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

    // Code
    TextDecorationUnit(
      icon: ToolbarIcons.code,
      label: aft.embedCode,
      name: AppFlowyRichTextKeys.code,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final decoration in _textDecorations)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _buildButton(decoration),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(TextDecorationUnit decoration) {
    final selection = widget.selection;
    final nodes = widget.editorState.getNodesInSelection(selection);
    final bool isSelected;
    if (selection.isCollapsed) {
      isSelected = widget.editorState.toggledStyle.containsKey(decoration.name);
    } else {
      isSelected = nodes.allSatisfyInSelection(selection, (delta) {
        return delta.everyAttributes(
          (attributes) => attributes[decoration.name] == true,
        );
      });
    }
    return EditorToolbarMenuButton(
      backgroundColor: Colors.transparent,
      isSelected: isSelected,
      icon: decoration.icon,
      iconPadding: const EdgeInsets.symmetric(vertical: 12),
      onTap: () {
        setState(() {
          widget.editorState.toggleAttribute(
            decoration.name,
            selection: widget.selection,
            selectionExtraInfo: {
              selectionExtraInfoDoNotAttachTextService: true,
            },
          );
        });
      },
    );
  }
}
