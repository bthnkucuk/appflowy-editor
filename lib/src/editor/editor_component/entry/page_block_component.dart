import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/base_component/widget/ignore_parent_gesture.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class PageBlockKeys {
  static const String type = 'page';
}

// ----------------------------------------------------------------------------
// SuperListView extent hinting
//
// SuperListView measures each child the first time it lays out, but until
// then it has to guess every item's height. A rough per-block-type guess
// keeps `maxScrollExtent`, scrollbar positioning, and index-based jumps
// stable from the first frame. The numbers below are intentionally
// approximate — they're hints, not contracts; real layout still wins.
// ----------------------------------------------------------------------------

const double _defaultBlockExtent = 28.0; // paragraph-ish
const double _headerExtent = 150.0;
const double _footerExtent = 100.0;

const Map<String, double> _blockExtentByType = <String, double>{
  'paragraph': 28.0,
  'todo_list': 32.0,
  'bulleted_list': 28.0,
  'numbered_list': 28.0,
  'quote': 36.0,
  'heading': 44.0, // average across h1–h6
  'divider': 16.0,
  'image': 220.0,
  'table': 180.0,
  'table/cell': 40.0,
  'page': _defaultBlockExtent,
};

double _estimateExtentForNode(Node node) {
  // Heading rows are dramatically different per level; if we have a level
  // attribute, refine. `attributes['level']` is `1..6`. (Reads through the
  // unmodifiable view; cheap.)
  if (node.type == 'heading') {
    final level = node.attributes['level'];
    if (level is int) {
      // Empirical Material-ish line heights, tighter for deeper levels.
      const headingByLevel = <double>[64, 52, 44, 36, 32, 28];
      final idx = (level - 1).clamp(0, headingByLevel.length - 1);
      return headingByLevel[idx];
    }
  }
  return _blockExtentByType[node.type] ?? _defaultBlockExtent;
}

class _SmallDocumentPrecalcPolicy extends ExtentPrecalculationPolicy {
  _SmallDocumentPrecalcPolicy();

  // Threshold borrowed from the package's own example: precalculate the
  // remaining extents only while the list is short enough that the
  // estimation error per item visibly affects the scrollbar. Above this,
  // the cost outweighs the benefit (see package README's "Advanced"
  // section).
  static const int _precalcThreshold = 100;

  @override
  bool shouldPrecalculateExtents(ExtentPrecalculationContext context) {
    return context.numberOfItems < _precalcThreshold;
  }
}

final _smallDocumentPrecalcPolicy = _SmallDocumentPrecalcPolicy();

Node pageNode({
  required Iterable<Node> children,
  Attributes attributes = const {},
}) {
  return Node(
    type: PageBlockKeys.type,
    children: children,
    attributes: attributes,
  );
}

class PageBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return PageBlockComponent(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      header: blockComponentContext.header,
      footer: blockComponentContext.footer,
      wrapper: blockComponentContext.wrapper,
    );
  }
}

class PageBlockComponent extends BlockComponentStatelessWidget {
  const PageBlockComponent({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.header,
    this.footer,
    this.wrapper,
  });

  final Widget? header;
  final Widget? footer;
  final BlockComponentWrapper? wrapper;

  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorState>();
    final scrollController = context.read<EditorScrollController?>();
    final items = node.children;

    if (scrollController == null || scrollController.shrinkWrap) {
      return SingleChildScrollView(
        child: Builder(
          builder: (context) {
            final scroller = Scrollable.maybeOf(context);
            if (scroller != null) {
              editorState.updateAutoScroller(scroller);
            }

            return Column(
              children: [
                ?header,
                ...items.map((e) {
                  Widget child = editorState.renderer.build(context, e);
                  if (wrapper != null) {
                    child = wrapper!(context, node: e, child: child);
                  }

                  return Container(
                    constraints: BoxConstraints(
                      maxWidth:
                          editorState.editorStyle.maxWidth ?? double.infinity,
                    ),
                    padding: editorState.editorStyle.padding,
                    child: child,
                  );
                }),
                ?footer,
              ],
            );
          },
        ),
      );
    } else {
      int extentCount = 0;
      if (header != null) extentCount++;
      if (footer != null) extentCount++;

      return SuperListView.builder(
        shrinkWrap: scrollController.shrinkWrap,
        scrollDirection: Axis.vertical,
        controller: scrollController.scrollController,
        listController: scrollController.listController,
        // Without an estimator SuperListView starts every unmeasured item at
        // its `kDefaultEstimatedItemExtent` (~100 px), then refines as each
        // item lays out. For a long document that initial guess is way off,
        // causing the scrollbar to skitter around and `jumpToIndex` /
        // `pageDown` to land in the wrong place until enough items have
        // been measured. Feeding back a per-block-type estimate lets the
        // list stabilize from the first frame.
        extentEstimation: (index, _) {
          if (index == null) {
            // All-same-extent fast path; return non-zero so the package
            // doesn't ask per index when the list is huge.
            return _defaultBlockExtent;
          }
          if (header != null && index == 0) return _headerExtent;
          if (footer != null && index == (items.length - 1) + extentCount) {
            return _footerExtent;
          }
          final node = items[index - (header != null ? 1 : 0)];
          return _estimateExtentForNode(node);
        },
        // Small-document precision: precalculate real extents when there
        // aren't many items, so the scrollbar tracks exactly. For long
        // documents the package's docs note this has diminishing returns;
        // we skip it.
        extentPrecalculationPolicy: _smallDocumentPrecalcPolicy,
        itemCount: items.length + extentCount,
        itemBuilder: (context, index) {
          editorState.updateAutoScroller(Scrollable.of(context));
          if (header != null && index == 0) {
            return IgnoreEditorSelectionGesture(child: header!);
          }

          if (footer != null && index == (items.length - 1) + extentCount) {
            return IgnoreEditorSelectionGesture(child: footer!);
          }

          final node = items[index - (header != null ? 1 : 0)];
          Widget child = editorState.renderer.build(context, node);
          if (wrapper != null) {
            child = wrapper!(context, node: node, child: child);
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: editorState.editorStyle.maxWidth ?? double.infinity,
              ),
              child: Padding(
                padding: editorState.editorStyle.padding,
                child: child,
              ),
            ),
          );
        },
      );
    }
  }
}
