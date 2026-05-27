import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [linkMobileToolbarItem]. Opens the URL input in a
/// [StupidSimpleSheetRoute] instead of the inline keyboard-height menu used
/// by MobileToolbarV2. Unlike the other sheet variants, this one keeps the
/// soft keyboard open — the TextField inside [MobileLinkMenu] needs it.
final linkMobileToolbarItemSheet = MobileToolbarItem(
  itemIconBuilder: (context, _) => ToolbarIcon(
    icon: ToolbarIcons.link,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) {
    final selection = editorState.selection;
    if (selection == null) return;

    // Don't close the keyboard — the TextField in the link menu autofocuses
    // and needs it. Just hide V2's toolbar so it doesn't stack on top of the
    // sheet, and stop the editor from re-attaching its own IME to the
    // selection (which would fight the TextField's IME).
    editorState.updateSelectionWithReason(
      selection,
      extraInfo: {
        selectionExtraInfoDisableMobileToolbarKey: true,
        selectionExtraInfoDisableFloatingToolbar: true,
        selectionExtraInfoDoNotAttachTextService: true,
      },
    );
    editorState.keepFocusNotifier.increase();

    final String? linkText = editorState.getDeltaAttributeValueInSelection(
      AppFlowyRichTextKeys.href,
      selection,
    );

    Navigator.of(context)
        .push(
          StupidSimpleSheetRoute<void>(
            barrierColor: Colors.transparent,
            originateAboveBottomViewInset: true,
            child: MobileToolbarTheme(
              child: _SheetLinkMenuHost(
                editorState: editorState,
                selection: selection,
                linkText: linkText,
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

class _SheetLinkMenuHost extends StatefulWidget {
  const _SheetLinkMenuHost({
    required this.editorState,
    required this.selection,
    required this.linkText,
  });

  final EditorState editorState;
  final Selection selection;
  final String? linkText;

  @override
  State<_SheetLinkMenuHost> createState() => _SheetLinkMenuHostState();
}

class _SheetLinkMenuHostState extends State<_SheetLinkMenuHost> {
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MobileLinkMenu(
        editorState: widget.editorState,
        linkText: widget.linkText,
        onSubmitted: (value) async {
          final navigator = Navigator.of(context);
          if (value.isNotEmpty) {
            await widget.editorState.formatDelta(
              widget.selection,
              {AppFlowyRichTextKeys.href: value},
              selectionExtraInfo: {
                selectionExtraInfoDoNotAttachTextService: true,
              },
            );
          }
          if (mounted) navigator.pop();
        },
        onCancel: () {
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

class MobileLinkMenu extends StatefulWidget {
  const MobileLinkMenu({
    super.key,
    this.linkText,
    required this.editorState,
    required this.onSubmitted,
    required this.onCancel,
  });

  final String? linkText;
  final EditorState editorState;
  final void Function(String) onSubmitted;
  final void Function() onCancel;

  @override
  State<MobileLinkMenu> createState() => _MobileLinkMenuState();
}

class _MobileLinkMenuState extends State<MobileLinkMenu> {
  late TextEditingController _textEditingController;

  @override
  void initState() {
    super.initState();
    widget.editorState.keyboardService?.disable();
    _textEditingController = TextEditingController(text: widget.linkText ?? '');
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    widget.editorState.keyboardService?.enable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    const double spacing = 8;

    return Material(
      // TextField widget needs to be wrapped in a Material widget to provide a visual appearance
      color: style.backgroundColor,
      child: SizedBox(
        height: style.toolbarHeight * 2 + spacing,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              controller: _textEditingController,
              keyboardType: TextInputType.url,
              onSubmitted: widget.onSubmitted,
              cursorColor: style.foregroundColor,
              decoration: InputDecoration(
                hintText: 'URL',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: style.itemOutlineColor),
                  borderRadius: BorderRadius.circular(style.borderRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: style.itemOutlineColor),
                  borderRadius: BorderRadius.circular(style.borderRadius),
                ),
                suffixIcon: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: Icon(Icons.clear_rounded, color: style.foregroundColor),
                  onPressed: _textEditingController.clear,
                  splashRadius: 5,
                ),
              ),
            ),
            const SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onCancel.call();
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        style.backgroundColor,
                      ),
                      foregroundColor: WidgetStateProperty.all(
                        style.primaryColor,
                      ),
                      elevation: WidgetStateProperty.all(0),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            style.borderRadius,
                          ),
                        ),
                      ),
                      side: WidgetStateBorderSide.resolveWith(
                        (states) => BorderSide(color: style.outlineColor),
                      ),
                    ),
                    child: Text(aft.cancel),
                  ),
                ),
                SizedBox(width: style.buttonSpacing),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSubmitted.call(_textEditingController.text);
                      widget.editorState.keyboardService?.closeKeyboard();
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        style.primaryColor,
                      ),
                      foregroundColor: WidgetStateProperty.all(
                        style.onPrimaryColor,
                      ),
                      elevation: WidgetStateProperty.all(0),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            style.borderRadius,
                          ),
                        ),
                      ),
                    ),
                    child: Text(aft.done),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
