import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

const String selectionExtraInfoDisableMobileToolbarKey = 'disableMobileToolbar';

/// Legacy hook kept so existing [MobileToolbarItem.itemIconBuilder] signatures
/// still compile. The new inline-above-keyboard toolbar has no menu state to
/// expose, so [closeItemMenu] is a no-op.
abstract class MobileToolbarWidgetService {
  void closeItemMenu();
}

class _NoopToolbarService implements MobileToolbarWidgetService {
  const _NoopToolbarService();
  @override
  void closeItemMenu() {}
}

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
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        ValueListenableBuilder<Selection?>(
          valueListenable: widget.editorState.selectionNotifier,
          builder: (_, selection, _) {
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
                final icon = item.itemIconBuilder?.call(
                  context,
                  editorState,
                  const _NoopToolbarService(),
                );
                if (icon == null) return const SizedBox.shrink();
                return IconButton(
                  icon: icon,
                  onPressed: () {
                    // withMenu items are legacy — their inline menu was
                    // removed when sheet variants replaced them. Tapping is
                    // a no-op; callers should migrate to the sheet variant.
                    item.actionHandler?.call(context, editorState);
                  },
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
