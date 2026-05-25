import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [headingMobileToolbarItem]. Opens the H1/H2/H3
/// row in a [StupidSimpleSheetRoute] instead of the inline keyboard-height
/// menu used by MobileToolbarV2.
final headingMobileToolbarItemSheet = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => AFMobileIcon(
    afMobileIcons: AFMobileIcons.heading,
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
                  child: _SheetHeadingMenu(editorState, selection),
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

class HeadingUnit {
  final AFMobileIcons icon;
  final String label;
  final int level;

  HeadingUnit({required this.icon, required this.label, required this.level});
}

class _SheetHeadingMenu extends StatefulWidget {
  const _SheetHeadingMenu(this.editorState, this.selection);

  final EditorState editorState;
  final Selection selection;

  @override
  State<_SheetHeadingMenu> createState() => _SheetHeadingMenuState();
}

class _SheetHeadingMenuState extends State<_SheetHeadingMenu> {
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

  final _headings = [
    HeadingUnit(
      icon: AFMobileIcons.h1,
      label: AppFlowyEditorL10n.current.mobileHeading1,
      level: 1,
    ),
    HeadingUnit(
      icon: AFMobileIcons.h2,
      label: AppFlowyEditorL10n.current.mobileHeading2,
      level: 2,
    ),
    HeadingUnit(
      icon: AFMobileIcons.h3,
      label: AppFlowyEditorL10n.current.mobileHeading3,
      level: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final btnList = _headings.map((currentHeading) {
      final node = widget.editorState.getNodeAtPath(
        widget.selection.start.path,
      )!;
      final isSelected =
          node.type == HeadingBlockKeys.type &&
          node.attributes[HeadingBlockKeys.level] == currentHeading.level;

      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: (size.width - 4 * style.buttonSpacing) / 3,
        ),
        child: MobileToolbarItemMenuBtn(
          icon: AFMobileIcon(
            afMobileIcons: currentHeading.icon,
            size: 20,
            color: MobileToolbarTheme.of(context).iconColor,
          ),
          label: Text(currentHeading.label, maxLines: 2),
          isSelected: isSelected,
          onPressed: () {
            setState(() {
              widget.editorState.formatNode(
                widget.selection,
                (node) => node.copyWith(
                  type: isSelected
                      ? ParagraphBlockKeys.type
                      : HeadingBlockKeys.type,
                  attributes: {
                    HeadingBlockKeys.level: currentHeading.level,
                    HeadingBlockKeys.backgroundColor:
                        node.attributes[blockComponentBackgroundColor],
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
