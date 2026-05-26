import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'editor/editor_component/service/scroll/auto_scroller.dart';
import 'editor/util/platform_extension.dart';
import 'editor_state/undo_manager.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

export 'editor_state/selection_drag_mode.dart';
export 'editor_state/types.dart';

// Internal mixin files. Kept as `part`/`part of` so they share
// library-level privacy with EditorState — the mixin types themselves
// are library-private (`_` prefix) and the implementation details
// (`_recordRedoOrUndo`, `_disposeXxx`) stay invisible to downstream.
part 'editor_state/document_query_mixin.dart';
part 'editor_state/document_rules_mixin.dart';
part 'editor_state/editor_chrome.dart';
part 'editor_state/editor_service.dart';
part 'editor_state/history_mixin.dart';
part 'editor_state/scroll_coordinator_mixin.dart';
part 'editor_state/selection_style_mixin.dart';
part 'editor_state/table_of_contents.dart';
part 'editor_state/transaction_pipeline_mixin.dart';

/// The state of the editor.
///
/// The state includes:
/// - The document to render
/// - The state of the selection
///
/// [EditorState] also includes the services of the editor:
/// - Selection service
/// - Scroll service
/// - Keyboard service
/// - Input service
/// - Toolbar service
///
/// In consideration of collaborative editing,
/// all the mutations should be applied through [Transaction].
///
/// Mutating the document with document's API is not recommended.
///
/// Internal: the mixin composition lives on [_EditorStateBase] below;
/// EditorState only extends it. Downstream consumers see EditorState
/// as the public API surface — the underscore-prefixed mixin types
/// (`_EditorChromeMixin`, `_HistoryMixin`, …) are library-private and
/// can't be applied to anything outside this library.
abstract class _EditorStateBase
    with
        _EditorChromeMixin,
        _EditorServiceMixin,
        _HistoryMixin,
        _SelectionStyleMixin,
        _ScrollCoordinatorMixin,
        _DocumentQueryMixin,
        _TransactionPipelineMixin,
        _TableOfContentsMixin,
        _DocumentRulesMixin {}

class EditorState extends _EditorStateBase {
  EditorState({
    required this.document,
    this.minHistoryItemDuration = const Duration(milliseconds: 50),
    int? maxHistoryItemSize,
  }) {
    _initHistory(maxHistoryItemSize);
    undoManager.state = this;
    _initDirtyTracking();
    _initTableOfContents();
  }

  EditorState.blank({bool withInitialText = true})
    : this(document: Document.blank(withInitialText: withInitialText));

  // Satisfies [_TransactionPipelineMixin.document] abstract getter.
  @override
  final Document document;

  // the minimum duration for saving the history item.
  // Satisfies [_HistoryMixin.minHistoryItemDuration] abstract getter.
  @override
  final Duration minHistoryItemDuration;

  // Selection/highlight/tap notifiers + selectionType/selectionUpdateReason
  // + selectionExtraInfo live in [_SelectionStyleMixin].
  //
  // Scroll config (disableAutoScroll, autoScrollEdgeOffset),
  // isAutoScrollHighlight, autoScroller, scrollableState,
  // selectionRects/highlightRects, scrollToHighlight + friends,
  // updateAutoScroller, renderBox, and the scroll-view listener set
  // live in [_ScrollCoordinatorMixin].

  // Service-locator surface (selectionService / keyboardService /
  // scrollService / rendererService + their GlobalKeys) lives in
  // [_EditorServiceMixin]. Consumers read them as direct members of
  // EditorState (no `.service.` middleman).

  /// Configures log output parameters,
  /// such as log level and log output callbacks,
  /// with this variable.
  AppFlowyLogConfiguration get logConfiguration => AppFlowyLogConfiguration();

  // transactionStream + _observer + _asyncObserver +
  // _broadcastTransaction + cancelSubscription live in
  // [_TransactionPipelineMixin].
  // toggledStyle / sliceUpcomingAttributes live in [_SelectionStyleMixin].

  Transaction get transaction {
    final transaction = Transaction(document: document);
    transaction.beforeSelection = selection;

    return transaction;
  }

  // documentRules + _subscription live in [_DocumentRulesMixin].

  // updateSelectionWithReason / updateHighlight / updateTap live in
  // [_SelectionStyleMixin].
  //
  // The scroll-view listener set, renderBox, and updateAutoScroller live
  // in [_ScrollCoordinatorMixin].

  final bool _enableCheckIntegrity = false;

  // the value of the notifier is meaningless, just for triggering the callbacks.
  final ValueNotifier<int> onDispose = ValueNotifier(0);

  bool isDisposed = false;

  void dispose() {
    _disposeScrollCoordinator();
    isDisposed = true;
    // ToC listens to the transaction stream — cancel before the stream
    // closes to keep dispose order clean.
    _disposeTableOfContents();
    _disposeTransactionPipeline();
    _disposeHistory();
    onDispose.value += 1;
    onDispose.dispose();
    document.dispose();
    _disposeSelectionStyle();
    disposeChrome();
    _disposeDocumentRules();
  }

  /// Apply the transaction to the state.
  ///
  /// The options can be used to determine whether the editor
  /// should record the transaction in undo/redo stack.
  ///
  /// The maximumRuleApplyLoop is used to prevent infinite loop.
  ///
  /// The withUpdateSelection is used to determine whether the editor
  /// should update the selection after applying the transaction.
  Future<void> apply(
    Transaction transaction, {
    bool isRemote = false,
    ApplyOptions options = const ApplyOptions(),
    bool withUpdateSelection = true,
    bool skipHistoryDebounce = false,
  }) async {
    if (!editable || isDisposed) {
      return;
    }

    // it's a time consuming task, only enable it if necessary.
    if (_enableCheckIntegrity) {
      document.root.checkDocumentIntegrity();
    }

    final completer = Completer<void>();

    if (isRemote) {
      _selectionUpdateReason = SelectionUpdateReason.remote;
      selection = _applyTransactionFromRemote(transaction);
    } else {
      // broadcast to other users here, before applying the transaction
      _broadcastTransaction(TransactionTime.before, transaction, options);

      _applyTransactionInLocal(transaction);

      // broadcast to other users here, after applying the transaction
      _broadcastTransaction(TransactionTime.after, transaction, options);

      _recordRedoOrUndo(options, transaction, skipHistoryDebounce);

      if (withUpdateSelection) {
        _selectionUpdateReason =
            transaction.reason ?? SelectionUpdateReason.transaction;
        _selectionType = transaction.customSelectionType;
        if (transaction.selectionExtraInfo != null) {
          selectionExtraInfo = transaction.selectionExtraInfo;
        }
        selection = transaction.afterSelection;
      }
    }

    completer.complete();

    return completer.future;
  }

  /// Force rebuild the editor.
  void reload() {
    document.root.notify();
  }

  /// get nodes in selection
  ///
  /// if selection is backward, return nodes in order
  /// if selection is forward, return nodes in reverse order
  // getNodesInSelection, getSelectedNodes, getNodeAtPath live in
  // [_DocumentQueryMixin].

  // selectionRects, highlightRects, scrollToHighlight,
  // enableAutoScrollHighlight, disableAutoScrollHighlight,
  // highlightChanged, updateAutoScroller all live in
  // [_ScrollCoordinatorMixin].

  // cancelSubscription lives in [_TransactionPipelineMixin].

  void _applyTransactionInLocal(Transaction transaction) {
    for (final op in transaction.operations) {
      AppFlowyEditorLog.editor.debug('apply op (local): ${op.toJson()}');

      if (op is InsertOperation) {
        document.insert(op.path, op.nodes);
      } else if (op is UpdateOperation) {
        // ignore the update operation if the attributes are the same.
        if (!mapEquals(op.attributes, op.oldAttributes)) {
          document.update(op.path, op.attributes);
        }
      } else if (op is DeleteOperation) {
        document.delete(op.path, op.nodes.length);
      } else if (op is UpdateTextOperation) {
        document.updateText(op.path, op.delta);
      }
    }
  }

  Selection? _applyTransactionFromRemote(Transaction transaction) {
    var selection = this.selection;

    for (final op in transaction.operations) {
      AppFlowyEditorLog.editor.debug('apply op (remote): ${op.toJson()}');

      if (op is InsertOperation) {
        document.insert(op.path, op.nodes);
        if (selection != null) {
          if (op.path <= selection.start.path) {
            selection = Selection(
              start: selection.start.copyWith(
                path: selection.start.path.nextNPath(op.nodes.length),
              ),
              end: selection.end.copyWith(
                path: selection.end.path.nextNPath(op.nodes.length),
              ),
            );
          }
        }
      } else if (op is UpdateOperation) {
        document.update(op.path, op.attributes);
      } else if (op is DeleteOperation) {
        document.delete(op.path, op.nodes.length);
        if (selection != null) {
          if (op.path <= selection.start.path) {
            selection = Selection(
              start: selection.start.copyWith(
                path: selection.start.path.previous,
              ),
              end: selection.end.copyWith(path: selection.end.path.previous),
            );
          }
        }
      } else if (op is UpdateTextOperation) {
        document.updateText(op.path, op.delta);
      }
    }

    return selection;
  }

  /// Scroll the document to the heading represented by [entry] and place
  /// the caret at the heading's start. Resolves [TocEntry.nodeId] to the
  /// current path; falls back to the cached [TocEntry.path] if the node
  /// was deleted between TOC compute and click.
  ///
  /// Uses [scrollService.jumpTo] internally so the call site doesn't need
  /// to thread an `EditorScrollController` through. [scrollService.jumpTo]
  /// addresses top-level children — a nested heading scrolls to its
  /// containing top-level block, which is the best the editor's scroll
  /// API can do today.
  Future<void> jumpToTocEntry(TocEntry entry) async {
    Path? target;
    final iter = NodeIterator(document: document, startNode: document.root);
    while (iter.moveNext()) {
      if (iter.current.id == entry.nodeId) {
        target = iter.current.path;
        break;
      }
    }
    final resolvedPath = target ?? entry.path;
    final topLevelIndex = resolvedPath.firstOrNull ?? 0;

    scrollService?.jumpTo(topLevelIndex);

    // Wait for the scroll-driven layout before placing the caret. Without
    // this await the selection update and the scroll can race, leaving
    // the caret in the previous viewport position.
    await SchedulerBinding.instance.endOfFrame;
    final node = document.nodeAtPath(resolvedPath);
    if (node != null) {
      selectionService.updateSelection(
        Selection.collapsed(Position(path: node.path)),
      );
    }
  }
}
