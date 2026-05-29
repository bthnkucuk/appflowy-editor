part of '../editor_state.dart';

/// Selection + Style state for [EditorState], bundled into one mixin
/// because the two concerns share a critical section in the
/// [_SelectionStyleMixin.selection] setter: every selection change must
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
mixin _SelectionStyleMixin {
  // ---------------------------------------------------------------------------
  // Selection notifiers
  // ---------------------------------------------------------------------------

  /// The selection notifier of the editor.
  final PropertyValueNotifier<Selection?> selectionNotifier = PropertyValueNotifier<Selection?>(null);

  /// The highlight notifier of the editor.
  final PropertyValueNotifier<Selection?> highlightNotifier = PropertyValueNotifier<Selection?>(null);

  /// Remote selection is the selection from other users.
  final PropertyValueNotifier<List<RemoteSelection>> remoteSelections = PropertyValueNotifier<List<RemoteSelection>>([]);

  /// Broadcast stream of one-shot tap-up selections coming out of the
  /// mobile highlight service (`MobileHighlightServiceWidget`).
  ///
  /// Unlike `selectionNotifier`, writing here does not mutate the
  /// editor's text-selection state and therefore does not paint a
  /// selection rect via `BlockSelectionArea` — which matters for
  /// `highlightable: true` + `editable: false` viewers where the editor
  /// is rendered as a reader and a lingering gray rect would be
  /// visually wrong.
  ///
  /// Consumers subscribe with `.listen` (or `.listen + cancel` for
  /// disposable owners) and treat each event as a momentary tap, e.g.
  /// "seek the TTS playhead to this word". The stream is broadcast, so
  /// multiple consumers can listen concurrently; it closes when
  /// `EditorState.dispose()` runs.
  Stream<Selection> get tapEvents => _tapEventsController.stream;

  final StreamController<Selection> _tapEventsController = StreamController<Selection>.broadcast();

  /// Publish a deliberate tap-up onto [tapEvents].
  ///
  /// The primary caller is `MobileHighlightServiceWidget._applySelection`
  /// at the moment a tap-up gesture lands. External callers can also use
  /// this to inject a synthetic tap — e.g. a programmatic "seek to this
  /// section" entry-point that wants the same downstream pipeline as a
  /// real user tap.
  ///
  /// Guarded against post-dispose calls so a stray late emission from a
  /// service that hasn't detached yet doesn't throw.
  void notifyTap(Selection selection) {
    if (_tapEventsController.isClosed) {
      debugPrint('[H-DBG] notifyTap: skip (controller closed)');
      return;
    }
    debugPrint('[H-DBG] notifyTap: $selection');
    _tapEventsController.add(selection);
  }

  // ---------------------------------------------------------------------------
  // Selection accessors
  // ---------------------------------------------------------------------------

  /// The selection of the editor.
  Selection? get selection => selectionNotifier.value;

  /// The highlight of the editor.
  Selection? get highlight => highlightNotifier.value;

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
    if (highlightNotifier.value == value) {
      debugPrint('[H-DBG] highlight setter: skip ($value unchanged)');
      return;
    }

    debugPrint(
      '[H-DBG] highlight setter: ${highlightNotifier.value} → $value',
    );
    highlightNotifier.value = value;
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

  /// Public update entry.
  ///
  /// H2.3.c (2026-05-26): previously returned `Future<void>` resolved on
  /// the next post-frame, but every one of the ~33 callsites in the
  /// editor fired-and-forgot the result — including the mobile drag
  /// path, which fires this ~60 times per second. The Completer +
  /// `addPostFrameCallback` allocation per call was pure waste. Return
  /// type is now `void`; callers that genuinely need to wait for the
  /// layout pass can schedule their own `WidgetsBinding.instance.
  /// addPostFrameCallback`.
  void updateSelectionWithReason(
    Selection? selection, {
    SelectionUpdateReason reason = SelectionUpdateReason.transaction,
    Map? extraInfo,
    SelectionType? customSelectionType,
  }) {
    if (reason == SelectionUpdateReason.uiEvent) {
      _selectionType = customSelectionType ?? SelectionType.inline;
    } else if (customSelectionType != null) {
      _selectionType = customSelectionType;
    }

    selectionExtraInfo = extraInfo;
    _selectionUpdateReason = reason;

    this.selection = selection;
  }

  void updateHighlight(Selection? highlight) {
    this.highlight = highlight;
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
  UnmodifiableMapView<String, dynamic> get toggledStyle => UnmodifiableMapView<String, dynamic>(_toggledStyle);

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
    _tapEventsController.close();
    remoteSelections.dispose();
    toggledStyleNotifier.dispose();
  }
}
