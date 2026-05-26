part of '../editor_state.dart';

/// Selection + Style state for [EditorState], bundled into one mixin
/// because the two concerns share a critical section in the
/// [SelectionStyleMixin.selection] setter: every selection change must
/// also clear the toggled-style map and reset the slice-attributes flag
/// — in that exact order, even when the selection value is identical
/// (only the H2.1 short-circuit on the notifier itself happens after the
/// style writes). Splitting Selection and Style into separate seams
/// would force a callback round-trip between them and turn the
/// ordering invariant into a bug-vector.
///
/// Lives in the same library as EditorState (`part of`) so its private
/// fields (`_selectionType`, `_selectionUpdateReason`, `_toggledStyle`,
/// `_sliceUpcomingAttributes`) stay invisible to downstream consumers.
mixin SelectionStyleMixin {
  // ---------------------------------------------------------------------------
  // Selection notifiers
  // ---------------------------------------------------------------------------

  /// The selection notifier of the editor.
  final PropertyValueNotifier<Selection?> selectionNotifier =
      PropertyValueNotifier<Selection?>(null);

  /// The highlight notifier of the editor.
  final PropertyValueNotifier<Selection?> highlightNotifier =
      PropertyValueNotifier<Selection?>(null);

  /// The tap notifier of the editor.
  final PropertyValueNotifier<Selection?> tapNotifier =
      PropertyValueNotifier<Selection?>(null);

  /// Remote selection is the selection from other users.
  final PropertyValueNotifier<List<RemoteSelection>> remoteSelections =
      PropertyValueNotifier<List<RemoteSelection>>([]);

  // ---------------------------------------------------------------------------
  // Selection accessors
  // ---------------------------------------------------------------------------

  /// The selection of the editor.
  Selection? get selection => selectionNotifier.value;

  /// The highlight of the editor.
  Selection? get highlight => highlightNotifier.value;

  Selection? get tap => tapNotifier.value;

  /// Sets the selection of the editor.
  ///
  /// LOAD-BEARING ORDER (do not reorder):
  /// 1. Clear toggled style when value actually differs.
  /// 2. Reset slice-upcoming-attributes flag — even if value is
  ///    identical, the user expects toggled state to reset on a
  ///    same-spot tap.
  /// 3. H2.1 short-circuit: skip the notifier write when the value is
  ///    identical, to avoid PropertyValueNotifier's always-notify
  ///    cascade across N block widgets.
  set selection(Selection? value) {
    // clear the toggled style when the selection is changed.
    if (selectionNotifier.value != value) {
      _toggledStyle.clear();
    }

    // reset slice flag
    sliceUpcomingAttributes = true;

    // H2.1: short-circuit notify on identical selection to avoid the
    // PropertyValueNotifier always-notify cascade across N block widgets.
    if (selectionNotifier.value == value) return;

    selectionNotifier.value = value;
  }

  /// Sets the highlight of the editor.
  set highlight(Selection? value) {
    if (highlightNotifier.value == value) return;

    highlightNotifier.value = value;
  }

  /// Sets the tap selection of the editor.
  set tap(Selection? value) {
    tapNotifier.value = value;
  }

  // ---------------------------------------------------------------------------
  // Selection metadata (type, update reason, extra info)
  // ---------------------------------------------------------------------------

  SelectionType? _selectionType;

  set selectionType(SelectionType? value) {
    if (value == _selectionType) {
      return;
    }
    _selectionType = value;
  }

  SelectionType? get selectionType => _selectionType;

  SelectionUpdateReason _selectionUpdateReason = SelectionUpdateReason.uiEvent;

  SelectionUpdateReason get selectionUpdateReason => _selectionUpdateReason;

  /// Untyped extra info attached to the most recent selection update.
  /// Use [SelectionExtraInfo.from] to read typed values.
  Map? selectionExtraInfo;

  /// Public update entry — awaits the post-frame callback for
  /// `uiEvent` updates so callers can chain against the layout pass.
  Future<void> updateSelectionWithReason(
    Selection? selection, {
    SelectionUpdateReason reason = SelectionUpdateReason.transaction,
    Map? extraInfo,
    SelectionType? customSelectionType,
  }) async {
    final completer = Completer<void>();

    if (reason == SelectionUpdateReason.uiEvent) {
      _selectionType = customSelectionType ?? SelectionType.inline;
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) => completer.complete(),
      );
    } else if (customSelectionType != null) {
      _selectionType = customSelectionType;
    }

    // broadcast to other users here
    selectionExtraInfo = extraInfo;
    _selectionUpdateReason = reason;

    this.selection = selection;

    return completer.future;
  }

  void updateHighlight(Selection? highlight) {
    this.highlight = highlight;
  }

  void updateTap(Selection? tap) {
    this.tap = tap;
  }

  // ---------------------------------------------------------------------------
  // Style — toggled formatting + slice-upcoming-attributes flag
  // ---------------------------------------------------------------------------

  /// Store the toggled format style, like bold, italic, etc.
  /// All the values must be the key from [AppFlowyRichTextKeys.supportToggled].
  ///
  /// Use the method [updateToggledStyle] to update key-value pairs.
  ///
  /// NOTES: It only works once; after the selection is changed, the
  /// toggled style will be cleared (see the [selection] setter).
  UnmodifiableMapView<String, dynamic> get toggledStyle =>
      UnmodifiableMapView<String, dynamic>(_toggledStyle);

  final _toggledStyle = Attributes();
  late final toggledStyleNotifier = ValueNotifier<Attributes>(toggledStyle);

  void updateToggledStyle(String key, dynamic value) {
    _toggledStyle[key] = value;
    toggledStyleNotifier.value = {..._toggledStyle};
  }

  /// Whether the upcoming attributes should be sliced.
  ///
  /// If the value is true, the upcoming attributes will be sliced.
  /// If the value is false, the upcoming attributes will be skipped.
  bool _sliceUpcomingAttributes = true;

  bool get sliceUpcomingAttributes => _sliceUpcomingAttributes;

  set sliceUpcomingAttributes(bool value) {
    if (value == _sliceUpcomingAttributes) {
      return;
    }
    AppFlowyEditorLog.input.debug('sliceUpcomingAttributes: $value');
    _sliceUpcomingAttributes = value;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void _disposeSelectionStyle() {
    selectionNotifier.dispose();
    highlightNotifier.dispose();
    tapNotifier.dispose();
    remoteSelections.dispose();
    toggledStyleNotifier.dispose();
  }
}
