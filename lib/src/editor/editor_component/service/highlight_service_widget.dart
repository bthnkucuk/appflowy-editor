import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_highlight_service.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart';
import 'package:flutter/material.dart';

class HighlightServiceWidget extends StatefulWidget {
  const HighlightServiceWidget({
    super.key,
    this.highlightColor = const Color.fromARGB(53, 111, 201, 231),
    required this.child,
  });

  final Widget child;
  final Color highlightColor;

  @override
  State<HighlightServiceWidget> createState() => _HighlightServiceWidgetState();
}

class _HighlightServiceWidgetState extends State<HighlightServiceWidget>
    with WidgetsBindingObserver
    implements AppFlowySelectionService {
  final forwardKey = GlobalKey(
    debugLabel: 'forward_to_platform_highlight_service',
  );
  AppFlowySelectionService get forward =>
      forwardKey.currentState as AppFlowySelectionService;

  @override
  Widget build(BuildContext context) {
    // if (PlatformExtension.isDesktopOrWeb) {
    //   return DesktopSelectionServiceWidget(
    //     key: forwardKey,
    //     cursorColor: widget.cursorColor,
    //     contextMenuItems: widget.contextMenuItems,
    //     dropTargetStyle:
    //         widget.dropTargetStyle ?? const AppFlowyDropTargetStyle(),
    //     child: widget.child,
    //   );
    // }

    return MobileHighlightServiceWidget(
      key: forwardKey,
      highlightColor: widget.highlightColor,
      child: widget.child,
    );
  }

  @override
  void clearCursor() => forward.clearCursor();

  @override
  void clearSelection() => forward.clearSelection();

  @override
  List<Node> get currentSelectedNodes => forward.currentSelectedNodes;

  @override
  ValueNotifier<Selection?> get currentSelection => forward.currentSelection;

  @override
  Node? getNodeInOffset(Offset offset) => forward.getNodeInOffset(offset);

  @override
  Position? getPositionInOffset(Offset offset) =>
      forward.getPositionInOffset(offset);

  @override
  void registerGestureInterceptor(SelectionGestureInterceptor interceptor) =>
      forward.registerGestureInterceptor(interceptor);

  @override
  List<Rect> get selectionRects => forward.selectionRects;

  @override
  void unregisterGestureInterceptor(String key) =>
      forward.unregisterGestureInterceptor(key);

  @override
  void updateSelection(Selection? selection) =>
      forward.updateSelection(selection);

  @override
  Selection? onPanStart(
    DragStartDetails details,
    MobileSelectionDragMode mode,
  ) =>
      forward.onPanStart(details, mode);

  @override
  Selection? onPanUpdate(
    DragUpdateDetails details,
    MobileSelectionDragMode mode,
  ) =>
      forward.onPanUpdate(details, mode);

  @override
  void onPanEnd(
    DragEndDetails details,
    MobileSelectionDragMode mode,
  ) =>
      forward.onPanEnd(details, mode);

  @override
  void removeDropTarget() => forward.removeDropTarget();

  @override
  void renderDropTargetForOffset(
    Offset offset, {
    DragAreaBuilder? builder,
    DragTargetNodeInterceptor? interceptor,
  }) =>
      forward.renderDropTargetForOffset(
        offset,
        builder: builder,
        interceptor: interceptor,
      );

  @override
  DropTargetRenderData? getDropTargetRenderData(
    Offset offset, {
    DragTargetNodeInterceptor? interceptor,
  }) =>
      forward.getDropTargetRenderData(
        offset,
        interceptor: interceptor,
      );
}
