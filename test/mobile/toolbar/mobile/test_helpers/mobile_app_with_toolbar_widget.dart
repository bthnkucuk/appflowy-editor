import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Used in testing mobile app with toolbar
class MobileAppWithToolbarWidget extends StatefulWidget {
  const MobileAppWithToolbarWidget({
    required this.editorState,
    this.toolbarItems,
    super.key,
  });
  final EditorState editorState;
  final List<MobileToolbarItem>? toolbarItems;

  @override
  State<MobileAppWithToolbarWidget> createState() =>
      _MobileAppWithToolbarWidgetState();
}

class _MobileAppWithToolbarWidgetState
    extends State<MobileAppWithToolbarWidget> {
  @override
  Widget build(BuildContext context) {
    final localToolbarItems =
        widget.toolbarItems ??
        [
          textDecorationMobileToolbarItemSheet,
          headingMobileToolbarItemSheet,
          todoListMobileToolbarItem,
          listMobileToolbarItemSheet,
          linkMobileToolbarItemSheet,
          quoteMobileToolbarItem,
          codeMobileToolbarItem,
        ];

    return MaterialApp(
      home: MobileToolbarV2(
        editorState: widget.editorState,
        toolbarItems: localToolbarItems,
        child: AppFlowyEditor(
          editorStyle: const EditorStyle.mobile(),
          editorState: widget.editorState,
        ),
      ),
    );
  }
}
