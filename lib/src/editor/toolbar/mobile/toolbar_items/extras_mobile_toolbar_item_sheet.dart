import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Callback shape passed to `buildExtrasMobileToolbarItemSheet` to wire
/// up the export cell. Mirrors [AppFlowyEditorExportCallback] — the
/// sheet hands back an [XFile] for the consumer to forward to
/// share_plus / file_picker / etc.
typedef ExtrasOnExportCallback =
    Future<void> Function(BuildContext context, XFile file);

/// Builds the "extras" sheet toolbar item — a horizontal-scroll picker
/// for misc editor utilities that don't deserve their own dedicated
/// toolbar slot. Cells included so far:
///
///  * Statistics — words / characters / sentences / paragraphs / reading time
///  * Export (only if [onExport] is provided) — opens
///    [AppFlowyEditorExportSheet] with the supplied PDF font config and
///    forwards the produced [XFile] to [onExport].
MobileToolbarItem buildExtrasMobileToolbarItemSheet({
  ExtrasOnExportCallback? onExport,
  String exportFileName = 'document',
  Future<pw.Font> Function()? pdfFont,
  Future<List<pw.Font>> Function()? pdfFontFallback,
  List<AppFlowyExportFormat> exportFormats = AppFlowyExportFormat.values,
}) {
  return MobileToolbarItem(
    itemIconBuilder: (context, _) => ToolbarIcon(
      icon: ToolbarIcons.more,
      color: MobileToolbarTheme.of(context).iconColor,
    ),
    actionHandler: (context, editorState) {
      final selection = editorState.selection;
      if (selection == null) return;

      editorState.keyboardService?.closeKeyboard();
      editorState.updateSelectionWithReason(
        selection,
        extraInfo: {
          selectionExtraInfoDisableMobileToolbarKey: true,
          selectionExtraInfoDisableFloatingToolbar: true,
          selectionExtraInfoDoNotAttachTextService: true,
        },
      );
      editorState.keepFocusNotifier.increase();

      Navigator.of(context)
          .push(
            StupidSimpleSheetRoute<void>(
              barrierColor: Colors.transparent,
              originateAboveBottomViewInset: true,
              child: MobileToolbarTheme(
                child: EditorToolbarSheetScaffold(
                  child: _ExtrasMenu(
                    editorState: editorState,
                    onExport: onExport,
                    exportFileName: exportFileName,
                    pdfFont: pdfFont,
                    pdfFontFallback: pdfFontFallback,
                    exportFormats: exportFormats,
                  ),
                ),
              ),
            ),
          )
          .then((_) {
            editorState.keepFocusNotifier.decrease();
            editorState.updateSelectionWithReason(
              selection,
              extraInfo: {selectionExtraInfoDisableFloatingToolbar: true},
            );
            editorState.keyboardService?.enableKeyBoard(selection);
          });
    },
  );
}

/// Back-compat alias: original `extrasMobileToolbarItemSheet` only
/// shipped the Statistics cell. Existing callers keep working.
final extrasMobileToolbarItemSheet = buildExtrasMobileToolbarItemSheet();

class _ExtrasMenu extends StatelessWidget {
  const _ExtrasMenu({
    required this.editorState,
    required this.onExport,
    required this.exportFileName,
    required this.pdfFont,
    required this.pdfFontFallback,
    required this.exportFormats,
  });

  final EditorState editorState;
  final ExtrasOnExportCallback? onExport;
  final String exportFileName;
  final Future<pw.Font> Function()? pdfFont;
  final Future<List<pw.Font>> Function()? pdfFontFallback;
  final List<AppFlowyExportFormat> exportFormats;

  @override
  Widget build(BuildContext context) {
    final cells = <_ExtrasCell>[
      _ExtrasCell(
        icon: ToolbarIcons.stats,
        label: 'Statistics',
        onTap: () => _openStats(context),
      ),
      if (onExport != null)
        _ExtrasCell(
          icon: ToolbarIcons.export,
          label: 'Export',
          onTap: () => _openExport(context),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _buildCell(context, cells[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildCell(BuildContext context, _ExtrasCell cell) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 76,
      child: EditorToolbarMenuButton(
        isSelected: false,
        backgroundColor: Colors.transparent,
        iconPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        onTap: cell.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ToolbarIcon(
              icon: cell.icon,
              color: theme.textTheme.bodyLarge?.color,
            ),
            const SizedBox(height: 6),
            Text(
              cell.label,
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

  void _openStats(BuildContext context) {
    Navigator.of(context).push(
      StupidSimpleSheetRoute<void>(
        barrierColor: Colors.transparent,
        originateAboveBottomViewInset: true,
        child: MobileToolbarTheme(
          child: EditorToolbarSheetScaffold(child: _StatsSheet(editorState)),
        ),
      ),
    );
  }

  void _openExport(BuildContext context) {
    final cb = onExport;
    if (cb == null) return;
    Navigator.of(context).push(
      StupidSimpleSheetRoute<void>(
        barrierColor: Colors.transparent,
        originateAboveBottomViewInset: true,
        child: MobileToolbarTheme(
          child: EditorToolbarSheetScaffold(
            child: AppFlowyEditorExportSheet(
              editorState: editorState,
              fileName: exportFileName,
              formats: exportFormats,
              pdfFont: pdfFont,
              pdfFontFallback: pdfFontFallback,
              onExport: cb,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtrasCell {
  const _ExtrasCell({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ToolbarIcons icon;
  final String label;
  final VoidCallback onTap;
}

class _StatsSheet extends StatelessWidget {
  const _StatsSheet(this.editorState);

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    final service = WordCountService(editorState: editorState);
    final wcDoc = service.getDocumentCounters();
    final wcSel = service.getSelectionCounters();
    final selection = editorState.selection;
    final hasSelectionStats = selection != null && !selection.isCollapsed;

    final doc = _DocStats.fromEditorState(editorState);
    final sel = hasSelectionStats
        ? _DocStats.fromSelection(editorState, selection)
        : null;

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Document', style: theme.textTheme.titleMedium),
          const Divider(height: 16, thickness: 0.5),
          _StatsRow.number(label: 'Words', value: wcDoc.wordCount),
          const SizedBox(height: 8),
          _StatsRow.number(label: 'Characters', value: wcDoc.charCount),
          const SizedBox(height: 8),
          _StatsRow.number(
            label: 'Characters (no spaces)',
            value: doc.charsNoSpaces,
          ),
          const SizedBox(height: 8),
          _StatsRow.number(label: 'Sentences', value: doc.sentences),
          const SizedBox(height: 8),
          _StatsRow.number(label: 'Paragraphs', value: doc.paragraphs),
          const SizedBox(height: 8),
          _StatsRow.text(
            label: 'Reading time',
            value: _formatReadingTime(wcDoc.wordCount),
          ),
          if (sel != null) ...[
            const SizedBox(height: 16),
            Text('Selection', style: theme.textTheme.titleSmall),
            const Divider(height: 12, thickness: 0.5),
            _StatsRow.number(label: 'Words', value: wcSel.wordCount),
            const SizedBox(height: 8),
            _StatsRow.number(label: 'Characters', value: wcSel.charCount),
            const SizedBox(height: 8),
            _StatsRow.number(
              label: 'Characters (no spaces)',
              value: sel.charsNoSpaces,
            ),
            const SizedBox(height: 8),
            _StatsRow.number(label: 'Sentences', value: sel.sentences),
          ],
        ],
      ),
    );
  }
}

class _DocStats {
  const _DocStats({
    required this.charsNoSpaces,
    required this.sentences,
    required this.paragraphs,
  });

  final int charsNoSpaces;
  final int sentences;
  final int paragraphs;

  factory _DocStats.fromEditorState(EditorState editorState) {
    final buf = StringBuffer();
    var paragraphs = 0;
    for (final node in editorState.document.root.children) {
      _accumulate(node, buf);
      paragraphs += _countParagraphs(node);
    }
    return _DocStats._fromText(buf.toString(), paragraphs);
  }

  factory _DocStats.fromSelection(
    EditorState editorState,
    Selection selection,
  ) {
    final nodes = editorState.getNodesInSelection(selection);
    final buf = StringBuffer();
    var paragraphs = 0;
    for (final node in nodes) {
      final text = node.delta?.toPlainText() ?? '';
      buf
        ..write(text)
        ..write(' ');
      if (node.delta != null) paragraphs++;
    }
    return _DocStats._fromText(buf.toString(), paragraphs);
  }

  factory _DocStats._fromText(String text, int paragraphs) {
    final matches = RegExp('[.!?]+').allMatches(text).length;
    final sentences = matches > 0 ? matches : (text.trim().isEmpty ? 0 : 1);
    final charsNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    return _DocStats(
      charsNoSpaces: charsNoSpaces,
      sentences: sentences,
      paragraphs: paragraphs,
    );
  }

  static void _accumulate(Node node, StringBuffer buf) {
    final text = node.delta?.toPlainText();
    if (text != null && text.isNotEmpty) {
      buf
        ..write(text)
        ..write('\n');
    }
    for (final child in node.children) {
      _accumulate(child, buf);
    }
  }

  static int _countParagraphs(Node node) {
    var count = node.delta != null ? 1 : 0;
    for (final child in node.children) {
      count += _countParagraphs(child);
    }
    return count;
  }
}

String _formatReadingTime(int wordCount) {
  if (wordCount == 0) return '0 min';
  final minutes = (wordCount / 200).ceil();
  return '$minutes min';
}

class _StatsRow extends StatelessWidget {
  const _StatsRow.number({required this.label, required int value})
    : displayValue = '$value';

  const _StatsRow.text({required this.label, required String value})
    : displayValue = value;

  final String label;
  final String displayValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          displayValue,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
