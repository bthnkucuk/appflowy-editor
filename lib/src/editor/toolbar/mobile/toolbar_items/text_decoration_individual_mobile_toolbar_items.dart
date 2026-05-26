import 'package:appflowy_editor/appflowy_editor.dart';

/// Returns true if [attributeName] is currently active under the
/// editor's selection — used to swap toolbar buttons to their Phosphor
/// Fill variant. Mirrors the detection logic in the text-decoration
/// sheet (`text_decoration_mobile_toolbar_item_v2_sheet.dart`):
///
///  * Collapsed cursor → consult `toggledStyle`, which tracks
///    soft-toggles that will apply to the next typed character.
///  * Range selection → require the attribute to be set on every span
///    inside the range. A "mixed" range (some bold, some not) reads as
///    not-active so the user can flip the whole range to on.
bool _isAttributeActive(EditorState editorState, String attributeName) {
  final selection = editorState.selection;
  if (selection == null) return false;
  if (selection.isCollapsed) {
    return editorState.toggledStyle.containsKey(attributeName);
  }
  final nodes = editorState.getNodesInSelection(selection);
  return nodes.allSatisfyInSelection(selection, (delta) {
    return delta.everyAttributes((a) => a[attributeName] == true);
  });
}

MobileToolbarItem _buildToggleItem({
  required ToolbarIcons icon,
  required String attributeName,
}) {
  return MobileToolbarItem.action(
    itemIconBuilder: (context, editorState, _) => ToolbarIcon(
      afMobileIcons: icon,
      color: MobileToolbarTheme.of(context).iconColor,
      selected: _isAttributeActive(editorState, attributeName),
    ),
    actionHandler: (_, editorState) {
      final selection = editorState.selection;
      if (selection == null) return;
      editorState.toggleAttribute(
        attributeName,
        selection: selection,
        selectionExtraInfo: {selectionExtraInfoDoNotAttachTextService: true},
      );
    },
  );
}

final boldMobileToolbarItem = _buildToggleItem(
  icon: ToolbarIcons.bold,
  attributeName: AppFlowyRichTextKeys.bold,
);

final italicMobileToolbarItem = _buildToggleItem(
  icon: ToolbarIcons.italic,
  attributeName: AppFlowyRichTextKeys.italic,
);

final underlineMobileToolbarItem = _buildToggleItem(
  icon: ToolbarIcons.underline,
  attributeName: AppFlowyRichTextKeys.underline,
);
