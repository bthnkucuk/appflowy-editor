import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Builds the icon widget for a [MobileToolbarItem] slot. Returning `null`
/// hides the item — useful for items that only make sense under a specific
/// selection (e.g. an "outdent" button when the cursor isn't in a list).
typedef MobileToolbarItemIconBuilder =
    Widget? Function(BuildContext context, EditorState editorState);

/// Fired when the user taps the toolbar item's icon.
typedef MobileToolbarItemActionHandler =
    void Function(BuildContext context, EditorState editorState);

/// Builds the body of a sheet opened by [MobileToolbarItem.sheet]. The
/// sheet captures the editor's selection at tap-time and passes it back
/// alongside the editor state, so the body doesn't have to read
/// `editorState.selection` (which the framework may have nulled by the
/// time the body builds).
typedef MobileToolbarSheetBodyBuilder =
    Widget Function(
      BuildContext context,
      EditorState editorState,
      Selection selection,
    );

/// A single icon-and-action pair the mobile toolbar (`MobileToolbarV2`)
/// renders. Pre-7.0 this had a `withMenu` variant that opened an inline
/// menu below the toolbar; that path was retired when sheet variants
/// replaced inline menus. The legacy constructor, `hasMenu` flag,
/// `itemMenuBuilder` field, and `MobileToolbarWidgetService` indirection
/// are all gone — what stayed is the minimal "render an icon, run a
/// callback" contract.
class MobileToolbarItem {
  const MobileToolbarItem({
    required this.itemIconBuilder,
    required this.actionHandler,
  });

  /// Convenience for items that just open a sheet styled with
  /// [EditorToolbarSheetScaffold]. Bakes in the boilerplate every sheet
  /// item used to repeat:
  ///
  ///   1. Bail when `editorState.selection` is null.
  ///   2. Optionally close the soft keyboard (skip for sheets that
  ///      host a `TextField` and need the IME open — e.g. the link
  ///      sheet).
  ///   3. Stamp the captured selection with the standard
  ///      extra-info flags so the mobile toolbar / floating toolbar /
  ///      IME stay out of the way for the lifetime of the sheet.
  ///   4. Push a [StupidSimpleSheetRoute] wrapped in
  ///      [MobileToolbarTheme] + [EditorToolbarSheetScaffold].
  ///   5. Pair the `keepFocusNotifier.increase()` with a matching
  ///      `decrease()` once the sheet pops; restore selection and
  ///      re-enable the keyboard for the next typing session.
  ///
  /// Each new sheet item only has to supply [itemIconBuilder] and
  /// [sheetBodyBuilder]. Set [closeKeyboard] to `false` when the sheet
  /// hosts an input that needs the IME (e.g. URL input).
  factory MobileToolbarItem.sheet({
    required MobileToolbarItemIconBuilder itemIconBuilder,
    required MobileToolbarSheetBodyBuilder sheetBodyBuilder,
    bool closeKeyboard = true,
  }) {
    return MobileToolbarItem(
      itemIconBuilder: itemIconBuilder,
      actionHandler: (context, editorState) {
        final selection = editorState.selection;
        if (selection == null) return;

        if (closeKeyboard) {
          editorState.keyboardService?.closeKeyboard();
        }
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
                    child: Builder(
                      builder: (sheetContext) =>
                          sheetBodyBuilder(sheetContext, editorState, selection),
                    ),
                  ),
                ),
              ),
            )
            .then((_) {
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

  final MobileToolbarItemIconBuilder itemIconBuilder;
  final MobileToolbarItemActionHandler actionHandler;
}
