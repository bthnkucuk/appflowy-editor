import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [buildTextAndBackgroundColorMobileToolbarItem].
/// Opens the same text/background color tabbed grid in a
/// [StupidSimpleSheetRoute] instead of the inline keyboard-height menu used
/// by MobileToolbarV2.
MobileToolbarItem buildTextAndBackgroundColorMobileToolbarItemSheet({
  List<ColorOption>? textColorOptions,
  List<ColorOption>? backgroundColorOptions,
}) {
  return MobileToolbarItem(
    itemIconBuilder: (context, _) => ToolbarIcon(
      icon: ToolbarIcons.color,
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
                  child: _SheetTextAndBackgroundColorMenu(
                    editorState,
                    selection,
                    textColorOptions: textColorOptions,
                    backgroundColorOptions: backgroundColorOptions,
                  ),
                ),
              ),
            ),
          )
          .then((_) {
            // Pair the .increase() above the .push (cf. heading sheet).
            editorState.keepFocusNotifier.decrease();
            editorState.updateSelectionWithReason(
              selection,
              extraInfo: {selectionExtraInfoDisableFloatingToolbar: true},
            );
            editorState.keyboardService?.enableKeyBoard(selection);
          });
    },
  );
}

class _SheetTextAndBackgroundColorMenu extends StatefulWidget {
  const _SheetTextAndBackgroundColorMenu(
    this.editorState,
    this.selection, {
    this.textColorOptions,
    this.backgroundColorOptions,
  });

  final EditorState editorState;
  final Selection selection;
  final List<ColorOption>? textColorOptions;
  final List<ColorOption>? backgroundColorOptions;

  @override
  State<_SheetTextAndBackgroundColorMenu> createState() =>
      _SheetTextAndBackgroundColorMenuState();
}

class _SheetTextAndBackgroundColorMenuState
    extends State<_SheetTextAndBackgroundColorMenu> {
  @override
  void initState() {
    super.initState();
    widget.editorState.selectionNotifier.addListener(_pinSelection);
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_pinSelection);
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final myTabs = <Tab>[
      Tab(text: aft.textColor),
      Tab(text: aft.backgroundColor),
    ];

    return DefaultTabController(
      length: myTabs.length,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: style.buttonHeight,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              tabs: myTabs,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  width: 2.4,
                  color: style.tabBarSelectedForegroundColor,
                ),
                borderRadius: const .all(.circular(2)),
              ),

              // labelColor: style.tabBarSelectedBackgroundColor,
              // indicator: BoxDecoration(
              //   borderRadius: BorderRadius.circular(style.borderRadius),
              //   color: style.tabBarSelectedForegroundColor,
              // ),
              dividerColor: Colors.transparent,
            ),
          ),
          SizedBox(
            height: 3 * style.buttonHeight + 4 * style.buttonSpacing,
            child: TabBarView(
              children: [
                TextColorOptionsWidgets(
                  widget.editorState,
                  widget.selection,
                  textColorOptions: widget.textColorOptions,
                ),
                BackgroundColorOptionsWidgets(
                  widget.editorState,
                  widget.selection,
                  backgroundColorOptions: widget.backgroundColorOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
