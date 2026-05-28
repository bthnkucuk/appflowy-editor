import '../shortcut_event/shortcut_event_handler.dart';
import 'package:flutter/material.dart';

ShortcutEventHandler exitEditingModeEventHandler = (editorState, event) {
  editorState.selectionService.clearSelection();

  return KeyEventResult.handled;
};
