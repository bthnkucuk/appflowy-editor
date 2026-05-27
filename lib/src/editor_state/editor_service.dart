part of '../editor_state.dart';

/// Service-locator surface mixed into [EditorState]. Owns the
/// `GlobalKey`s that point at the live service widgets (selection,
/// keyboard, scroll) and the late-bound `rendererService` plug-in.
///
/// Implemented as a mixin so consumers read `editorState.selectionService`
/// directly — the `editorState.service.X` middleman is gone. The
/// `_Key` fields and the `_service` getters are now first-class members
/// of EditorState.
mixin _EditorServiceMixin {
  // selection service
  final selectionServiceKey = GlobalKey(debugLabel: 'appflowy_editor_selection_service');

  AppFlowySelectionService get selectionService {
    assert(selectionServiceKey.currentState != null && selectionServiceKey.currentState is AppFlowySelectionService);

    return selectionServiceKey.currentState! as AppFlowySelectionService;
  }

  // keyboard service
  final keyboardServiceKey = GlobalKey(debugLabel: 'appflowy_editor_keyboard_service');

  AppFlowyKeyboardService? get keyboardService {
    if (keyboardServiceKey.currentState != null && keyboardServiceKey.currentState is AppFlowyKeyboardService) {
      return keyboardServiceKey.currentState! as AppFlowyKeyboardService;
    }

    return null;
  }

  // render plugin service
  late BlockComponentRendererService rendererService;

  /// Convenience alias of [rendererService] — kept because the existing
  /// `editorState.renderer` accessor predated the mixin extraction.
  BlockComponentRendererService get renderer => rendererService;
  set renderer(BlockComponentRendererService value) => rendererService = value;

  // scroll service
  final scrollServiceKey = GlobalKey(debugLabel: 'appflowy_editor_scroll_service');

  AppFlowyScrollService? get scrollService {
    if (scrollServiceKey.currentState != null && scrollServiceKey.currentState is AppFlowyScrollService) {
      return scrollServiceKey.currentState! as AppFlowyScrollService;
    }

    return null;
  }
}
