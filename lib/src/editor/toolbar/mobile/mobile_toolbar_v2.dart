import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

const String selectionExtraInfoDisableMobileToolbarKey = 'disableMobileToolbar';

class MobileToolbarV2 extends StatefulWidget {
  const MobileToolbarV2({
    super.key,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xff676666),
    this.iconColor = Colors.black,
    this.clearDiagonalLineColor = const Color(0xffB3261E),
    this.itemHighlightColor = const Color(0xff1F71AC),
    this.itemOutlineColor = const Color(0xFFE3E3E3),
    this.tabBarSelectedBackgroundColor = const Color(0x23808080),
    this.tabBarSelectedForegroundColor = Colors.black,
    this.primaryColor = const Color(0xff1F71AC),
    this.onPrimaryColor = Colors.white,
    this.outlineColor = const Color(0xFFE3E3E3),
    this.toolbarHeight = 50.0,
    this.borderRadius = 6.0,
    this.buttonHeight = 40.0,
    this.buttonSpacing = 8.0,
    this.buttonBorderWidth = 1.0,
    this.buttonSelectedBorderWidth = 2.0,
    required this.editorState,
    required this.toolbarItems,
    required this.child,
  });

  final EditorState editorState;
  final List<MobileToolbarItem> toolbarItems;
  final Widget child;

  // style
  final Color backgroundColor;
  final Color foregroundColor;
  final Color iconColor;
  final Color clearDiagonalLineColor;
  final Color itemHighlightColor;
  final Color itemOutlineColor;
  final Color tabBarSelectedBackgroundColor;
  final Color tabBarSelectedForegroundColor;
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color outlineColor;
  final double toolbarHeight;
  final double borderRadius;
  final double buttonHeight;
  final double buttonSpacing;
  final double buttonBorderWidth;
  final double buttonSelectedBorderWidth;

  @override
  State<MobileToolbarV2> createState() => _MobileToolbarV2State();
}

class _MobileToolbarV2State extends State<MobileToolbarV2> {
  /// Ticks once per transaction so `itemIconBuilder` re-evaluates the
  /// "is this attribute currently active" check after a toggle.
  ///
  /// `selectionNotifier` alone is insufficient: when the user toggles
  /// e.g. bold on a non-collapsed selection, the document mutates but
  /// the selection range is identical — and `EditorState.selection`
  /// short-circuits the notifier on identical writes (see
  /// `selection_style_mixin.dart` line 70, the H2.1 PropertyValueNotifier
  /// cascade fix). Without this tick the toolbar icon stays in its
  /// pre-toggle filled/outlined state until the user moves the caret.
  final ValueNotifier<int> _docTick = ValueNotifier<int>(0);
  StreamSubscription<EditorTransactionValue>? _txnSub;

  @override
  void initState() {
    super.initState();
    _txnSub = widget.editorState.transactionStream.listen((_) {
      _docTick.value++;
    });
  }

  @override
  void didUpdateWidget(covariant MobileToolbarV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      _txnSub?.cancel();
      _txnSub = widget.editorState.transactionStream.listen((_) {
        _docTick.value++;
      });
    }
  }

  @override
  void dispose() {
    _txnSub?.cancel();
    _docTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        ListenableBuilder(
          listenable: Listenable.merge([
            widget.editorState.selectionNotifier,
            _docTick,
          ]),
          builder: (_, _) {
            final selection = widget.editorState.selection;
            final disabled =
                widget
                    .editorState
                    .selectionExtraInfo?[selectionExtraInfoDisableMobileToolbarKey] ==
                true;
            if (selection == null || disabled) {
              return const SizedBox.shrink();
            }
            return RepaintBoundary(
              child: MobileToolbarTheme(
                backgroundColor: widget.backgroundColor,
                foregroundColor: widget.foregroundColor,
                iconColor: widget.iconColor,
                clearDiagonalLineColor: widget.clearDiagonalLineColor,
                itemHighlightColor: widget.itemHighlightColor,
                itemOutlineColor: widget.itemOutlineColor,
                tabBarSelectedBackgroundColor:
                    widget.tabBarSelectedBackgroundColor,
                tabBarSelectedForegroundColor:
                    widget.tabBarSelectedForegroundColor,
                primaryColor: widget.primaryColor,
                onPrimaryColor: widget.onPrimaryColor,
                outlineColor: widget.outlineColor,
                toolbarHeight: widget.toolbarHeight,
                borderRadius: widget.borderRadius,
                buttonHeight: widget.buttonHeight,
                buttonSpacing: widget.buttonSpacing,
                buttonBorderWidth: widget.buttonBorderWidth,
                buttonSelectedBorderWidth: widget.buttonSelectedBorderWidth,
                child: Material(
                  child: _ToolbarRow(
                    editorState: widget.editorState,
                    toolbarItems: widget.toolbarItems,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({required this.editorState, required this.toolbarItems});

  final EditorState editorState;
  final List<MobileToolbarItem> toolbarItems;

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      width: width,
      height: style.toolbarHeight,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: style.itemOutlineColor),
          bottom: BorderSide(color: style.itemOutlineColor),
        ),
        color: style.backgroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: toolbarItems.length,
              itemBuilder: (context, index) {
                final item = toolbarItems[index];
                final icon = item.itemIconBuilder(context, editorState);
                if (icon == null) return const SizedBox.shrink();
                return IconButton(
                  icon: icon,
                  onPressed: () => item.actionHandler(context, editorState),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: VerticalDivider(width: 1),
          ),
          _CloseKeyboardButton(
            onPressed: () {
              editorState.selection = null;
            },
          ),
          const SizedBox(width: 4.0),
        ],
      ),
    );
  }
}

class _CloseKeyboardButton extends StatelessWidget {
  const _CloseKeyboardButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(
        Icons.keyboard_hide,
        color: MobileToolbarTheme.of(context).iconColor,
      ),
    );
  }
}
