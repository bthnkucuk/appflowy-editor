import 'package:appflowy_editor/src/editor/block_component/rich_text/appflowy_rich_text.dart';
import 'package:appflowy_editor/src/editor/editor_component/style/editor_style.dart';
import 'package:appflowy_editor/src/editor/selection_menu/selection_menu_widget.dart';
import 'package:appflowy_editor/src/editor_state/types.dart';
import 'package:flutter/foundation.dart';

/// Static-ish presentation surface mixed into [EditorState] — fields
/// that describe what the editor looks like (style, header/footer
/// toggles, auto-complete config, debug overlay) and whether it is
/// editable.
///
/// Holds NO mutation-core state: no selection notifiers, no history, no
/// transaction stream. Scroll mechanics (auto-scroller, listener set,
/// scrollable state) live in a separate seam that the facade will
/// introduce in a later step.
///
/// Implemented as a mixin so EditorState consumers can keep reading
/// `editorState.showHeader`, `editorState.editorStyle`, etc. directly —
/// no forwarder boilerplate, no second instance to construct or dispose,
/// no public API delta.
mixin EditorChromeMixin {
  /// The visual style of the editor. Late-initialized once from the
  /// hosting `AppFlowyEditor` widget; assigning twice is allowed by
  /// `late` semantics and matches the pre-refactor contract.
  late EditorStyle editorStyle;

  /// Whether the editor accepts edits. Listenable so widgets can react
  /// to changes (e.g. block components disabling their gesture wiring).
  final ValueNotifier<bool> editableNotifier = ValueNotifier(true);

  bool get editable => editableNotifier.value;

  set editable(bool value) {
    if (value == editable) {
      return;
    }
    editableNotifier.value = value;
  }

  /// Whether to render the optional editor header above the document.
  bool showHeader = false;

  /// Whether to render the optional editor footer below the document.
  bool showFooter = false;

  /// Whether the auto-complete suggestion (inline ghost text) feature
  /// is enabled. Reading code consults this BEFORE calling the provider.
  bool enableAutoComplete = false;

  /// Callback consulted by block components to ask for the auto-complete
  /// suggestion at the current cursor position. May be null even when
  /// [enableAutoComplete] is true.
  AppFlowyAutoCompleteTextProvider? autoCompleteTextProvider;

  /// Items rendered in the slash command (`/`) menu.
  List<SelectionMenuItem> selectionMenuItems = [];

  /// Debug overlays / flags (e.g. paint sizes of selection handles on
  /// mobile). Mutated by tests and demo apps.
  EditorStateDebugInfo debugInfo = EditorStateDebugInfo();

  /// Called by [EditorState.dispose] at the chrome's slot in the
  /// load-bearing disposal order.
  void disposeChrome() {
    editableNotifier.dispose();
  }
}
