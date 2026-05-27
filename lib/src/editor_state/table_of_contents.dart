part of '../editor_state.dart';

/// A single heading entry in the document outline.
///
/// Flat data (no `children` list) — hierarchy is rendered by indenting on
/// [level]. This matches Google Docs / Notion / TipTap: real documents
/// skip levels (H1 → H3 with no H2), and a nested tree forces awkward
/// placeholder parents for the skips. Indent-by-level handles every
/// case correctly at the render layer.
class TocEntry extends Equatable {
  const TocEntry({
    required this.text,
    required this.level,
    required this.nodeId,
    required this.path,
    required this.isNested,
  });

  /// Plain-text content of the heading at compute time. May lag by one
  /// frame on rapid edits — fine for a sidebar UI.
  final String text;

  /// Heading level 1..6, read from `node.attributes[HeadingBlockKeys.level]`.
  ///
  /// NOT [NodeExtensions.level], which returns the *tree depth* of the
  /// node. The pre-refactor `Document.calculateTableOfContents` confused
  /// those two and stored tree depth in every entry — see
  /// commit history if you need the gory details.
  final int level;

  /// Stable across edits — primary jump key. Resolve to current path at
  /// click time via NodeIterator. Survives the heading moving through
  /// the tree, which the old `Selection`-based key did not.
  final String nodeId;

  /// Path *as of compute time*. Refreshed every recompute. Use only as
  /// a fallback when [nodeId] resolution fails (heading was deleted
  /// between recompute and click) or for cheap "currently scrolled to"
  /// comparison against the active selection.
  final Path path;

  /// `true` when the heading lives inside a non-page parent (list
  /// item, blockquote, column, callout). Useful for UI dimming or
  /// annotation — these headings still appear in the outline, but they
  /// scroll to their containing top-level block rather than to
  /// themselves.
  final bool isNested;

  @override
  List<Object?> get props => [text, level, nodeId, path, isNested];
}

/// Live outline of the document — list of headings extracted from every
/// `HeadingBlockKeys.type` node in the tree (including nested ones).
/// Recomputes after every transaction that could touch a heading,
/// coalesced to once per microtask so a paste with N headings or a
/// transaction with downstream rule-driven follow-ups stays at one walk.
///
/// Full-walk-on-touch rather than operation-incremental: headings are
/// sparse (a 50-page document has ~100 of them), the walk is dominated
/// by `NodeIterator.moveNext` and per-node attribute lookups, and the
/// operation log doesn't carry "heading-ness" directly — an
/// `UpdateOperation` flipping `type` from `paragraph` to `heading` looks
/// identical to any other attribute update from the outside. The
/// incremental machinery would cost more in cognitive load than it
/// saves at realistic document sizes. See `_TransactionPipelineMixin`'s
/// hash-delta for the cases where incremental DOES earn its keep.
mixin _TableOfContentsMixin {
  Document get document;
  Stream<EditorTransactionValue> get transactionStream;

  final ValueNotifier<List<TocEntry>> _tocNotifier = ValueNotifier<List<TocEntry>>(const []);

  /// Public live outline. Render with `(level - 1) * indentStep` for
  /// Word-style indentation.
  ValueListenable<List<TocEntry>> get tableOfContents => _tocNotifier;

  StreamSubscription<EditorTransactionValue>? _tocSubscription;
  bool _tocRecomputeScheduled = false;

  void _initTableOfContents() {
    _recomputeToc();
    _tocSubscription = transactionStream.listen((event) {
      final (time, transaction, _) = event;
      if (time != TransactionTime.after) return;
      if (!_transactionMayAffectToc(transaction)) return;
      _scheduleTocRecompute();
    });
  }

  /// Coarse-grained "did this transaction maybe touch a heading?" check.
  /// Conservative — false positives are fine (extra walk, no harm),
  /// false negatives are NOT (stale TOC).
  ///
  /// Pays off in the common typing case: an `UpdateTextOperation` on a
  /// paragraph (not a heading) skips the recompute entirely. Users
  /// typically edit body text, not headings, so this guards the hot
  /// path.
  bool _transactionMayAffectToc(Transaction t) {
    for (final op in t.operations) {
      if (op is InsertOperation || op is DeleteOperation) {
        // Inserting or deleting *anything* can shift heading paths, so
        // conservatively always recompute.
        return true;
      }
      if (op is UpdateOperation) {
        // Attribute change on the node at op.path. Worth a recompute if
        // either the type or the heading level is involved, or if the
        // node is already a heading (so a delta edit on the heading
        // changes its text).
        if (op.attributes.containsKey('type') || op.attributes.containsKey(HeadingBlockKeys.level)) {
          return true;
        }
        final node = document.nodeAtPath(op.path);
        if (node?.type == HeadingBlockKeys.type) return true;
      } else if (op is UpdateTextOperation) {
        // Text edit only matters if it's on a heading.
        final node = document.nodeAtPath(op.path);
        if (node?.type == HeadingBlockKeys.type) return true;
      }
    }
    return false;
  }

  void _scheduleTocRecompute() {
    if (_tocRecomputeScheduled) return;
    _tocRecomputeScheduled = true;
    scheduleMicrotask(() {
      _tocRecomputeScheduled = false;
      _recomputeToc();
    });
  }

  void _recomputeToc() {
    final entries = <TocEntry>[];
    final iter = NodeIterator(document: document, startNode: document.root);
    while (iter.moveNext()) {
      final node = iter.current;
      if (node.type != HeadingBlockKeys.type) continue;
      final text = node.delta?.toPlainText() ?? '';
      if (text.isEmpty) continue; // Drop empty-text headings (matches Notion).
      final rawLevel = node.attributes[HeadingBlockKeys.level];
      final level = rawLevel is int ? rawLevel.clamp(1, 6) : 1;
      entries.add(
        TocEntry(
          text: text,
          level: level,
          nodeId: node.id,
          path: node.path,
          // "Nested" = parent is not the page root. document.root has no
          // grandparent; a top-level heading's parent IS the page root,
          // so node.parent?.parent is null. Headings inside lists /
          // columns have a non-null grandparent.
          isNested: node.parent?.parent != null,
        ),
      );
    }
    // ValueNotifier fires on identity change of the new value. Without
    // this guard, every transaction would emit a new list reference
    // even when the outline didn't change — rebuilding every listener.
    if (!const ListEquality<TocEntry>().equals(_tocNotifier.value, entries)) {
      _tocNotifier.value = entries;
    }
  }

  void _disposeTableOfContents() {
    _tocSubscription?.cancel();
    _tocNotifier.dispose();
  }
}
