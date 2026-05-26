part of '../editor_state.dart';

/// Transaction broadcast pipeline owned by [EditorState]. Holds the two
/// stream controllers (sync `_observer`, async `_asyncObserver`) that
/// `apply()` writes to before and after every document mutation, plus
/// the [transactionStream] getter consumers depend on.
///
/// Stays library-private (`part of`) so the broadcast helper
/// `_broadcastTransaction` and the close-on-dispose lifecycle aren't
/// surfaced on the public API. Downstream consumers continue to read
/// the public `transactionStream` getter and call `cancelSubscription()`
/// — both kept intact.
///
/// `documentRules` and `_subscription` deliberately stay on EditorState
/// because the rules subscription's callback passes `this` to
/// `DocumentRule.shouldApply(editorState: this)` — that call expects
/// EditorState, which the mixin's `this` is not without a cast.
/// Keeping the setter on the facade avoids that gymnastic.
mixin TransactionPipelineMixin {
  /// listen to this stream to get notified when the transaction applies.
  Stream<EditorTransactionValue> get transactionStream => _observer.stream;

  /// Sync broadcast — listeners run inline with the transaction emit, so
  /// they observe the pre/post-mutation state in the exact slot.
  final StreamController<EditorTransactionValue> _observer =
      StreamController.broadcast(sync: true);

  /// Async broadcast — used by document-rule subscriptions that may
  /// produce follow-up transactions; emitting async prevents reentrant
  /// rule loops within the same microtask.
  final StreamController<EditorTransactionValue> _asyncObserver =
      StreamController.broadcast();

  /// Emit a (before|after) transaction event to both observers. Used
  /// from `apply()`; the closed-check guards prevent writes after
  /// dispose.
  void _broadcastTransaction(
    TransactionTime time,
    Transaction transaction,
    ApplyOptions options,
  ) {
    if (!_observer.isClosed) {
      _observer.add((time, transaction, options));
    }
    if (!_asyncObserver.isClosed) {
      _asyncObserver.add((time, transaction, options));
    }
  }

  /// Closes the sync observer. Public for downstream consumers that
  /// need to stop listening to the transaction stream without disposing
  /// the editor.
  ///
  /// NOTE: deliberately only closes `_observer`, not `_asyncObserver`.
  /// This asymmetry predates the H3.1 refactor; documented here so it's
  /// visible to future readers. See ROADMAP / Analyst B's open question.
  void cancelSubscription() {
    _observer.close();
  }

  void _disposeTransactionPipeline() {
    _observer.close();
    _asyncObserver.close();
  }
}
