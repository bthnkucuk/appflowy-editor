import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Builds the icon widget for a [MobileToolbarItem] slot. Returning `null`
/// hides the item — useful for items that only make sense under a specific
/// selection (e.g. an "outdent" button when the cursor isn't in a list).
typedef MobileToolbarItemIconBuilder =
    Widget? Function(BuildContext context, EditorState editorState);

/// Fired when the user taps the toolbar item's icon.
typedef MobileToolbarItemActionHandler =
    void Function(BuildContext context, EditorState editorState);

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

  final MobileToolbarItemIconBuilder itemIconBuilder;
  final MobileToolbarItemActionHandler actionHandler;
}
