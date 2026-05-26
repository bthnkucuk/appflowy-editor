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
mixin _TransactionPipelineMixin {
  /// Provided by EditorState — needed only on the rare path where a
  /// transaction's UpdateOperation references a node by path, so we can
  /// recompute its hash from current state.
  Document get document;

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

  // ---------------------------------------------------------------------------
  // Dirty tracking — content-based, incremental.
  //
  // Each node contributes a hash of `(type, attributes)` to a running
  // XOR aggregate. Operations update the aggregate in O(operation size),
  // never re-walking the whole document. The aggregate is compared to a
  // baseline captured at construction and on each `markClean()` — so a
  // sequence of edits that returns the document to byte-identical
  // content (the "type x, delete x, type x" case) restores `isDirty`
  // to false on its own.
  //
  // Hash function: `Object.hash(type, DeepCollectionEquality.hash(attrs))`.
  // Stable across runs is NOT required (we never persist the hash); only
  // determinism within a single editor session matters.
  // ---------------------------------------------------------------------------

  /// `true` when the document content differs from the last clean
  /// snapshot. Listenable for UI bindings (e.g. an unsaved-changes
  /// indicator in the app bar).
  final ValueNotifier<bool> isDirtyNotifier = ValueNotifier<bool>(false);

  bool get isDirty => isDirtyNotifier.value;

  /// Per-node hash, indexed by stable node id. Mutated by
  /// [_applyHashDelta] as operations apply.
  final Map<String, int> _nodeHashes = <String, int>{};

  /// XOR of every entry in [_nodeHashes]. Maintained incrementally — no
  /// full tree walk on each transaction. Re-derivable by re-walking via
  /// [_initDirtyTracking] / [markClean].
  int _aggregateHash = 0;

  /// Aggregate at the last clean point. `null` until
  /// [_initDirtyTracking] runs.
  int? _cleanAggregateHash;

  /// Walk the document once at editor construction to seed the hash
  /// dictionary and the clean baseline. Called from EditorState's
  /// constructor.
  void _initDirtyTracking() {
    for (final n in document.root.children) {
      _addSubtree(n);
    }
    _cleanAggregateHash = _aggregateHash;
  }

  /// Snapshot the current document as the new clean baseline and reset
  /// the dirty flag. Call after persisting.
  void markClean() {
    _cleanAggregateHash = _aggregateHash;
    if (isDirtyNotifier.value) {
      isDirtyNotifier.value = false;
    }
  }

  /// Emit a (before|after) transaction event to both observers, and on
  /// the after-emit apply the hash delta from this transaction. The
  /// closed-check guards prevent writes after dispose.
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
    if (time == TransactionTime.after) {
      _applyHashDelta(transaction);
    }
  }

  /// Walk the transaction's operations and adjust the running hash
  /// incrementally. Each op is O(affected node + its descendants),
  /// not O(document size).
  void _applyHashDelta(Transaction transaction) {
    if (_cleanAggregateHash == null) {
      // Dirty tracking hasn't been seeded yet (mid-construction).
      return;
    }
    for (final op in transaction.operations) {
      if (op is InsertOperation) {
        for (final n in op.nodes) {
          _addSubtree(n);
        }
      } else if (op is DeleteOperation) {
        for (final n in op.nodes) {
          _removeSubtree(n);
        }
      } else if (op is UpdateOperation) {
        _refreshNodeAtPath(op.path);
      } else if (op is UpdateTextOperation) {
        _refreshNodeAtPath(op.path);
      }
    }
    final dirty = _aggregateHash != _cleanAggregateHash;
    if (isDirtyNotifier.value != dirty) {
      isDirtyNotifier.value = dirty;
    }
  }

  /// Recompute hash for the node at [path] (post-mutation state) and
  /// fold the delta into the aggregate. Used by UpdateOperation and
  /// UpdateTextOperation, both of which mutate a single node's content
  /// without changing its tree position.
  void _refreshNodeAtPath(Path path) {
    final node = document.nodeAtPath(path);
    if (node == null) return;
    final oldH = _nodeHashes[node.id] ?? 0;
    final newH = _hashNode(node);
    if (oldH == newH) return;
    _aggregateHash ^= oldH ^ newH;
    _nodeHashes[node.id] = newH;
  }

  /// XOR the hash of [n] and all its descendants into the aggregate
  /// and record them in [_nodeHashes]. Used for InsertOperation and
  /// the initial document walk.
  void _addSubtree(Node n) {
    final h = _hashNode(n);
    _nodeHashes[n.id] = h;
    _aggregateHash ^= h;
    for (final child in n.children) {
      _addSubtree(child);
    }
  }

  /// XOR out the hashes of [n] and all its descendants and drop them
  /// from [_nodeHashes]. Used for DeleteOperation. The deleted Node
  /// keeps its `id` and `children` accessible after unlink, so this is
  /// safe to call from the after-broadcast.
  void _removeSubtree(Node n) {
    final h = _nodeHashes.remove(n.id);
    if (h != null) {
      _aggregateHash ^= h;
    }
    for (final child in n.children) {
      _removeSubtree(child);
    }
  }

  /// Content-only fingerprint of a single node. Excludes children
  /// (they're hashed separately and XOR'd in) — keeps mutations local:
  /// an attribute change on a leaf doesn't ripple a re-hash up the
  /// parent chain.
  int _hashNode(Node n) {
    const deepEq = DeepCollectionEquality();
    return Object.hash(n.type, deepEq.hash(n.attributes));
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
    isDirtyNotifier.dispose();
    _nodeHashes.clear();
  }
}
