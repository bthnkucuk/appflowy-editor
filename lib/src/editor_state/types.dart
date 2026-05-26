/// Helper types for [EditorState] — value-like config bags and the
/// transaction/selection enums. Lives in its own file so the main
/// editor_state.dart can stay focused on stateful behavior.
library;

import 'package:appflowy_editor/src/core/transform/transaction.dart';
import 'package:appflowy_editor/src/history/undo_manager.dart';

/// The record broadcast by `EditorState.transactionStream`. Pattern-matched
/// at consumer sites; consumers depend on the field order
/// (time, transaction, options).
typedef EditorTransactionValue = (
  TransactionTime time,
  Transaction transaction,
  ApplyOptions options,
);

/// The type of this value is bool.
///
/// Set true on this key in `selectionExtraInfo` to prevent attaching the
/// text service when selection is changed.
const selectionExtraInfoDoNotAttachTextService =
    'selectionExtraInfoDoNotAttachTextService';

final class ApplyOptions {
  const ApplyOptions({
    this.source = TransactionSource.userEdit,
    this.inMemoryUpdate = false,
  });

  /// The source of the transaction. Determines how it's recorded in the
  /// undo/redo history. Defaults to [TransactionSource.userEdit] which
  /// pushes the transaction onto the undo stack.
  final TransactionSource source;

  /// Whether the transaction is an in-memory update.
  final bool inMemoryUpdate;
}

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
}

enum SelectionType { inline, block }

enum TransactionTime { before, after }
