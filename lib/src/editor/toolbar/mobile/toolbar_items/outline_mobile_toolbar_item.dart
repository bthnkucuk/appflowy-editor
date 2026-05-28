import 'package:appflowy_editor/appflowy_editor.dart';

/// Mobile toolbar item that immediately inserts an [outlineBlockNode]
/// (auto table-of-contents block) after the current selection — no
/// sheet, no extra prompt. Mirrors the `dividerMobileToolbarItem`
/// pattern for single-tap inserts.
///
/// Use this when you want a quick "add TOC here" affordance distinct
/// from the navigator-style [OutlineMobileSheet] (which is opened from
/// the extras menu and used for jumping between headings).
final outlineMobileToolbarItem = MobileToolbarItem(
  itemIconBuilder: (context, _) => ToolbarIcon(
    icon: ToolbarIcons.outline,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (_, editorState) {
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }
    final path = selection.end.path;
    final node = editorState.getNodeAtPath(path);
    final delta = node?.delta;
    if (node == null || delta == null) {
      return;
    }
    // If the cursor sits on an empty paragraph the outline replaces it
    // in place; otherwise we insert below.
    final insertedPath = delta.isEmpty ? path : path.next;
    final transaction = editorState.transaction;
    transaction.insertNode(insertedPath, outlineBlockNode());
    // Append a trailing paragraph so the user has a place to keep typing
    // after the block is inserted. Mirrors the divider toolbar item.
    final next = node.next;
    if (next == null ||
        next.type != ParagraphBlockKeys.type ||
        next.delta?.isNotEmpty == true) {
      transaction.insertNode(insertedPath.next, paragraphNode());
    }
    transaction.afterSelection = Selection.collapsed(
      Position(path: insertedPath.next),
    );
    editorState.apply(transaction);
  },
);
