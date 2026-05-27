import 'package:appflowy_editor/appflowy_editor.dart';
// Use editorAppearanceTick from appflowy_editor.
import 'package:example/util/stutter_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_platform/universal_platform.dart';

class MobileEditor extends StatefulWidget {
  const MobileEditor({
    super.key,
    required this.editorState,
    this.editorStyle,
  });

  final EditorState editorState;
  final EditorStyle? editorStyle;

  @override
  State<MobileEditor> createState() => _MobileEditorState();
}

class _MobileEditorState extends State<MobileEditor> {
  EditorState get editorState => widget.editorState;

  late final EditorScrollController editorScrollController;
  late final StutterLogger _stutterLogger;

  late Map<String, BlockComponentBuilder> blockComponentBuilders;

  // Read live from editorState so the appearance sheet's mutations are
  // visible after a `setState`. EditorState's late field is assigned in
  // initState before AppFlowyEditor first builds.
  EditorStyle get editorStyle => editorState.editorStyle;

  @override
  void initState() {
    super.initState();

    editorScrollController = EditorScrollController(
      editorState: editorState,
      shrinkWrap: false,
    );

    // Dev-only diagnostic — logs per-notify BSA/BHA build deltas during
    // a selection handle drag. Tail with
    //   adb logcat | grep STUTTER
    // and trigger by long-pressing in the document.
    _stutterLogger = StutterLogger(editorState);

    editorState.editorStyle = _buildMobileEditorStyle();
    blockComponentBuilders = _buildBlockComponentBuilders();
  }

  @override
  void dispose() {
    _stutterLogger.dispose();
    editorScrollController.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();

    editorState.editorStyle = _buildMobileEditorStyle();
    blockComponentBuilders = _buildBlockComponentBuilders();
  }

  @override
  Widget build(BuildContext context) {
    return MobileToolbarV2(
      toolbarHeight: 48.0,
      toolbarItems: [
        undoMobileToolbarItem,
        redoMobileToolbarItem,
        codeMobileToolbarItem,
        quoteMobileToolbarItem,
        textDecorationMobileToolbarItemV2Sheet,
        buildTextAndBackgroundColorMobileToolbarItemSheet(),
        blocksMobileToolbarItemSheet,
        linkMobileToolbarItemSheet,
        dividerMobileToolbarItem,
        boldMobileToolbarItem,
        italicMobileToolbarItem,
        underlineMobileToolbarItem,
        buildExtrasMobileToolbarItemSheet(
          exportFileName: 'appflowy-document',
          // Same PDF font config that home_page uses for the AppBar
          // export action — keeps mobile-toolbar exports rendering
          // non-ASCII glyphs and emoji correctly.
          pdfFont: () => PdfGoogleFonts.notoSansRegular(),
          pdfFontFallback: () async => Future.wait([
            PdfGoogleFonts.notoColorEmoji(),
            PdfGoogleFonts.notoSansSymbolsRegular(),
            PdfGoogleFonts.notoSansSymbols2Regular(),
            PdfGoogleFonts.notoSansMathRegular(),
            PdfGoogleFonts.notoSansSCRegular(),
            PdfGoogleFonts.notoSansJPRegular(),
            PdfGoogleFonts.notoSansKRRegular(),
          ]),
          onExport: (callbackContext, file) async {
            final box = callbackContext.findRenderObject() as RenderBox?;
            await Share.shareXFiles(
              [file],
              subject: file.name,
              sharePositionOrigin: box == null
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size,
            );
          },
        ),
      ],
      editorState: editorState,
      child: MobileFloatingToolbar(
        editorState: editorState,
        editorScrollController: editorScrollController,
        floatingToolbarHeight: 32,
        toolbarBuilder: (context, anchor, closeToolbar) {
          return AdaptiveTextSelectionToolbar.editable(
            clipboardStatus: ClipboardStatus.pasteable,
            onCopy: () {
              copyCommand.execute(editorState);
              closeToolbar();
            },
            onCut: () => cutCommand.execute(editorState),
            onPaste: () => pasteCommand.execute(editorState),
            onSelectAll: () => selectAllCommand.execute(editorState),
            onLiveTextInput: () {},
            onLookUp: () {},
            onSearchWeb: () {},
            onShare: () {},
            anchors: TextSelectionToolbarAnchors(
              primaryAnchor: anchor,
            ),
          );
        },
        // Rebuild AppFlowyEditor whenever the appearance sheet bumps
        // [editorAppearanceTick]. Without this the cached editor widget in
        // home_page doesn't get rebuilt by setState, so heading
        // textStyleBuilder closures and body fontWeight changes wouldn't
        // reach the editor subtree.
        child: ValueListenableBuilder<int>(
          valueListenable: editorAppearanceTick,
          builder: (context, _, __) => AppFlowyEditor(
            editorStyle: editorStyle,
            editorState: editorState,
            editorScrollController: editorScrollController,
            blockComponentBuilders: blockComponentBuilders,
            showMagnifier: false,
            // showcase 3: customize the header and footer.
            header: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Image.asset(
                'assets/images/header.png',
              ),
            ),
            footer: const SizedBox(
              height: 100,
            ),
          ),
        ),
      ),
    );
  }

  // showcase 1: customize the editor style.
  EditorStyle _buildMobileEditorStyle() {
    return EditorStyle.mobile(
      textScaleFactor: 1.0,
      cursorColor: const Color.fromARGB(255, 134, 46, 247),
      dragHandleColor: const Color.fromARGB(255, 134, 46, 247),
      selectionColor: const Color.fromARGB(50, 134, 46, 247),
      textStyleConfiguration: TextStyleConfiguration(
        text: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black,
        ),
        code: GoogleFonts.sourceCodePro(
          backgroundColor: Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      magnifierSize: const Size(144, 96),
      mobileDragHandleBallSize: UniversalPlatform.isIOS
          ? const Size.square(12)
          : const Size.square(8),
      mobileDragHandleLeftExtend: 12.0,
      mobileDragHandleWidthExtend: 24.0,
    );
  }

  // showcase 2: customize the block style
  Map<String, BlockComponentBuilder> _buildBlockComponentBuilders() {
    final map = {
      ...standardBlockComponentBuilderMap,
    };
    // Heading sizes scale off the current body font size in
    // `editorState.editorStyle.textStyleConfiguration.text`, so the
    // appearance sheet's font-size slider also moves the headings.
    // Ratios derive from the pre-existing hardcoded table normalized
    // against the previous body default (14): [24, 22, 20, 18, 16, 14]
    // → [1.71, 1.57, 1.43, 1.29, 1.14, 1.0].
    const headingRatios = <double>[1.71, 1.57, 1.43, 1.29, 1.14, 1.0];
    map[HeadingBlockKeys.type] = HeadingBlockComponentBuilder(
      textStyleBuilder: (level) {
        final text = editorState.editorStyle.textStyleConfiguration.text;
        final baseSize = text.fontSize ?? 14.0;
        final family = text.fontFamily?.split('_').first ?? 'Poppins';
        final ratio = headingRatios.elementAtOrNull(level - 1) ?? 1.0;
        try {
          return GoogleFonts.getFont(
            family,
            fontSize: baseSize * ratio,
            fontWeight: FontWeight.w600,
            color: text.color,
          );
        } catch (_) {
          return TextStyle(
            fontFamily: family,
            fontSize: baseSize * ratio,
            fontWeight: FontWeight.w600,
            color: text.color,
          );
        }
      },
    );
    map[ParagraphBlockKeys.type] = ParagraphBlockComponentBuilder(
      configuration: BlockComponentConfiguration(
        placeholderText: (node) => 'Type something...',
      ),
    );
    return map;
  }
}
