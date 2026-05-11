import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late EditorStyle editorStyle;
  late Map<String, BlockComponentBuilder> blockComponentBuilders;

  @override
  void initState() {
    super.initState();

    editorScrollController = EditorScrollController(
      editorState: editorState,
      shrinkWrap: false,
    );

    editorState.highlightNotifier.addListener(() {
      // final highlight = editorState.highlightNotifier.value;

      return;

      // final visibleRange = editorScrollController.visibleRangeNotifier.value;

      // if (highlight != null) {
      //   final node = editorState.getNodesInSelection(highlight).lastOrNull;

      //   final index =
      //       node != null ? editorState.document.nodes.indexOf(node) : null;
      //   if (index != null) {
      //     if (index < visibleRange.$1 || index > visibleRange.$2) {
      //       editorScrollController.itemScrollController.scrollTo(
      //         index: index + 1,
      //         duration: const Duration(milliseconds: 250),
      //         curve: Curves.easeInOut,
      //       );
      //     }
      //   }
      // }
    });

    // () async {
    //   for (final node in editorState.document.nodes) {
    //     final textInserts = node.delta?.whereType<TextInsert>();
    //     final String? text = textInserts?.map((t) => t.text).join();
    //     await Future.delayed(const Duration(milliseconds: 1));

    //   }
    // }();

    editorState.highlightNotifier.addListener(() {
      final highlight = editorState.highlightNotifier.value;
      final visibleRange = editorScrollController.visibleRangeNotifier.value;

      if (highlight != null) {
        final node = editorState.getNodesInSelection(highlight).lastOrNull;

        final index =
            node != null ? editorState.document.nodes.indexOf(node) : null;
        if (index != null) {
          if (index < visibleRange.$1 || index > visibleRange.$2) {
            editorScrollController.itemScrollController.scrollTo(
              index: index + 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        }
      }
    });

    // () async {
    //   for (final node in editorState.document.nodes) {
    //     final textInserts = node.delta?.whereType<TextInsert>();
    //     final String? text = textInserts?.map((t) => t.text).join();
    //     await Future.delayed(const Duration(milliseconds: 1));
    //   }
    // }();

    editorStyle = _buildMobileEditorStyle();
    blockComponentBuilders = _buildBlockComponentBuilders();
  }

  @override
  void reassemble() {
    super.reassemble();

    editorStyle = _buildMobileEditorStyle();
    blockComponentBuilders = _buildBlockComponentBuilders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // for (final node in editorState.document.nodes) {
          //   final textInserts = node.delta?.whereType<TextInsert>();
          //   final String? text = textInserts?.map((t) => t.text).join();

          //   editorState.updateHighlight(
          //     Selection(
          //       start: Position(offset: 0, path: node.path),
          //       end: Position(offset: 500, path: node.path),
          //     ),
          //   );

          //   await Future.delayed(const Duration(seconds: 1));
          // }

          // return;

          // int index = 0;
          // Timer.periodic(Duration(seconds: 1), (_) {
          //   editorState.updateHighlight(
          //     Selection(
          //       start: Position(offset: 0, path: [index]),
          //       end: Position(offset: 500, path: [index]),
          //     ),
          //   );
          //   index++;
          // });
          // return;
          // print(editorState.document.last?.toJson());

          editorState.document.insertNodesToEndOfDocument(
            List.generate(
              10,
              (index) => Node.fromJson(
                {
                  "type": "paragraph",
                  "data": {
                    "level": 1,
                    "delta": [
                      {
                        "insert": "AppFlowy Editor $index",
                        "attributes": {
                          "bold": true,
                          "italic": false,
                          "underline": false,
                        },
                      },
                      {
                        "insert":
                            " empowers your flutter app with seamless document editing features.",
                        "attributes": {
                          "bold": false,
                          "italic": false,
                          "underline": false,
                        },
                      }
                    ],
                  },
                },
              ),
            ),
          );
          editorState.updateHighlight(
            Selection(
              start: Position(offset: 0, path: [3]),
              end: Position(offset: 10, path: [3]),
            ),
          );
          // editorState.document.insertNodesToEndOfDocument(
          //   List.generate(
          //     10,
          //     (index) => Node.fromJson(
          //       {
          //         "type": "paragraph",
          //         "data": {
          //           "level": 1,
          //           "delta": [
          //             {
          //               "insert": "AppFlowy Editor $index",
          //               "attributes": {
          //                 "bold": true,
          //                 "italic": false,
          //                 "underline": false
          //               },
          //             },
          //             {
          //               "insert":
          //                   " empowers your flutter app with seamless document editing features.",
          //               "attributes": {
          //                 "bold": false,
          //                 "italic": false,
          //                 "underline": false
          //               },
          //             }
          //           ],
          //         },
          //       },
          //     ),
          //   ),
          // );
          // editorState.updateHighlight(
          //   Selection(
          //     start: Position(offset: 0, path: [3]),
          //     end: Position(offset: 10, path: [3]),
          //   ),
          // );
        },
      ),
      body: MobileToolbarV2(
        toolbarHeight: 48.0,
        toolbarItems: [
          textDecorationMobileToolbarItemV2,
          buildTextAndBackgroundColorMobileToolbarItem(),
          blocksMobileToolbarItem,
          linkMobileToolbarItem,
          dividerMobileToolbarItem,
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
              onLiveTextInput: null,
              onLookUp: null,
              onSearchWeb: null,
              onShare: null,
              anchors: TextSelectionToolbarAnchors(
                primaryAnchor: anchor,
              ),
            );
          },
          child: AppFlowyEditor(
            autoFocus: true,
            editable: true,

            // disableSelectionService: true,
            // disableKeyboardService: true,
            // disableScrollService: false,
            // showMagnifier: false,

            editorStyle: editorStyle,
            editorState: editorState,
            editorScrollController: editorScrollController,
            blockComponentBuilders: blockComponentBuilders,
            // showcase 3: customize the header and footer.

            autoScrollEdgeOffset: 8,
            header: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Image.asset('assets/images/header.png'),
            ),
            footer: const SizedBox(height: 100),
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
      highlightColor: Colors.amber,
      defaultNodeBackgroundColor: CupertinoColors.systemGrey6,
      seperatorPadding: const EdgeInsets.all(0),
      inBlockPadding: const EdgeInsets.all(0),
      padding: const EdgeInsets.symmetric(horizontal: 0),
      // selectionColor: const Color.fromARGB(50, 134, 46, 247),
      textStyleConfiguration: TextStyleConfiguration(
        text: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black,
        ),
        code: GoogleFonts.sourceCodePro(
          backgroundColor: Colors.grey.shade200,
        ),
      ),
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
    // customize the heading block component
    final levelToFontSize = [
      24.0,
      22.0,
      20.0,
      18.0,
      16.0,
      14.0,
    ];
    map[HeadingBlockKeys.type] = HeadingBlockComponentBuilder(
      textStyleBuilder: (level) => GoogleFonts.poppins(
        fontSize: levelToFontSize.elementAtOrNull(level - 1) ?? 14.0,
        fontWeight: FontWeight.w600,
      ),
    );
    map[ParagraphBlockKeys.type] = ParagraphBlockComponentBuilder(
      configuration: BlockComponentConfiguration(
        placeholderText: (node) => 'Type something...',
      ),
    );
    return map;
  }
}
