import 'package:appflowy_editor/appflowy_editor.dart';

final undoMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => ToolbarIcon(
    afMobileIcons: ToolbarIcons.undo,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) async {
    editorState.undoManager.undo();
  },
);

final redoMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, _, _) => ToolbarIcon(
    afMobileIcons: ToolbarIcons.redo,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) async {
    editorState.undoManager.redo();
  },
);
