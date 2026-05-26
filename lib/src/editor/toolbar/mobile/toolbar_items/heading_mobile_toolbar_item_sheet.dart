import 'dart:developer';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [headingMobileToolbarItem]. Opens the H1/H2/H3
/// row in a [StupidSimpleSheetRoute] instead of the inline keyboard-height
/// menu used by MobileToolbarV2.
final headingMobileToolbarItemSheet = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => ToolbarIcon(
    afMobileIcons: ToolbarIcons.heading,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) {
    final selection = editorState.selection;
    if (selection == null) return;
    log('headingMobileToolbarItemSheet: selection=$selection');

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
                  child: _SheetHeadingMenu(editorState, selection),
                ),
              ),
            ),
          ),
        )
        .then((_) {
          // Paired with the increase() above. Was missing pre-fix —
          // every sheet open leaked +1 on the counter, leaving
          // `shouldKeepFocus == true` forever after the first use and
          // the keyboard service silently skipping selection clears /
          // IME closes.
          editorState.keepFocusNotifier.decrease();
          editorState.updateSelectionWithReason(
            selection,
            extraInfo: {selectionExtraInfoDisableFloatingToolbar: true},
          );
          editorState.keyboardService?.enableKeyBoard(selection);
        });
  },
);

class HeadingUnit {
  final ToolbarIcons icon;
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
  @override
  void initState() {
    super.initState();
    // The action handler that pushed this route just synchronously
    // called updateSelectionWithReason with `selection`, and nothing
    // between that call and this initState mutates selection (the
    // wrapping `MobileToolbarItemMenu` doesn't touch it). So no
    // post-frame catch-up call is needed — the listener catches every
    // subsequent change.
    widget.editorState.selectionNotifier.addListener(_pinSelection);
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_pinSelection);
    super.dispose();
  }

  /// Snap the live selection back to the one this sheet was opened with,
  /// if it has drifted. The sheet's actions all assume the original
  /// selection is still in play — any IME/focus side-effect that moved
  /// the caret elsewhere would otherwise format the wrong block.
  void _pinSelection() {
    if (!mounted) return;
    if (widget.editorState.selection == widget.selection) return;
    widget.editorState.updateSelectionWithReason(
      widget.selection,
      extraInfo: {
        selectionExtraInfoDisableMobileToolbarKey: true,
        selectionExtraInfoDisableFloatingToolbar: true,
        selectionExtraInfoDoNotAttachTextService: true,
      },
    );
  }

  final _headings = [
    HeadingUnit(icon: ToolbarIcons.h1, label: aft.mobileHeading1, level: 1),
    HeadingUnit(icon: ToolbarIcons.h2, label: aft.mobileHeading2, level: 2),
    HeadingUnit(icon: ToolbarIcons.h3, label: aft.mobileHeading3, level: 3),
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
          icon: ToolbarIcon(
            afMobileIcons: currentHeading.icon,
            size: 20,
            color: MobileToolbarTheme.of(context).iconColor,
            selected: isSelected,
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
