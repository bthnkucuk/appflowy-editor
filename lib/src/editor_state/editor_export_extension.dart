import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;

import '../editor_state.dart';
import '../plugins/markdown/document_markdown.dart';
import '../plugins/pdf/html_to_pdf_encoder.dart';

/// Supported export targets for [AppFlowyEditorExportSheet].
enum EditorExportFormat {
  json('json', 'application/json'),
  markdown('md', 'text/markdown'),
  pdf('pdf', 'application/pdf');

  const EditorExportFormat(this.fileExtension, this.mimeType);
  final String fileExtension;
  final String mimeType;
}

/// Export helpers for [EditorState] — encode the current document to
/// JSON / Markdown / PDF and stage the result in the OS temp directory.
/// Pulled out of `AppFlowyEditorExportSheet` so the same encoders are
/// usable without the sheet UI (e.g. a "save now" button, a CLI tool,
/// or an AppBar action handler).
///
/// Every method returns an [XFile] — the cross-platform file
/// abstraction shared by `share_plus`, `file_picker`, and
/// `image_picker`. On web (`kIsWeb`) the file is an in-memory
/// [XFile.fromData] (no temp filesystem); elsewhere it's a real file
/// inside `Directory.systemTemp` that the caller now owns. Move /
/// copy / delete it as appropriate; large PDF exports otherwise sit in
/// temp until the OS reclaims it.
extension EditorExport on EditorState {
  /// Encodes the current document in [format] and writes the result to
  /// a temp file (or memory on web). [fileName] is the base name; the
  /// extension is appended automatically from
  /// [EditorExportFormat.fileExtension].
  ///
  /// [pdfFont] and [pdfFontFallback] are only consulted for
  /// [EditorExportFormat.pdf]; supplying them is strongly recommended
  /// for non-ASCII documents — see the docs on
  /// [exportAsPdf] for the underlying constraint.
  Future<XFile> exportAs(
    EditorExportFormat format, {
    String fileName = 'document',
    Future<pw.Font> Function()? pdfFont,
    Future<List<pw.Font>> Function()? pdfFontFallback,
  }) {
    switch (format) {
      case EditorExportFormat.json:
        return exportAsJson(fileName: fileName);
      case EditorExportFormat.markdown:
        return exportAsMarkdown(fileName: fileName);
      case EditorExportFormat.pdf:
        return exportAsPdf(fileName: fileName, pdfFont: pdfFont, pdfFontFallback: pdfFontFallback);
    }
  }

  Future<XFile> exportAsJson({String fileName = 'document'}) {
    return _writeString(
      jsonEncode(document.toJson()),
      name: '$fileName.${EditorExportFormat.json.fileExtension}',
      mimeType: EditorExportFormat.json.mimeType,
    );
  }

  Future<XFile> exportAsMarkdown({String fileName = 'document'}) {
    return _writeString(
      documentToMarkdown(document),
      name: '$fileName.${EditorExportFormat.markdown.fileExtension}',
      mimeType: EditorExportFormat.markdown.mimeType,
    );
  }

  /// Encodes the document as PDF. Both font args are async because
  /// `PdfGoogleFonts.*` downloads on first use and disk-caches.
  ///
  /// Supplying [pdfFont] is strongly recommended for non-ASCII
  /// documents: when it's null the pdf package falls back to built-in
  /// Helvetica, which *claims* to cover WinAnsi codepoints like U+2019
  /// (curly apostrophe) but renders them as the wrong glyph — and
  /// since Helvetica reports the glyph as "present", [pdfFontFallback]
  /// is never consulted for them. A real TTF (e.g.
  /// `PdfGoogleFonts.notoSansRegular()`) routes missing glyphs to the
  /// fallback chain correctly.
  Future<XFile> exportAsPdf({
    String fileName = 'document',
    Future<pw.Font> Function()? pdfFont,
    Future<List<pw.Font>> Function()? pdfFontFallback,
  }) async {
    final markdown = documentToMarkdown(document);
    final font = await pdfFont?.call();
    final fontFallback = await pdfFontFallback?.call() ?? const <pw.Font>[];
    final pdf = await PdfHTMLEncoder(font: font, fontFallback: fontFallback).convert(markdown);
    // Stage on disk and drop the byte buffer immediately so the
    // returned XFile only retains a path, not the whole document.
    return _writeBytes(
      await pdf.save(),
      name: '$fileName.${EditorExportFormat.pdf.fileExtension}',
      mimeType: EditorExportFormat.pdf.mimeType,
    );
  }

  Future<XFile> _writeString(String contents, {required String name, required String mimeType}) async {
    if (kIsWeb) {
      final bytes = Uint8List.fromList(utf8.encode(contents));
      return XFile.fromData(bytes, name: name, mimeType: mimeType, length: bytes.length);
    }
    final file = await _newCacheFile(name);
    await file.writeAsString(contents, flush: true);
    return XFile(file.path, name: name, mimeType: mimeType, length: await file.length());
  }

  Future<XFile> _writeBytes(Uint8List bytes, {required String name, required String mimeType}) async {
    if (kIsWeb) {
      return XFile.fromData(bytes, name: name, mimeType: mimeType, length: bytes.length);
    }
    final file = await _newCacheFile(name);
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, name: name, mimeType: mimeType, length: await file.length());
  }

  Future<File> _newCacheFile(String name) async {
    final dir = await Directory.systemTemp.createTemp('appflowy_export_');
    return File('${dir.path}${Platform.pathSeparator}$name');
  }
}
