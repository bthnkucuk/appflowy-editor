import 'package:equatable/equatable.dart';

import '../../editor/block_component/heading_block_component/heading_block_component.dart';
import 'document.dart';
import 'node_iterator.dart';
import 'path.dart';

/// A single heading entry produced by [DocumentOutline.computeOutline].
///
/// Flat data (no `children` list) — hierarchy is rendered by indenting on
/// [level]. This matches Google Docs / Notion / TipTap: real documents
/// skip levels (H1 → H3 with no H2), and a nested tree forces awkward
/// placeholder parents for the skips. Indent-by-level handles every
/// case correctly at the render layer.
class OutlineEntry extends Equatable {
  const OutlineEntry({
    required this.text,
    required this.level,
    required this.nodeId,
    required this.path,
    required this.isNested,
  });

  /// Plain-text content of the heading at compute time.
  final String text;

  /// Heading level 1..6, read from `node.attributes[HeadingBlockKeys.level]`.
  final int level;

  /// Stable across edits — primary jump key. Resolve to current path at
  /// click time via [NodeIterator]. Survives the heading moving through
  /// the tree.
  final String nodeId;

  /// Path *as of compute time*. Use only as a fallback when [nodeId]
  /// resolution fails (heading was deleted between recompute and click)
  /// or for cheap "currently scrolled to" comparison.
  final Path path;

  /// `true` when the heading lives inside a non-page parent (list item,
  /// blockquote, column, callout). Useful for UI dimming — these
  /// headings still appear in the outline, but they scroll to their
  /// containing top-level block rather than to themselves.
  final bool isNested;

  @override
  List<Object?> get props => [text, level, nodeId, path, isNested];
}

extension DocumentOutline on Document {
  /// Walk the document and collect every `HeadingBlockKeys.type` node
  /// into a flat [OutlineEntry] list.
  ///
  /// - Empty-text headings are dropped (matches Notion's behavior — an
  ///   empty heading is usually a stub the user hasn't filled in).
  /// - Levels are clamped to 1..6.
  /// - Pass [maxDepth] (1..6) to filter — entries with `level > maxDepth`
  ///   are skipped. Default 6 (no filter).
  ///
  /// Full-walk: headings are sparse (a 50-page document has ~100 of
  /// them), the walk is dominated by `NodeIterator.moveNext` and
  /// per-node attribute lookups, and the operation log doesn't carry
  /// "heading-ness" directly. The incremental machinery would cost
  /// more in cognitive load than it saves at realistic document sizes.
  List<OutlineEntry> computeOutline({int maxDepth = 6}) {
    final entries = <OutlineEntry>[];
    final iter = NodeIterator(document: this, startNode: root);
    while (iter.moveNext()) {
      final node = iter.current;
      if (node.type != HeadingBlockKeys.type) continue;
      final text = node.delta?.toPlainText() ?? '';
      if (text.isEmpty) continue;
      final rawLevel = node.attributes[HeadingBlockKeys.level];
      final level = rawLevel is int ? rawLevel.clamp(1, 6) : 1;
      if (level > maxDepth) continue;
      entries.add(
        OutlineEntry(
          text: text,
          level: level,
          nodeId: node.id,
          path: node.path,
          isNested: node.parent?.parent != null,
        ),
      );
    }
    return entries;
  }
}
