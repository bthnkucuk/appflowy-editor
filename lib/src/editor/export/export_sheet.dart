import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

///TODO(bthnkucuk): This is a temporary solution to export the document... UI needs to be improved.
/// Supported export targets for [AppFlowyEditorExportSheet].
enum AppFlowyExportFormat {
  json('json', 'application/json'),
  markdown('md', 'text/markdown'),
  pdf('pdf', 'application/pdf');

  const AppFlowyExportFormat(this.fileExtension, this.mimeType);
  final String fileExtension;
  final String mimeType;
}

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
typedef AppFlowyEditorExportCallback =
    Future<void> Function(BuildContext context, XFile file);

/// A drop-in export panel that runs against an [EditorState] — parallel to
/// [AppFlowyEditor]. Shows one row per requested [AppFlowyExportFormat]; on
/// tap, encodes the document with the package's built-in encoders
/// ([documentToMarkdown], [PdfHTMLEncoder]), writes the result to a temp
/// file, and hands the path to [onExport]. Writing to disk (rather than
/// passing bytes around) keeps large PDF exports from being pinned in heap
/// after the callback returns.
///
/// Open it with `showModalBottomSheet` (or any other host route):
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (_) => AppFlowyEditorExportSheet(
///     editorState: editorState,
///     fileName: 'my-doc',
///     onExport: (context, file) async {
///       // hand `file` to share_plus / file_picker / etc.
///     },
///   ),
/// );
/// ```
class AppFlowyEditorExportSheet extends StatefulWidget {
  const AppFlowyEditorExportSheet({
    super.key,
    required this.editorState,
    required this.onExport,
    this.fileName = 'document',
    this.formats = AppFlowyExportFormat.values,
    this.pdfFont,
    this.pdfFontFallback,
  });

  final EditorState editorState;
  final AppFlowyEditorExportCallback onExport;

  /// Base name (no extension) used for the temp file. The sheet appends the
  /// correct extension per format.
  final String fileName;

  /// Which formats to offer, in display order. Defaults to all formats.
  final List<AppFlowyExportFormat> formats;

  /// Primary font forwarded to [PdfHTMLEncoder]. Strongly recommended for
  /// non-ASCII documents: when this is null the pdf package falls back to
  /// built-in Helvetica, which *claims* to cover WinAnsi codepoints like
  /// U+2019 (curly apostrophe) but renders them as wrong glyphs — and since
  /// Helvetica reports the glyph as "present", [pdfFontFallback] is never
  /// consulted for them. Supply e.g. `PdfGoogleFonts.notoSansRegular()` to
  /// route every glyph through a real TTF.
  final Future<pw.Font> Function()? pdfFont;

  /// Fonts consulted when [pdfFont] doesn't cover a codepoint (e.g. emoji,
  /// CJK). Order matters — earlier entries are tried first. Only consulted
  /// for [AppFlowyExportFormat.pdf].
  final Future<List<pw.Font>> Function()? pdfFontFallback;

  @override
  State<AppFlowyEditorExportSheet> createState() =>
      _AppFlowyEditorExportSheetState();
}

class _AppFlowyEditorExportSheetState extends State<AppFlowyEditorExportSheet> {
  AppFlowyExportFormat? _exporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Export', style: theme.textTheme.titleMedium),
            ),
            for (final format in widget.formats) _buildTile(format),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(AppFlowyExportFormat format) {
    final busy = _exporting == format;
    final disabled = _exporting != null && !busy;
    return ListTile(
      enabled: !disabled,
      title: Text(_labelFor(format)),
      subtitle: Text('.${format.fileExtension}'),
      trailing: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined),
      onTap: busy ? null : () => _run(format),
    );
  }

  String _labelFor(AppFlowyExportFormat format) {
    switch (format) {
      case AppFlowyExportFormat.json:
        return 'Export as JSON';
      case AppFlowyExportFormat.markdown:
        return 'Export as Markdown';
      case AppFlowyExportFormat.pdf:
        return 'Export as PDF';
    }
  }

  Future<void> _run(AppFlowyExportFormat format) async {
    setState(() => _exporting = format);
    try {
      final file = await _encode(format);
      if (!mounted) return;
      await widget.onExport(context, file);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  Future<XFile> _encode(AppFlowyExportFormat format) async {
    final document = widget.editorState.document;
    final name = '${widget.fileName}.${format.fileExtension}';
    switch (format) {
      case AppFlowyExportFormat.json:
        return _writeString(
          jsonEncode(document.toJson()),
          name: name,
          mimeType: format.mimeType,
        );
      case AppFlowyExportFormat.markdown:
        return _writeString(
          documentToMarkdown(document),
          name: name,
          mimeType: format.mimeType,
        );
      case AppFlowyExportFormat.pdf:
        final markdown = documentToMarkdown(document);
        final font = await widget.pdfFont?.call();
        final fontFallback =
            await widget.pdfFontFallback?.call() ?? const <pw.Font>[];
        final pdf = await PdfHTMLEncoder(
          font: font,
          fontFallback: fontFallback,
        ).convert(markdown);
        // Stage on disk and drop the byte buffer immediately so the
        // returned XFile only retains a path, not the whole document.
        return _writeBytes(
          await pdf.save(),
          name: name,
          mimeType: format.mimeType,
        );
    }
  }

  Future<XFile> _writeString(
    String contents, {
    required String name,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      final bytes = Uint8List.fromList(utf8.encode(contents));
      return XFile.fromData(
        bytes,
        name: name,
        mimeType: mimeType,
        length: bytes.length,
      );
    }
    final file = await _newCacheFile(name);
    await file.writeAsString(contents, flush: true);
    return XFile(
      file.path,
      name: name,
      mimeType: mimeType,
      length: await file.length(),
    );
  }

  Future<XFile> _writeBytes(
    Uint8List bytes, {
    required String name,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      return XFile.fromData(
        bytes,
        name: name,
        mimeType: mimeType,
        length: bytes.length,
      );
    }
    final file = await _newCacheFile(name);
    await file.writeAsBytes(bytes, flush: true);
    return XFile(
      file.path,
      name: name,
      mimeType: mimeType,
      length: await file.length(),
    );
  }

  Future<File> _newCacheFile(String name) async {
    final dir = await Directory.systemTemp.createTemp('appflowy_export_');
    return File('${dir.path}${Platform.pathSeparator}$name');
  }
}
