import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Sheet-based variant of [linkMobileToolbarItem]. Opens the URL input in a
/// [StupidSimpleSheetRoute] instead of the inline keyboard-height menu used
/// by MobileToolbarV2. Unlike the other sheet variants, this one keeps the
/// soft keyboard open — the TextField inside [MobileLinkMenu] needs it.
final linkMobileToolbarItemSheet = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => AFMobileIcon(
    afMobileIcons: AFMobileIcons.link,
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
    keepEditorFocusNotifier.increase();

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
          editorState.updateSelectionWithReason(
            selection,
            extraInfo: {selectionExtraInfoDisableFloatingToolbar: true},
          );
          editorState.service.keyboardService?.enableKeyBoard(selection);
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
            await widget.editorState.formatDelta(widget.selection, {
              AppFlowyRichTextKeys.href: value,
            }, selectionExtraInfo: {
              selectionExtraInfoDoNotAttachTextService: true,
            });
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
