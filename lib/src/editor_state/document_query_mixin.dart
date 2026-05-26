part of '../editor_state.dart';

/// Document-traversal helpers that live on [EditorState] for callers'
/// convenience but have no state of their own — they just walk the
/// document tree.
///
/// Kept as a mixin (rather than free functions or a Document method)
/// because the most common callsites already hold an [EditorState]
/// reference and the [getSelectedNodes] convenience reads the editor's
/// current [selection] when the caller doesn't supply one.
///
/// Satisfies the abstract [_ScrollCoordinatorMixin.getNodesInSelection]
/// — the scroll coordinator needs to know which nodes a selection
/// intersects so auto-scroll-to-highlight can compute rects.
mixin _DocumentQueryMixin {
  // ---------------------------------------------------------------------------
  // Abstract dependencies (provided by EditorState + other mixins)
  // ---------------------------------------------------------------------------

  /// Provided by EditorState — the document tree these helpers walk.
  Document get document;

  /// Provided by [_SelectionStyleMixin] — used by [getSelectedNodes]
  /// as the implicit selection when the caller doesn't pass one.
  Selection? get selection;

  // ---------------------------------------------------------------------------
  // Query helpers
  // ---------------------------------------------------------------------------

  /// Returns nodes intersecting [selection], in document order (or
  /// reverse for a forward selection — see [Selection.isForward]).
  List<Node> getNodesInSelection(Selection selection) {
    final normalized = selection.normalized;
    final startNode = document.nodeAtPath(normalized.start.path);
    final endNode = document.nodeAtPath(normalized.end.path);

    if (startNode != null && endNode != null) {
      final nodes = NodeIterator(
        document: document,
        startNode: startNode,
        endNode: endNode,
      ).toList();

      return selection.isForward ? nodes.reversed.toList() : nodes;
    }

    return [];
  }

  /// Returns the deduplicated, optionally deep-copied set of nodes
  /// covered by [selection] (or the current editor selection if null).
  /// Slices the first and last node's delta down to the selection
  /// range so the result is ready for clipboard / serialization paths.
  ///
  /// [withCopy] controls whether the returned nodes are detached
  /// copies or live document references. Default `true` because most
  /// callers (copy/cut) mutate the result without wanting to touch
  /// the original tree.
  List<Node> getSelectedNodes({Selection? selection, bool withCopy = true}) {
    List<Node> res = [];
    selection ??= this.selection;
    if (selection == null) {
      return res;
    }
    final nodes = getNodesInSelection(selection);
    for (final node in nodes) {
      if (res.any((element) => element.isParentOf(node))) {
        continue;
      }
      res.add(node);
    }

    if (withCopy) {
      res = res.map((e) => e.copyWith()).toList();
    }

    if (res.isNotEmpty) {
      var delta = res.first.delta;
      if (delta != null) {
        res.first.updateAttributes({
          ...res.first.attributes,
          blockComponentDelta: delta
              .slice(
                selection.startIndex,
                selection.isSingle ? selection.endIndex : delta.length,
              )
              .toJson(),
        });
      }

      var node = res.last;
      while (node.children.isNotEmpty) {
        node = node.children.last;
      }
      delta = node.delta;
      if (delta != null && !selection.isSingle) {
        if (node.parent != null) {
          node.insertBefore(
            node.copyWith(
              attributes: {
                ...node.attributes,
                blockComponentDelta: delta
                    .slice(0, selection.endIndex)
                    .toJson(),
              },
            ),
          );
          node.unlink();
        } else {
          node.updateAttributes({
            ...node.attributes,
            blockComponentDelta: delta.slice(0, selection.endIndex).toJson(),
          });
        }
      }
    }

    return res;
  }

  /// Returns the node at [path], or `null` if the path is outside the
  /// document. Thin wrapper over [Document.nodeAtPath] — kept here so
  /// callers can reach it via the editor state without holding a
  /// document reference.
  Node? getNodeAtPath(Path path) {
    return document.nodeAtPath(path);
  }
}
