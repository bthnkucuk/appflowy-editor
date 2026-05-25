import 'package:appflowy_editor/appflowy_editor.dart';

MobileToolbarItem _buildToggleItem({
  required ToolbarIcons icon,
  required String attributeName,
}) {
  return MobileToolbarItem.action(
    itemIconBuilder: (context, _, _) => ToolbarIcon(
      afMobileIcons: icon,
      color: MobileToolbarTheme.of(context).iconColor,
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
