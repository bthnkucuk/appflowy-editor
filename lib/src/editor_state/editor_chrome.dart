part of '../editor_state.dart';

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
mixin _EditorChromeMixin {
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

  /// Reference-counted "don't clear my selection / IME on focus loss"
  /// guard. Overlays (slash menu, color picker, link toolbar, mobile
  /// sheets) bump it while open; the keyboard service consults
  /// [KeepEditorFocusNotifier.shouldKeepFocus] inside its
  /// `_onFocusChanged` and bails out instead of clearing the selection
  /// when the counter is positive. Pre-7.0 this lived as a global
  /// (`keepEditorFocusNotifier`); per-EditorState scoping removes the
  /// multi-editor and hot-reload contamination risks the global had.
  final KeepEditorFocusNotifier keepFocusNotifier = KeepEditorFocusNotifier();

  /// Called by [EditorState.dispose] at the chrome's slot in the
  /// load-bearing disposal order.
  void disposeChrome() {
    editableNotifier.dispose();
    keepFocusNotifier.dispose();
  }
}
