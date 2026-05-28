import 'package:appflowy_editor/appflowy_editor.dart';

final undoMobileToolbarItem = MobileToolbarItem(
  itemIconBuilder: (context, _) => ToolbarIcon(
    icon: ToolbarIcons.undo,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) async {
    editorState.undoManager.undo();
  },
);

final redoMobileToolbarItem = MobileToolbarItem(
  itemIconBuilder: (context, _) => ToolbarIcon(
    icon: ToolbarIcons.redo,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) async {
    editorState.undoManager.redo();
  },
);
