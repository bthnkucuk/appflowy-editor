import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/toolbar/mobile/utils/keyboard_height_observer.dart';
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
  void initState() {
    super.initState();
    // MobileToolbarV2 sizes its menu by the cached keyboard height. With no
    // real keyboard event in tests the menu collapses to 0px and item-menu
    // taps miss. The inner _MobileToolbar (where the listener that drives
    // `cachedKeyboardHeight` lives) is built inside an OverlayEntry that
    // MobileToolbarV2 inserts in a postFrameCallback, so it only mounts on a
    // subsequent frame. A single postFrameCallback fires before the inner
    // listener is registered, so the notify is dropped. Re-notify across the
    // first several frames so the listener picks it up once it's there.
    _scheduleNotify(0);
  }

  void _scheduleNotify(int attempt) {
    if (attempt >= 5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      KeyboardHeightObserver.instance.notify(300);
      _scheduleNotify(attempt + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localToolbarItems =
        widget.toolbarItems ??
        [
          textDecorationMobileToolbarItem,
          headingMobileToolbarItem,
          todoListMobileToolbarItem,
          listMobileToolbarItem,
          linkMobileToolbarItem,
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
