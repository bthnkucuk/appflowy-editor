import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'package:example/file_io_stub.dart';
import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:example/appearance/appearance_sheet.dart';
import 'package:example/pages/animated_markdown_page.dart';
import 'package:example/pages/auto_complete_editor.dart';
import 'package:example/pages/auto_expand_editor.dart';
import 'package:example/pages/collab_editor.dart';
import 'package:example/pages/collab_editor_offline.dart';
import 'package:example/pages/collab_selection_editor.dart';
import 'package:example/pages/customize_theme_for_editor.dart';
import 'package:example/pages/drag_to_reorder_editor.dart';
import 'package:example/pages/editor.dart';
import 'package:example/pages/editor_list.dart';
import 'package:example/pages/fixed_toolbar_editor.dart';
import 'package:example/pages/focus_example_for_editor.dart';
import 'package:example/pages/markdown_editor.dart';
import 'package:example/pages/tts_reader_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_platform/universal_platform.dart';

enum ExportFileType {
  documentJson,
  markdown,
  pdf,
  delta,
}

extension on ExportFileType {
  String get extension {
    switch (this) {
      case ExportFileType.documentJson:
      case ExportFileType.delta:
        return 'json';
      case ExportFileType.markdown:
        return 'md';
      case ExportFileType.pdf:
        return 'pdf';
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late WidgetBuilder _widgetBuilder;
  late EditorState _editorState;
  late Future<String> _jsonString;
  late Editor _editor;

  /// Surfaces the live [EditorState] to the app bar so it can render
  /// an `isDirty` indicator. `null` until the editor calls
  /// `onEditorStateChange` for the first time.
  final ValueNotifier<EditorState?> _editorStateNotifier =
      ValueNotifier<EditorState?>(null);

  @override
  void dispose() {
    _editorStateNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _jsonString = UniversalPlatform.isDesktopOrWeb
        ? rootBundle.loadString('assets/example.json')
        : rootBundle.loadString('assets/mobile_example.json');

    _widgetBuilder = (context) => Editor(
          jsonString: _jsonString,
          onEditorStateChange: (editorState) {
            _editorState = editorState;
            _publishEditorState(editorState);
          },
        );
  }

  @override
  void reassemble() {
    super.reassemble();

    _editor = Editor(
      jsonString: _jsonString,
      onEditorStateChange: (editorState) {
        _editorState = editorState;
        _publishEditorState(editorState);
        _jsonString = Future.value(
          jsonEncode(_editorState.document.toJson()),
        );
      },
    );

    _widgetBuilder = (context) => _editor;
  }

  /// `onEditorStateChange` fires from inside the editor's build phase
  /// (FutureBuilder → Editor build), so writing to a ValueNotifier
  /// synchronously would call `setState` mid-build on any listening
  /// ValueListenableBuilder. Defer the write to the next frame.
  void _publishEditorState(EditorState editorState) {
    if (_editorStateNotifier.value == editorState) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_editorStateNotifier.value == editorState) return;
      _editorStateNotifier.value = editorState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: UniversalPlatform.isDesktopOrWeb,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 134, 46, 247),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('AppFlowy Editor'),
        actions: [
          ValueListenableBuilder<EditorState?>(
            valueListenable: _editorStateNotifier,
            builder: (context, editorState, _) {
              if (editorState == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Appearance',
                    icon: const Icon(Icons.text_format),
                    onPressed: () => openAppearanceSheet(
                      context: context,
                      editorState: editorState,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Table of contents',
                    icon: const Icon(Icons.format_list_bulleted),
                    onPressed: () => _openTocSheet(editorState),
                  ),
                  _DirtyIndicator(editorState: editorState),
                ],
              );
            },
          ),
          if (UniversalPlatform.isMobile)
            IconButton(
              tooltip: 'Export & share',
              icon: const Icon(Icons.ios_share),
              onPressed: _openExportSheet,
            ),
        ],
      ),
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: _widgetBuilder(context),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            child: Image.asset(
              'assets/images/icon.jpeg',
              fit: BoxFit.fill,
            ),
          ),

          // AppFlowy Editor Demo
          _buildSeparator(context, 'AppFlowy Editor Demo'),
          _buildListTile(context, 'With Example.json', () {
            final jsonString = UniversalPlatform.isDesktopOrWeb
                ? rootBundle.loadString('assets/example.json')
                : rootBundle.loadString('assets/mobile_example.json');
            _loadEditor(context, jsonString);
          }),
          _buildListTile(context, 'With Large Document (10000+ lines)', () {
            final nodes = List.generate(
              10000,
              (index) =>
                  paragraphNode(text: '$index ${generateRandomString(50)}'),
            );
            final editorState = EditorState(
              document: Document(root: pageNode(children: nodes)),
            );
            final jsonString = Future.value(
              jsonEncode(editorState.document.toJson()),
            );
            _loadEditor(context, jsonString);
          }),
          _buildListTile(context, 'With Example.html', () async {
            final htmlString =
                await rootBundle.loadString('assets/example.html');
            final html = htmlToDocument(htmlString);
            final jsonString = Future<String>.value(
              jsonEncode(
                html.toJson(),
              ).toString(),
            );
            if (context.mounted) {
              _loadEditor(context, jsonString);
            }
          }),
          _buildListTile(context, 'With Empty Document', () {
            final jsonString = Future<String>.value(
              jsonEncode(
                EditorState.blank(withInitialText: true).document.toJson(),
              ).toString(),
            );
            _loadEditor(context, jsonString);
          }),

          // Theme Demo
          _buildSeparator(context, 'Showcases'),
          _buildListTile(context, 'Drag to reorder', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DragToReorderEditor(),
              ),
            );
          }),
          _buildListTile(context, 'Markdown Editor', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MarkdownEditor(),
              ),
            );
          }),
          _buildListTile(context, 'Animated Markdown Editor', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AnimatedMarkdownPage(),
              ),
            );
          }),
          _buildListTile(context, 'Auto complete Editor', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AutoCompleteEditor(),
              ),
            );
          }),
          _buildListTile(context, 'TTS Reader (read-along)', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TtsReaderPage(),
              ),
            );
          }),
          _buildListTile(context, 'Collab Editor', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CollabEditor(),
              ),
            );
          }),
          _buildListTile(context, 'Collab Selection', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CollabSelectionEditor(),
              ),
            );
          }),
          _buildListTile(context, 'Collab Offline', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CollabEditorOffline(),
              ),
            );
          }),
          _buildListTile(context, 'Custom Theme', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomizeThemeForEditor(),
              ),
            );
          }),
          _buildListTile(context, 'RTL', () {
            final jsonString = rootBundle.loadString(
              'assets/arabic_example.json',
            );
            _loadEditor(
              context,
              jsonString,
              textDirection: TextDirection.rtl,
            );
          }),
          _buildListTile(context, 'Focus Example', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FocusExampleForEditor(),
              ),
            );
          }),
          _buildListTile(context, 'Editor List', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditorList(),
              ),
            );
          }),
          _buildListTile(context, 'Fixed Toolbar', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FixedToolbarExample(),
              ),
            );
          }),

          _buildListTile(context, 'Auto Expand Editor', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AutoExpandEditor(
                  editorState: EditorState.blank(),
                ),
              ),
            );
          }),

          // Encoder Demo
          _buildSeparator(context, 'Export To X Demo'),
          _buildListTile(context, 'Export To JSON', () {
            _exportFile(_editorState, ExportFileType.documentJson);
          }),
          _buildListTile(context, 'Export to Markdown', () {
            _exportFile(_editorState, ExportFileType.markdown);
          }),

          _buildListTile(context, 'Export to PDF', () {
            _exportFile(_editorState, ExportFileType.pdf);
          }),

          // Decoder Demo
          _buildSeparator(context, 'Import From X Demo'),
          _buildListTile(context, 'Import From Document JSON', () {
            _importFile(ExportFileType.documentJson);
          }),
          _buildListTile(context, 'Import From Markdown', () {
            _importFile(ExportFileType.markdown);
          }),
          _buildListTile(context, 'Import From Quill Delta', () {
            _importFile(ExportFileType.delta);
          }),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    String text,
    VoidCallback? onTap,
  ) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 16),
      title: Text(
        text,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
    );
  }

  Widget _buildSeparator(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _loadEditor(
    BuildContext context,
    Future<String> jsonString, {
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final completer = Completer<void>();
    _jsonString = jsonString;
    setState(
      () {
        _widgetBuilder = (context) => Editor(
              jsonString: _jsonString,
              onEditorStateChange: (editorState) {
                _editorState = editorState;
                _publishEditorState(editorState);
              },
              textDirection: textDirection,
            );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      completer.complete();
    });
    return completer.future;
  }

  Future<void> _openTocSheet(EditorState editorState) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _TocSheet(editorState: editorState),
    );
  }

  Future<void> _openExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => AppFlowyEditorExportSheet(
        editorState: _editorState,
        fileName: 'appflowy-document',
        // Primary font MUST be a real TTF (not the default Helvetica) — the
        // pdf package's built-in Helvetica claims to cover WinAnsi codepoints
        // like U+2019 (’) and renders them as the wrong glyph, never falling
        // through to pdfFontFallback. A TTF's CMap routes missing glyphs to
        // the fallback chain correctly.
        pdfFont: () => PdfGoogleFonts.notoSansRegular(),
        // Order matters — pdf consults these in order for any codepoint Noto
        // Sans Regular doesn't have. Each family covers a disjoint range, so
        // there is no overlap; placement is for fast-path locality only.
        pdfFontFallback: () async => await Future.wait([
          // Color emoji — must come BEFORE the symbol fonts. The B&W
          // notoEmojiRegular is missing many SMP emoji codepoints (e.g.
          // U+1F389, U+1F680); with it first, those fall through to
          // notoSansSymbols/Symbols2 which render them as random dingbat
          // outlines. notoColorEmoji has full coverage and the pdf package
          // renders its glyph table even if the CBDT color layer is dropped.
          PdfGoogleFonts.notoColorEmoji(),
          // Arrows, geometric shapes, misc dingbats.
          PdfGoogleFonts.notoSansSymbolsRegular(),
          PdfGoogleFonts.notoSansSymbols2Regular(),
          // Mathematical operators, blackboard, integrals, summations.
          PdfGoogleFonts.notoSansMathRegular(),

          // CJK scripts — large fonts (~10MB each), pulled from Google Fonts
          // on first export and disk-cached by the printing package thereafter.
          PdfGoogleFonts.notoSansSCRegular(),
          PdfGoogleFonts.notoSansJPRegular(),
          PdfGoogleFonts.notoSansKRRegular(),
        ]),
        onExport: (callbackContext, file) async {
          final box = callbackContext.findRenderObject() as RenderBox?;
          await Share.shareXFiles(
            [file],
            subject: file.name,
            sharePositionOrigin:
                box == null ? null : box.localToGlobal(Offset.zero) & box.size,
          );
        },
      ),
    );
  }

  void _exportFile(
    EditorState editorState,
    ExportFileType fileType,
  ) async {
    var result = '';

    switch (fileType) {
      case ExportFileType.documentJson:
        result = jsonEncode(editorState.document.toJson());
        break;
      case ExportFileType.markdown:
        result = documentToMarkdown(editorState.document);
        break;
      case ExportFileType.pdf:
        result = documentToMarkdown(editorState.document);
        break;

      case ExportFileType.delta:
        throw UnimplementedError();
    }

    if (kIsWeb) {
      final blob = html.Blob([result], 'text/plain', 'native');
      html.AnchorElement(
        href: html.Url.createObjectUrlFromBlob(blob).toString(),
      )
        ..setAttribute('download', 'document.${fileType.extension}')
        ..click();
    } else if (UniversalPlatform.isMobile) {
      final appStorageDirectory = await getApplicationDocumentsDirectory();

      final path = File(
        '${appStorageDirectory.path}/${DateTime.now()}.${fileType.extension}',
      );
      await path.writeAsString(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This document is saved to the ${appStorageDirectory.path}',
            ),
          ),
        );
      }
    } else {
      // for desktop
      final path = await FilePicker.saveFile(
        fileName: 'document.${fileType.extension}',
      );
      if (path != null) {
        await File(path).writeAsString(result);
        if (fileType == ExportFileType.pdf) {
          final pdf = await PdfHTMLEncoder(
            fontFallback: [
              await PdfGoogleFonts.notoColorEmoji(),
              await PdfGoogleFonts.notoColorEmojiRegular(),
            ],
          ).convert(result);

          await File(path).writeAsBytes(await pdf.save());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This document is saved to the $path'),
            ),
          );
        }
      }
    }
  }

  void _importFile(ExportFileType fileType) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      allowedExtensions: [fileType.extension],
      type: FileType.custom,
    );
    var plainText = '';
    if (!kIsWeb) {
      final path = result?.files.single.path;
      if (path == null) {
        return;
      }
      plainText = await File(path).readAsString();
    } else {
      final bytes = result?.files.first.bytes;
      if (bytes == null) {
        return;
      }
      plainText = const Utf8Decoder().convert(bytes);
    }

    var jsonString = '';
    switch (fileType) {
      case ExportFileType.documentJson:
        jsonString = plainText;
        break;
      case ExportFileType.markdown:
        jsonString = jsonEncode(markdownToDocument(plainText).toJson());
        break;
      case ExportFileType.delta:
        final delta = Delta.fromJson(jsonDecode(plainText));
        final document = quillDeltaEncoder.convert(delta);
        jsonString = jsonEncode(document.toJson());
        break;
      case ExportFileType.pdf:
        throw UnimplementedError();
    }

    if (mounted) {
      _loadEditor(context, Future<String>.value(jsonString));
    }
  }
}

String generateRandomString(int len) {
  var r = Random();
  return String.fromCharCodes(
    List.generate(len, (index) => r.nextInt(33) + 89),
  );
}

/// AppBar action that shows whether the document has unsaved changes
/// and lets the user mark it clean. Wired to
/// [EditorState.isDirtyNotifier], which the editor maintains via an
/// operation-incremental content hash (see
/// `_TransactionPipelineMixin._applyHashDelta`).
class _DirtyIndicator extends StatelessWidget {
  const _DirtyIndicator({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: editorState.isDirtyNotifier,
      builder: (context, isDirty, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDirty)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  '• Unsaved',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            IconButton(
              tooltip: isDirty ? 'Mark as saved' : 'Saved',
              icon: Icon(
                isDirty ? Icons.save_outlined : Icons.check_circle_outline,
              ),
              onPressed: isDirty ? editorState.markClean : null,
            ),
          ],
        );
      },
    );
  }
}

/// Bottom-sheet outline view. Subscribes to [EditorState.tableOfContents]
/// so the list refreshes if the user edits the document while the sheet
/// is open (rare but cheap). Indentation mimics Microsoft Word's
/// navigation pane — each level shifts ~16 px right.
class _TocSheet extends StatelessWidget {
  const _TocSheet({required this.editorState});

  final EditorState editorState;

  static const double _indentStep = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Table of contents',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ValueListenableBuilder<List<TocEntry>>(
                valueListenable: editorState.tableOfContents,
                builder: (context, entries, _) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No headings yet — add an H1/H2/H3 to populate '
                          'the outline.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final indent = (entry.level - 1) * _indentStep;
                      // H1 sets the visual baseline — bold + 16 px.
                      // Each level below trims 1 px and softens weight.
                      final fontSize = (16 - (entry.level - 1)).clamp(12, 16);
                      final weight = entry.level <= 2
                          ? FontWeight.w600
                          : FontWeight.w400;
                      return InkWell(
                        onTap: () async {
                          Navigator.of(context).pop();
                          await editorState.jumpToTocEntry(entry);
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            20 + indent,
                            10,
                            20,
                            10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: fontSize.toDouble(),
                                    fontWeight: weight,
                                    color: entry.isNested
                                        ? theme.hintColor
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
