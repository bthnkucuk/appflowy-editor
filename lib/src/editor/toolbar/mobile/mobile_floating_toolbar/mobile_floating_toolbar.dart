import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart';
import 'package:flutter/material.dart';

const selectionExtraInfoDisableFloatingToolbar = 'disableFloatingToolbar';

/// A mobile floating toolbar that displays at the top of the editor when the
/// selection is not collapsed.
///   and will be hidden when the selection is collapsed.
///
/// Normally, it will show copy, cut, paste.
class MobileFloatingToolbar extends StatefulWidget {
  const MobileFloatingToolbar({
    super.key,
    required this.editorState,
    required this.editorScrollController,
    required this.child,
    required this.toolbarBuilder,
    required this.floatingToolbarHeight,
  });

  final EditorState editorState;
  final EditorScrollController editorScrollController;
  final Widget child;
  final double floatingToolbarHeight;
  final Widget Function(
    BuildContext context,
    Offset anchor,
    VoidCallback closeToolbar,
  )
  toolbarBuilder;

  @override
  State<MobileFloatingToolbar> createState() => _MobileFloatingToolbarState();
}

class _MobileFloatingToolbarState extends State<MobileFloatingToolbar>
    with WidgetsBindingObserver {
  final OverlayPortalController _portalController = OverlayPortalController();

  EditorState get editorState => widget.editorState;

  Offset _anchor = Offset.zero;

  // use for skipping the first build for the toolbar when the selection is collapsed.
  Selection? prevSelection;

  VoidCallback? _onScrollEnd;

  late final StreamSubscription _onTapSelectionAreaSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    editorState.selectionNotifier.addListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.addListener(
      _onScrollPositionChanged,
    );
    _onTapSelectionAreaSubscription = appFlowyEditorOnTapSelectionArea.stream
        .listen((event) {
          _portalController.isShowing ? _clear() : _showAfterDelay();
        });
  }

  @override
  void didUpdateWidget(MobileFloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editorState != oldWidget.editorState) {
      editorState.selectionNotifier.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    editorState.selectionNotifier.removeListener(_onSelectionChanged);
    widget.editorScrollController.offsetNotifier.removeListener(
      _onScrollPositionChanged,
    );
    _onTapSelectionAreaSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();

    _clear();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && _onScrollEnd != null) {
          _onScrollEnd!.call();
          _onScrollEnd = null;
        }

        return false;
      },
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (overlayContext) {
          return widget.toolbarBuilder(overlayContext, _anchor, _clear);
        },
        child: widget.child,
      ),
    );
  }

  void _onSelectionChanged() {
    final selection = editorState.selection;
    final selectionType = editorState.selectionType;
    if (selection == null || selectionType == SelectionType.block) {
      _clear();
    } else if (selection.isCollapsed) {
      if (_portalController.isShowing) {
        _clear();
      } else if (prevSelection == selection &&
          editorState.selectionUpdateReason == SelectionUpdateReason.uiEvent &&
          editorState
                  .selectionExtraInfo?[selectionExtraInfoDisableFloatingToolbar] !=
              true) {
        _showAfterDelay();
      }
      prevSelection = selection;
    } else {
      _clear();
      final dragMode = editorState.selectionExtraInfo?[selectionDragModeKey];
      if ([
        MobileSelectionDragMode.leftSelectionHandle,
        MobileSelectionDragMode.rightSelectionHandle,
      ].contains(dragMode)) {
        return;
      }

      if (editorState
              .selectionExtraInfo?[selectionExtraInfoDisableFloatingToolbar] !=
          true) {
        _showAfterDelay();
      }
    }
  }

  void _onScrollPositionChanged() {
    // ignore: avoid_print
    print(
      '[FLOAT-DBG] _onScrollPositionChanged '
      'isShowing=${_portalController.isShowing} '
      'dy=${widget.editorScrollController.offsetNotifier.value}',
    );
    // Hide while scrolling, re-show once the scroll comes to rest. Cheaper
    // than continuously re-computing the anchor each scroll tick — and
    // matches the old OverlayEntry-based behavior.
    if (_portalController.isShowing) {
      _portalController.hide();
      prevSelection = null;
      _onScrollEnd ??= () => _showAfterDelay(const Duration(milliseconds: 50));
    }
  }

  final String _debounceKey = 'show the toolbar';

  void _clear() {
    // ignore: avoid_print
    print('[FLOAT-DBG] _clear (isShowing=${_portalController.isShowing})');
    Debounce.cancel(_debounceKey);

    if (_portalController.isShowing) {
      _portalController.hide();
    }
    prevSelection = null;
  }

  void _showAfterDelay([Duration duration = Duration.zero]) {
    // uses debounce to avoid the computing the rects too frequently.
    Debounce.debounce(_debounceKey, duration, () {
      if (!mounted) return;
      _showToolbar();
    });
  }

  void _showToolbar() {
    final rects = editorState.selectionRects();
    if (rects.isEmpty) {
      // ignore: avoid_print
      print('[FLOAT-DBG] _showToolbar skipped (no rects)');
      return;
    }
    final rect = _findSuitableRect(rects);
    // Empty is determined only if there is only one selection area
    if (rects.length <= 1 && rect.isEmpty) {
      // ignore: avoid_print
      print('[FLOAT-DBG] _showToolbar skipped (empty single rect)');
      return;
    }
    // ignore: avoid_print
    print(
      '[FLOAT-DBG] _showToolbar SHOW anchor=${rect.topCenter} '
      'wasShowing=${_portalController.isShowing}',
    );
    setState(() {
      _anchor = rect.topCenter;
    });
    if (!_portalController.isShowing) {
      _portalController.show();
    }
  }

  Rect _findSuitableRect(Iterable<Rect> rects) {
    assert(rects.isNotEmpty);

    final editorOffset =
        editorState.renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    // find the min offset with non-negative dy.
    final rectsWithNonNegativeDy = rects.where(
      (element) => element.top >= editorOffset.dy,
    );
    if (rectsWithNonNegativeDy.isEmpty) {
      // if all the rects offset is negative, then the selection is not visible.
      return Rect.zero;
    }

    final minRect = rectsWithNonNegativeDy.reduce((min, current) {
      if (min.top < current.top) {
        return min;
      } else if (min.top == current.top) {
        return min.top < current.top ? min : current;
      } else {
        return current;
      }
    });

    return minRect;
  }
}
