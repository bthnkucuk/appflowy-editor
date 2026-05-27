import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Mobile outline / table-of-contents sheet, ported from the example's
/// `_TocSheet`. Renders [EditorState.tableOfContents] as a tappable list
/// of headings; tapping a row pops the sheet and scrolls the editor to
/// that heading via [EditorTableOfContentsExtension.jumpToTocEntry].
///
/// Designed to drop into a [StupidSimpleSheetRoute] wrapped with
/// `EditorToolbarSheetScaffold` — matches the rest of the mobile
/// toolbar sheet system. Empty document case shows a hint instead of a
/// blank panel.
class OutlineMobileSheet extends StatelessWidget {
  const OutlineMobileSheet({super.key, required this.editorState});

  final EditorState editorState;

  static const double _indentStep = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Table of contents', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 16, thickness: 0.5),
          ValueListenableBuilder<List<TocEntry>>(
            valueListenable: editorState.tableOfContents,
            builder: (context, entries, _) {
              if (entries.isEmpty) {
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
              // Fixed-ish height keeps the sheet from growing too tall on
              // long outlines while still letting the user scroll.
              final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _Entry(
                    entry: entries[i],
                    indentStep: _indentStep,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await editorState.jumpToTocEntry(entries[i]);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.entry,
    required this.indentStep,
    required this.onTap,
  });

  final TocEntry entry;
  final double indentStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = (entry.level - 1) * indentStep;
    // H1 sets the visual baseline — bold + 16 px. Each level below trims
    // 1 px and softens weight.
    final fontSize = (16 - (entry.level - 1)).clamp(12, 16).toDouble();
    final weight =
        entry.level <= 2 ? FontWeight.w600 : FontWeight.w400;
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
