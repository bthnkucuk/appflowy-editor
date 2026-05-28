import '../../localizations/strings.g.dart';

import '../internal_key_event_handlers/copy_paste_handler.dart';
import 'context_menu.dart';

final standardContextMenuItems = [
  [
    // cut
    ContextMenuItem(
      getName: () => aft.cut,
      onPressed: (editorState) {
        handleCut(editorState);
      },
    ),
    // copy
    ContextMenuItem(
      getName: () => aft.copy,
      onPressed: (editorState) {
        handleCopy(editorState);
      },
    ),
    // Paste
    ContextMenuItem(
      getName: () => aft.paste,
      onPressed: (editorState) {
        handlePaste(editorState);
      },
    ),
  ],
];
