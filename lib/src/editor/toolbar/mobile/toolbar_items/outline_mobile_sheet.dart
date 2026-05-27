import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Mobile outline / table-of-contents sheet. Thin wrapper around
/// [OutlineListView] (the same widget the inline outline block uses)
/// plus a header — guarantees the sheet's heading list and any
/// in-document outline block stay byte-identical. Tap on a heading row
/// pops the sheet and jumps the editor to that heading via
/// [EditorState.jumpToOutlineEntry].
///
/// The header also offers a one-tap action to either insert an
/// [outlineBlockNode] (auto TOC) at the current selection (when no
/// outline block exists in the document) or scroll to the existing one.
///
/// Designed to drop into a [StupidSimpleSheetRoute] wrapped with
/// `EditorToolbarSheetScaffold` — matches the rest of the mobile toolbar
/// sheet system.
class OutlineMobileSheet extends StatefulWidget {
  const OutlineMobileSheet({super.key, required this.editorState});

  final EditorState editorState;

  @override
  State<OutlineMobileSheet> createState() => _OutlineMobileSheetState();
}

class _OutlineMobileSheetState extends State<OutlineMobileSheet> {
  /// First top-level `outline` node in the document, if any. Used by
  /// the header to switch between "insert" and "scroll-to" affordances.
  Node? _findExistingOutlineNode() {
    final iter = NodeIterator(
      document: widget.editorState.document,
      startNode: widget.editorState.document.root,
    );
    while (iter.moveNext()) {
      if (iter.current.type == OutlineBlockKeys.type) {
        return iter.current;
      }
    }
    return null;
  }

  Future<void> _insertOutlineNode() async {
    final navigator = Navigator.of(context);
    final editorState = widget.editorState;
    final selection = editorState.selection;
    final t = editorState.transaction;
    if (selection != null) {
      final path = selection.end.path.next;
      t.insertNode(path, outlineBlockNode());
    } else {
      // No selection — append at end of doc.
      final lastIndex = editorState.document.root.children.length;
      t.insertNode([lastIndex], outlineBlockNode());
    }
    await editorState.apply(t);
    if (mounted) navigator.pop();
  }

  Future<void> _scrollToOutlineNode(Node node) async {
    final navigator = Navigator.of(context);
    final editorState = widget.editorState;
    editorState.scrollService?.jumpTo(node.path.first);
    editorState.selectionService.updateSelection(
      Selection.collapsed(Position(path: node.path)),
    );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EditorTransactionValue>(
      stream: widget.editorState.transactionStream,
      builder: (context, _) {
        final theme = Theme.of(context);
        final existing = _findExistingOutlineNode();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Table of contents',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (existing == null)
                    TextButton.icon(
                      onPressed: _insertOutlineNode,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Insert in document'),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _scrollToOutlineNode(existing),
                      icon: const Icon(
                        Icons.center_focus_strong,
                        size: 18,
                      ),
                      label: const Text('Scroll to block'),
                    ),
                ],
              ),
              const Divider(height: 16, thickness: 0.5),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: OutlineListView(
                    editorState: widget.editorState,
                    onTap: (entry) async {
                      Navigator.of(context).pop();
                      await widget.editorState.jumpToOutlineEntry(entry);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
