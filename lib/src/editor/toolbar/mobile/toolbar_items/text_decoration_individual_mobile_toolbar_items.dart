import 'package:appflowy_editor/appflowy_editor.dart';

MobileToolbarItem _buildToggleItem({
  required AFMobileIcons icon,
  required String attributeName,
}) {
  return MobileToolbarItem.action(
    itemIconBuilder: (context, _, _) => AFMobileIcon(
      afMobileIcons: icon,
      color: MobileToolbarTheme.of(context).iconColor,
    ),
    actionHandler: (_, editorState) {
      final selection = editorState.selection;
      if (selection == null) return;
      editorState.toggleAttribute(
        attributeName,
        selection: selection,
        selectionExtraInfo: {
          selectionExtraInfoDoNotAttachTextService: true,
        },
      );
    },
  );
}

final boldMobileToolbarItem = _buildToggleItem(
  icon: AFMobileIcons.bold,
  attributeName: AppFlowyRichTextKeys.bold,
);

final italicMobileToolbarItem = _buildToggleItem(
  icon: AFMobileIcons.italic,
  attributeName: AppFlowyRichTextKeys.italic,
);

final underlineMobileToolbarItem = _buildToggleItem(
  icon: AFMobileIcons.underline,
  attributeName: AppFlowyRichTextKeys.underline,
);
