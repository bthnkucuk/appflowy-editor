part of '../editor_state.dart';

/// Undo / redo bookkeeping for [EditorState]. Owns the [UndoManager]
/// instance and the debounce-seal timer that groups consecutive
/// keystrokes into a single history item.
///
/// Lives in the same library as EditorState (via `part of`) so its
/// private helpers (`_recordRedoOrUndo`, `_debouncedSealHistoryItem`)
/// stay invisible to downstream consumers — they're called only from
/// EditorState's `apply()` write-path.
///
/// EditorState's constructor calls [_initHistory] and then assigns
/// `undoManager.state = this`. The back-ref happens on the host because
/// `this` from inside this mixin is typed as the mixin itself, not as
/// EditorState — typing it would require `on EditorState`, which would
/// create a circular import between editor_state.dart and this file.
mixin _HistoryMixin {
  /// Provided by the host EditorState — the minimum interval after
  /// which a user-edit history item is sealed (grouping consecutive
  /// keystrokes into one undo step). Declared as an abstract getter so
  /// the mixin can read it without an `on EditorState` clause.
  Duration get minHistoryItemDuration;

  /// The undo/redo manager. Initialized once via [_initHistory] from the
  /// EditorState constructor.
  late final UndoManager undoManager;

  Timer? _debouncedSealHistoryItemTimer;

  /// Test hook: when set, [_debouncedSealHistoryItem] becomes a no-op so
  /// tests can deterministically inspect the un-sealed history item.
  @visibleForTesting
  bool disableSealTimer = false;

  void _initHistory(int? maxHistoryItemSize) {
    undoManager = UndoManager(maxHistoryItemSize ?? 200);
  }

  /// Record the transaction into the undo or redo stack and, for user
  /// edits, schedule the debounce-seal that groups consecutive
  /// keystrokes. Called from `EditorState.apply()`.
  void _recordRedoOrUndo(ApplyOptions options, Transaction transaction, bool skipDebounce) {
    final source = options.source;
    undoManager.record(transaction, source);

    // Only debounce-seal for user edits (grouping consecutive keystrokes).
    if (source == TransactionSource.userEdit) {
      if (skipDebounce && undoManager.undoStack.isNonEmpty) {
        AppFlowyEditorLog.editor.debug('Seal history item');
        final last = undoManager.undoStack.last;
        last.seal();
      } else {
        _debouncedSealHistoryItem();
      }
    }
  }

  void _debouncedSealHistoryItem() {
    if (disableSealTimer) {
      return;
    }
    _debouncedSealHistoryItemTimer?.cancel();
    _debouncedSealHistoryItemTimer = Timer(minHistoryItemDuration, () {
      if (undoManager.undoStack.isNonEmpty) {
        AppFlowyEditorLog.editor.debug('Seal history item');
        final last = undoManager.undoStack.last;
        last.seal();
      }
    });
  }

  void _disposeHistory() {
    _debouncedSealHistoryItemTimer?.cancel();
  }
}
