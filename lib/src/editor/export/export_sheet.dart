import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

/// Callback invoked once an export has been produced.
///
/// The sheet hands back an [XFile] whose [XFile.path] points at a freshly
/// written file inside the OS temp directory (on web, where there is no
/// filesystem, an in-memory [XFile.fromData] is used as fallback). [XFile]
/// is the same cross-platform file abstraction used by `share_plus`,
/// `file_picker`, and `image_picker`, so it can be forwarded directly to
/// those APIs. The sheet pops itself after the callback resolves.
///
/// Ownership of the temp file belongs to the caller — move/copy it with
/// `file_picker`'s save dialog or `share_plus`, or delete it once you're
/// done. Large PDF exports otherwise sit in temp until the OS reclaims it.
typedef EditorExportCallback = Future<void> Function(BuildContext context, XFile file);

/// A drop-in export panel that runs against an [EditorState]. Each row
/// just forwards to the matching [EditorExport] extension method
/// (`exportAsJson` / `exportAsMarkdown` / `exportAsPdf`), then hands the
/// produced [XFile] to [onExport]. The sheet itself owns no encoding
/// logic — that lives on `EditorState` so consumers can reuse it from
/// a button, an AppBar action, or a CLI tool without mounting the
/// sheet UI.
///
/// Layout matches the mobile toolbar sheet system (cf.
/// `EditorToolbarSheetScaffold`, `EditorToolbarMenuButton`).
class AppFlowyEditorExportSheet extends StatefulWidget {
  const AppFlowyEditorExportSheet({
    super.key,
    required this.editorState,
    required this.onExport,
    this.fileName = 'document',
    this.formats = EditorExportFormat.values,
    this.pdfFont,
    this.pdfFontFallback,
  });

  final EditorState editorState;
  final EditorExportCallback onExport;

  /// Base name (no extension) used for the temp file. The sheet appends the
  /// correct extension per format.
  final String fileName;

  /// Which formats to offer, in display order. Defaults to all formats.
  final List<EditorExportFormat> formats;

  /// Primary font forwarded to [EditorExport.exportAsPdf]. See that
  /// method's doc comment for why supplying a real TTF matters when
  /// the document has non-ASCII codepoints.
  final Future<pw.Font> Function()? pdfFont;

  /// Fonts consulted when [pdfFont] doesn't cover a codepoint (e.g.
  /// emoji, CJK). Only forwarded for [EditorExportFormat.pdf].
  final Future<List<pw.Font>> Function()? pdfFontFallback;

  @override
  State<AppFlowyEditorExportSheet> createState() => _AppFlowyEditorExportSheetState();
}

class _AppFlowyEditorExportSheetState extends State<AppFlowyEditorExportSheet> {
  EditorExportFormat? _exporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Export', style: theme.textTheme.titleMedium),
          const Divider(height: 16, thickness: 0.5),
          for (var i = 0; i < widget.formats.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildRow(widget.formats[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(EditorExportFormat format) {
    final busy = _exporting == format;
    final disabled = _exporting != null && !busy;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: EditorToolbarMenuButton(
        isSelected: false,
        onTap: busy || disabled ? () {} : () => _run(format),
        enabled: !busy && !disabled,
        iconPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            ToolbarIcon(icon: _iconFor(format), color: Theme.of(context).textTheme.bodyLarge?.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_labelFor(format), style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    '.${format.fileExtension}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
          ],
        ),
      ),
    );
  }

  ToolbarIcons _iconFor(EditorExportFormat format) {
    switch (format) {
      case EditorExportFormat.json:
        return ToolbarIcons.code;
      case EditorExportFormat.markdown:
        return ToolbarIcons.text;
      case EditorExportFormat.pdf:
        return ToolbarIcons.export;
    }
  }

  String _labelFor(EditorExportFormat format) {
    switch (format) {
      case EditorExportFormat.json:
        return 'Export as JSON';
      case EditorExportFormat.markdown:
        return 'Export as Markdown';
      case EditorExportFormat.pdf:
        return 'Export as PDF';
    }
  }

  Future<void> _run(EditorExportFormat format) async {
    setState(() => _exporting = format);
    try {
      final file = await widget.editorState.exportAs(
        format,
        fileName: widget.fileName,
        pdfFont: widget.pdfFont,
        pdfFontFallback: widget.pdfFontFallback,
      );
      if (!mounted) return;
      await widget.onExport(context, file);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }
}
