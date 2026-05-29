import 'dart:collection';

import 'package:appflowy_editor/appflowy_editor.dart';

/// [Document] represents an AppFlowy Editor document structure.
///
/// It stores the root of the document.
///
/// **DO NOT** directly mutate the properties of a [Document] object.
///
class Document {
  Document({required this.root}) {
    // Back-pointer so any Node in this tree can resolve its owning
    // Document via the parent-chain walk (`Node.document` getter) and
    // read the per-Document `sectionParser`.
    root.attachAsRoot(this);
  }

  /// Constructs a [Document] from a JSON strcuture.
  ///
  /// _Example of a [Document] in JSON format:_
  /// ```
  /// {
  ///   'document': {
  ///     'type': 'page',
  ///     'children': [
  ///       {
  ///         'type': 'paragraph',
  ///         'data': {
  ///           'delta': [
  ///             { 'insert': 'Welcome ' },
  ///             { 'insert': 'to ' },
  ///             { 'insert': 'AppFlowy!' }
  ///           ]
  ///         }
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  ///
  factory Document.fromJson(Map<String, dynamic> json) {
    assert(json['document'] is Map);

    final document = Map<String, Object>.from(json['document'] as Map);
    final root = Node.fromJson(document);

    // `Document(root: ...)` calls `root.attachAsRoot(this)` so the
    // back-pointer survives both factory paths.
    return Document(root: root);
  }

  /// Creates a blank [Document] containing an empty root [Node].
  ///
  /// If [withInitialText] is true, the document will contain an empty
  /// paragraph [Node].
  ///
  factory Document.blank({bool withInitialText = false}) {
    final root = Node(
      type: 'page',
      children: withInitialText ? [paragraphNode()] : [],
    );

    return Document(root: root);
  }

  /// The root [Node] of the [Document]
  final Node root;

  /// Per-Document section parser. Replaces the deprecated process-global
  /// `Node.sectionParser` static — keeping ownership on the Document
  /// avoids cross-page leakage (one editor's parser bleeding into
  /// another's nodes) and lets parsers swap without coordinating a
  /// save/restore around the static.
  ///
  /// `Node.sections` is computed lazily on read and reuses the cached
  /// result until either the node's delta reference changes or the
  /// parser identity changes.
  Sections? Function(Node node)? sectionParser;

  /// First node of the document.
  Node? get first => root.children.firstOrNull;

  /// All nodes of the document.
  List<Node> get nodes => root.children;

  /// Last node of the document.
  Node? get last {
    Node? current = root.children.lastOrNull;
    while (current != null && current.children.isNotEmpty) {
      current = current.children.last;
    }

    return current;
  }

  /// Must call this method when the [Document] is no longer needed.
  void dispose() {
    final nodes = NodeIterator(document: this, startNode: root).toList();
    for (final node in nodes) {
      node.dispose();
    }
  }

  /// Returns the node at the given [path].
  Node? nodeAtPath(Path path) {
    return root.childAtPath(path);
  }

  bool insertNodesToEndOfDocument(Iterable<Node> nodes) {
    if (nodes.isEmpty) {
      return false;
    }

    final path = this.nodes.last.path;

    final target = nodeAtPath(path);
    if (target != null) {
      for (final node in nodes) {
        target.insertBefore(node);
      }
      return true;
    }

    final parent = nodeAtPath(path.parent);
    if (parent != null) {
      for (var i = 0; i < nodes.length; i++) {
        parent.insert(nodes.elementAt(i), index: path.last + i);
      }
      return true;
    }

    return false;
  }

  bool insetAtRootRank(String rank, Node node) {
    try {
      // if the rank is already exists, it will throw an error
      root.insertAtRank(rank, node);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Inserts a [Node]s at the given [Path].
  bool insert(Path path, Iterable<Node> nodes) {
    if (path.isEmpty || nodes.isEmpty) {
      return false;
    }

    final target = nodeAtPath(path);
    if (target != null) {
      for (final node in nodes) {
        target.insertBefore(node);
      }

      return true;
    }

    final parent = nodeAtPath(path.parent);
    if (parent != null) {
      for (var i = 0; i < nodes.length; i++) {
        parent.insert(nodes.elementAt(i), index: path.last + i);
      }

      return true;
    }

    return false;
  }

  /// Deletes the [Node]s at the given [Path].
  bool delete(Path path, [int length = 1]) {
    if (path.isEmpty || length <= 0) {
      return false;
    }
    var target = nodeAtPath(path);
    if (target == null) {
      return false;
    }
    while (target != null && length > 0) {
      final next = target.next;
      target.unlink();
      target = next;
      length--;
    }

    return true;
  }

  /// Updates the [Node] at the given [Path]
  bool update(Path path, Attributes attributes) {
    // if the path is empty, it means the root node.
    if (path.isEmpty) {
      root.updateAttributes(attributes);

      return true;
    }
    final target = nodeAtPath(path);
    if (target == null) {
      return false;
    }
    target.updateAttributes(attributes);

    return true;
  }

  /// Updates the [Node] with [Delta] at the given [Path]
  bool updateText(Path path, Delta delta) {
    if (path.isEmpty) {
      return false;
    }
    final target = nodeAtPath(path);
    final targetDelta = target?.delta;
    if (target == null || targetDelta == null) {
      return false;
    }
    target.updateAttributes({'delta': (targetDelta.compose(delta)).toJson()});

    return true;
  }

  /// Returns whether the root [Node] does not contain
  /// any text.
  ///
  bool get isEmpty {
    if (root.children.isEmpty) {
      return true;
    }

    if (root.children.length > 1) {
      return false;
    }

    final node = root.children.first;
    final delta = node.delta;
    if (delta != null && (delta.isEmpty || delta.toPlainText().isEmpty)) {
      return true;
    }

    return false;
  }

  /// Encodes the [Document] into a JSON structure.
  ///
  Map<String, Object> toJson({
    bool includeDatabaseIndex = true,
    bool includeId = true,
    bool includeRank = true,
  }) {
    return {
      'document': root.toJson(
        includeDatabaseIndex: includeDatabaseIndex,
        includeId: includeId,
        includeRank: includeRank,
      ),
    };
  }
}
