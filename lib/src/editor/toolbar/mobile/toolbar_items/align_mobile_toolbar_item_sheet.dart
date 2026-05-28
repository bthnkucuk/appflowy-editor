import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Mobile toolbar item that opens a sheet with the four block-alignment
/// options (left, center, right, justify). Tap a cell to toggle the
/// current node's `blockComponentAlign` attribute. Tapping the same
/// option that's already active clears the alignment (back to default).
///
/// Visually parallels [blocksMobileToolbarItemSheet]: horizontal-scroll
/// row of squircle cells, icon + label per cell, the active option
/// renders selected via the Phosphor Fill swap inside
/// [EditorToolbarMenuButton].
final MobileToolbarItem alignMobileToolbarItemSheet = MobileToolbarItem.sheet(
  itemIconBuilder: (context, _) => ToolbarIcon(
    icon: ToolbarIcons.alignLeft,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  sheetBodyBuilder: (context, editorState, selection) =>
      _SheetAlignMenu(editorState, selection),
);

class _SheetAlignMenu extends StatefulWidget {
  const _SheetAlignMenu(this.editorState, this.selection);

  final EditorState editorState;
  final Selection selection;

  @override
  State<_SheetAlignMenu> createState() => _SheetAlignMenuState();
}

class _SheetAlignMenuState extends State<_SheetAlignMenu> {
  @override
  void initState() {
    super.initState();
    widget.editorState.selectionNotifier.addListener(_pinSelection);
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_pinSelection);
    super.dispose();
  }

  void _pinSelection() {
    if (!mounted) return;
    if (widget.editorState.selection == widget.selection) return;
    widget.editorState.updateSelectionWithReason(
      widget.selection,
      extraInfo: {
        selectionExtraInfoDisableMobileToolbarKey: true,
        selectionExtraInfoDisableFloatingToolbar: true,
        selectionExtraInfoDoNotAttachTextService: true,
      },
    );
  }

  // Order matters — the row reads left → center → right → justify so
  // users encounter alignments in their typographic order.
  static const _options = <_AlignOption>[
    _AlignOption(icon: ToolbarIcons.alignLeft, label: 'Left', value: 'left'),
    _AlignOption(
      icon: ToolbarIcons.alignCenter,
      label: 'Center',
      value: 'center',
    ),
    _AlignOption(icon: ToolbarIcons.alignRight, label: 'Right', value: 'right'),
    _AlignOption(
      icon: ToolbarIcons.alignJustify,
      label: 'Justify',
      value: 'justify',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final node = widget.editorState.getNodeAtPath(widget.selection.start.path)!;
    final current = node.attributes[blockComponentAlign] as String?;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _buildCell(context, _options[i], current),
          ],
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    _AlignOption option,
    String? current,
  ) {
    final isSelected = current == option.value;
    final theme = Theme.of(context);
    return SizedBox(
      width: 76,
      child: EditorToolbarMenuButton(
        isSelected: isSelected,
        backgroundColor: Colors.transparent,
        iconPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        onTap: () => setState(() => _apply(option, isSelected)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ToolbarIcon(
              icon: option.icon,
              selected: isSelected,
              color: theme.textTheme.bodyLarge?.color,
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Tapping the active option clears alignment (drops the attribute).
  /// Tapping a different option overwrites with the new value.
  void _apply(_AlignOption option, bool isSelected) {
    widget.editorState.formatNode(
      widget.selection,
      (node) {
        final attrs = Map<String, Object?>.from(node.attributes);
        if (isSelected) {
          attrs.remove(blockComponentAlign);
        } else {
          attrs[blockComponentAlign] = option.value;
        }
        return node.copyWith(attributes: attrs);
      },
      selectionExtraInfo: {selectionExtraInfoDoNotAttachTextService: true},
    );
  }
}

class _AlignOption {
  const _AlignOption({
    required this.icon,
    required this.label,
    required this.value,
  });

  final ToolbarIcons icon;
  final String label;

  /// String written into `node.attributes[blockComponentAlign]`. Matches
  /// the values consumed by `align_mixin.dart`'s lookup.
  final String value;
}
