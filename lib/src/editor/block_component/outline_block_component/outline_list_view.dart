import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Shared list-of-headings widget. Single source of truth used by both
/// [OutlineBlockComponentWidget] (in-document block) and the mobile
/// outline sheet (bottom modal). Both placements render the same data —
/// `editorState.document.computeOutline()` — through the same row widget,
/// so there is no duplication between "navigator" and "content" surfaces.
///
/// Re-renders on every transaction by listening to
/// `editorState.transactionStream`. Walk is cheap (sparse headings), no
/// microtask coalesce — the previous TOC mixin had one but it was
/// premature for realistic doc sizes.
class OutlineListView extends StatefulWidget {
  const OutlineListView({
    super.key,
    required this.editorState,
    this.maxDepth = 6,
    this.indentStep = 16,
    this.maxHeight,
    this.onTap,
    this.emptyBuilder,
  });

  final EditorState editorState;

  /// Heading levels above this number are filtered out. 1..6. Default 6.
  final int maxDepth;

  /// Logical pixels added per level. The row indents
  /// `(level - 1) * indentStep`.
  final double indentStep;

  /// When non-null, the list is bounded to this height and overflow
  /// scrolls vertically with a scrollbar. When null, all rows render
  /// inline as an unbounded [Column] — the caller is responsible for
  /// placing it in a scrollable parent.
  ///
  /// Both the inline block component and the bottom-sheet wrap pass a
  /// concrete value so a 200-heading document doesn't blow out the
  /// containing layout.
  final double? maxHeight;

  /// Override the default jump behavior. Default calls
  /// `editorState.jumpToOutlineEntry`. Pass a callback (e.g. to pop a
  /// sheet first) to override.
  final void Function(OutlineEntry entry)? onTap;

  /// Builder for the empty state. Default renders a centered hint.
  final WidgetBuilder? emptyBuilder;

  @override
  State<OutlineListView> createState() => _OutlineListViewState();
}

class _OutlineListViewState extends State<OutlineListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EditorTransactionValue>(
      stream: widget.editorState.transactionStream,
      builder: (context, _) {
        final entries =
            widget.editorState.document.computeOutline(maxDepth: widget.maxDepth);
        if (entries.isEmpty) {
          return widget.emptyBuilder?.call(context) ?? _defaultEmpty(context);
        }

        Widget buildRow(int i) => OutlineEntryRow(
              entry: entries[i],
              indentStep: widget.indentStep,
              onTap: () =>
                  (widget.onTap ?? widget.editorState.jumpToOutlineEntry)
                      .call(entries[i]),
            );

        if (widget.maxHeight == null) {
          // No height constraint — let the caller handle scrolling.
          // Cheaper than a ListView because outlines tend to fit on one
          // screen in this branch; allocating a viewport is overkill.
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (int i = 0; i < entries.length; i++) buildRow(i)],
          );
        }

        // Bounded: lazy ListView.builder inside a ConstrainedBox so a
        // long outline scrolls instead of pushing the surrounding
        // layout. Scrollbar gives a visible affordance.
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight!),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: false,
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (context, i) => buildRow(i),
            ),
          ),
        );
      },
    );
  }

  Widget _defaultEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'No headings yet — add an H1/H2/H3 to populate the outline.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

/// Single row in [OutlineListView]. Public so consumers building a
/// custom layout (e.g. a numbered TOC, a sidebar panel) can reuse the
/// indent + typography rules.
class OutlineEntryRow extends StatelessWidget {
  const OutlineEntryRow({
    super.key,
    required this.entry,
    required this.indentStep,
    required this.onTap,
  });

  final OutlineEntry entry;
  final double indentStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = (entry.level - 1) * indentStep;
    // H1 sets the visual baseline; each level below trims 1px and
    // softens weight (H1/H2 bold, H3-H6 regular).
    final fontSize = (16 - (entry.level - 1)).clamp(12, 16).toDouble();
    final weight = entry.level <= 2 ? FontWeight.w600 : FontWeight.w400;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4 + indent, 10, 4, 10),
        child: Text(
          entry.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: entry.isNested
                ? theme.colorScheme.outline
                : theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
