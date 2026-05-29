part of '../editor_state.dart';

/// Reactive table-of-contents projection of [document]'s headings.
///
/// Exposes a [ValueListenable] of [OutlineEntry] that recomputes on
/// every transaction emitted by [transactionStream]. Consumers bind it
/// to a UI (a ToC sidebar, a wheel, a jump menu) with
/// `ValueListenableBuilder` and don't have to manage the recompute
/// cycle.
///
/// Lazy: the underlying subscription only attaches the first time
/// [tableOfContents] is read, so apps that never surface a ToC pay
/// nothing for it. The notifier is reused across reads — the
/// `ValueNotifier.value` is the cached outline.
///
/// Recompute strategy: walk the document via
/// `Document.computeOutline()` (sparse — headings are rare relative to
/// total nodes), then `listEquals` the result against the cached value
/// before emitting. A keystroke inside a paragraph still triggers a
/// `transactionStream` event, but the resulting outline is byte-equal
/// to the last one and no listeners run. Heading text edits / heading
/// insertions / removals are the only events that actually fire UI
/// updates.
mixin _OutlineMixin {
  Document get document;
  Stream<EditorTransactionValue> get transactionStream;

  ValueNotifier<List<OutlineEntry>>? _outlineNotifier;
  StreamSubscription<EditorTransactionValue>? _outlineSubscription;

  /// Reactive [List<OutlineEntry>] mirroring the current document's
  /// headings. Subscribe with `addListener` or bind via
  /// `ValueListenableBuilder<List<OutlineEntry>>`.
  ///
  /// First read engages the recompute subscription — subsequent reads
  /// return the same notifier. Disposed by EditorState's lifecycle.
  ValueListenable<List<OutlineEntry>> get tableOfContents {
    final existing = _outlineNotifier;
    if (existing != null) return existing;
    final notifier = ValueNotifier<List<OutlineEntry>>(
      document.computeOutline(),
    );
    _outlineNotifier = notifier;
    _outlineSubscription = transactionStream.listen((_) {
      final next = document.computeOutline();
      if (!listEquals(notifier.value, next)) {
        notifier.value = next;
      }
    });
    return notifier;
  }

  void _disposeOutline() {
    _outlineSubscription?.cancel();
    _outlineNotifier?.dispose();
  }
}
