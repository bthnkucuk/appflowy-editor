/// Helper types for [EditorState] — value-like config bags and the
/// transaction/selection enums. Lives in its own file so the main
/// editor_state.dart can stay focused on stateful behavior.
library;

import '../core/transform/transaction.dart';
import 'undo_manager.dart';

/// The drag-mode state for mobile selection / cursor manipulation. Lives
/// at the editor_state layer so the core (editor_state, scroll service)
/// can compare against it directly without the `.toString()` hack that
/// previously stringified the enum to break a layering dependency.
///
/// Name is intentionally kept as `MobileSelectionDragMode` (and not the
/// shorter `SelectionDragMode`) to avoid a 50+ callsite rename. The enum
/// has been mobile-coded historically; if desktop drag-to-select ever
/// reuses these states a typedef alias is the migration path.
enum MobileSelectionDragMode { none, leftSelectionHandle, rightSelectionHandle, cursor }

/// Key under which the active [MobileSelectionDragMode] is published in
/// `EditorState.selectionExtraInfo`. Consumers can read it directly, but
/// `SelectionExtraInfo.dragMode` is the typed access path you actually
/// want.
const String selectionDragModeKey = 'selection_drag_mode';

/// The record broadcast by `EditorState.transactionStream`. Pattern-matched
/// at consumer sites; consumers depend on the field order
/// (time, transaction, options).
typedef EditorTransactionValue = (TransactionTime time, Transaction transaction, ApplyOptions options);

/// The type of this value is bool.
///
/// Set true on this key in `selectionExtraInfo` to prevent attaching the
/// text service when selection is changed.
const selectionExtraInfoDoNotAttachTextService = 'selectionExtraInfoDoNotAttachTextService';

/// Border radius (logical pixels) for the highlight rect of the
/// currently-selected match in find-and-replace. Stored under this
/// key in `selectionExtraInfo` so that
/// `SelectionAreaPainter` can render an [RRect] instead of a plain
/// rect — visually distinguishes the active search hit from regular
/// selections.
///
/// Type: `double`.
const selectionExtraInfoSelectionRadius = 'selectionExtraInfoSelectionRadius';

/// Typed view over the untyped `selectionExtraInfo` map that
/// `EditorState.updateSelectionWithReason` carries alongside a selection
/// change. Wire-compatible — the underlying value remains a
/// `Map<String, Object?>` so `Transaction.selectionExtraInfo`
/// serialization keeps working — but reads at consumer sites no longer
/// have to stringify enums or guess at key spellings.
///
/// Construct via [SelectionExtraInfo.from] when you have a possibly-null
/// map handed to you by the editor; use [asMap] when you need to pass
/// it back into APIs that still expect the raw map shape.
extension type SelectionExtraInfo._(Map<String, Object?> _map) {
  /// Wrap an existing map; `null` becomes an empty wrapper so callers
  /// don't have to null-check before reading typed accessors.
  factory SelectionExtraInfo.from(Map<String, Object?>? map) => SelectionExtraInfo._(map ?? const <String, Object?>{});

  /// Empty info, useful as a default sentinel.
  factory SelectionExtraInfo.empty() => SelectionExtraInfo._(const <String, Object?>{});

  /// The raw map for callers that still talk in untyped extraInfo (e.g.
  /// `Transaction.selectionExtraInfo` serialization).
  Map<String, Object?> get asMap => _map;

  /// Resolved drag mode for the current selection update. Returns
  /// [MobileSelectionDragMode.none] when the key is absent or holds a
  /// type other than the enum.
  MobileSelectionDragMode get dragMode {
    final value = _map[selectionDragModeKey];
    return value is MobileSelectionDragMode ? value : MobileSelectionDragMode.none;
  }

  /// Whether a drag (handle / long-press cursor) is currently in
  /// progress. Equivalent to `dragMode != none` — exposed as its own
  /// getter because it is what most consumers actually care about.
  bool get isDraggingSelection => dragMode != MobileSelectionDragMode.none;

  /// True when the selection update should NOT attach the text service
  /// (used to suppress IME re-attachment during transient updates).
  bool get doNotAttachTextService => _map[selectionExtraInfoDoNotAttachTextService] == true;
}

final class ApplyOptions {
  const ApplyOptions({this.source = TransactionSource.userEdit, this.inMemoryUpdate = false});

  /// The source of the transaction. Determines how it's recorded in the
  /// undo/redo history. Defaults to [TransactionSource.userEdit] which
  /// pushes the transaction onto the undo stack.
  final TransactionSource source;

  /// Whether the transaction is an in-memory update.
  final bool inMemoryUpdate;
}

///TODO(mobile): Debug info for the editor state. Its meaning is same as [EditorChrome.debugInfo]. clear this class later and use [EditorChrome.debugInfo] instead.
final class EditorStateDebugInfo {
  EditorStateDebugInfo({this.debugPaintSizeEnabled = false});

  /// Enable the debug paint size for selection handle.
  ///
  /// It is only available on mobile.
  bool debugPaintSizeEnabled;
}

enum SelectionUpdateReason {
  uiEvent, // like mouse click, keyboard event
  transaction, // like insert, delete, format
  remote, // like remote selection
  selectAll,
  searchHighlight, // Highlighting search results

  /// Selection update originating from a tap-driven UI path (e.g. an
  /// editable editor whose tap places the cursor).
  ///
  /// Note: the mobile highlight service does NOT use this reason any
  /// more — it publishes tap-ups onto `EditorState.tapEvents` instead,
  /// so a tap in a `highlightable: true` + `editable: false` viewer
  /// does not write the editor's selection and therefore does not
  /// paint a selection rect. This enum value remains for code paths
  /// that legitimately stamp a tap onto `editorState.selection`.
  tap,
}

enum SelectionType { inline, block }

enum TransactionTime { before, after }
