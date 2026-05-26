import 'package:flutter/material.dart';
import '../shortcut_event/shortcut_event_handler.dart';

ShortcutEventHandler pageUpHandler = (editorState, _) {
  final scrollHeight = editorState.scrollService?.onePageHeight;
  final scrollService = editorState.scrollService;
  if (scrollHeight != null && scrollService != null) {
    scrollService.scrollTo(scrollService.dy - scrollHeight);
  }

  return KeyEventResult.handled;
};

ShortcutEventHandler pageDownHandler = (editorState, _) {
  final scrollHeight = editorState.scrollService?.onePageHeight;
  final scrollService = editorState.scrollService;
  if (scrollHeight != null && scrollService != null) {
    scrollService.scrollTo(scrollService.dy + scrollHeight);
  }

  return KeyEventResult.handled;
};
