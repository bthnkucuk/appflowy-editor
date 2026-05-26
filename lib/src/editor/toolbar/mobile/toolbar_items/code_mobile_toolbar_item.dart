import 'package:appflowy_editor/appflowy_editor.dart';

final codeMobileToolbarItem = MobileToolbarItem(
  itemIconBuilder: (context, _) => ToolbarIcon(
    icon: ToolbarIcons.code,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (_, editorState) =>
      editorState.toggleAttribute(AppFlowyRichTextKeys.code),
);
