import 'dart:async';
import 'dart:collection';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:appflowy_editor/src/history/undo_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

export 'editor_state/editor_chrome.dart';
export 'editor_state/selection_drag_mode.dart';
export 'editor_state/types.dart';

// Internal mixin files. Kept as `part`/`part of` so they can share
// library-level privacy with EditorState (e.g. `_recordRedoOrUndo`
// remains a private implementation detail not surfaced on the public
// API).
part 'editor_state/history_mixin.dart';
part 'editor_state/selection_style_mixin.dart';

/// The state of the editor.
///
/// The state includes:
/// - The document to render
/// - The state of the selection
///
/// [EditorState] also includes the services of the editor:
/// - Selection service
/// - Scroll service
/// - Keyboard service
/// - Input service
/// - Toolbar service
///
/// In consideration of collaborative editing,
/// all the mutations should be applied through [Transaction].
///
/// Mutating the document with document's API is not recommended.
class EditorState with EditorChromeMixin, HistoryMixin, SelectionStyleMixin {
  EditorState({
    required this.document,
    this.minHistoryItemDuration = const Duration(milliseconds: 50),
    int? maxHistoryItemSize,
  }) {
    _initHistory(maxHistoryItemSize);
    undoManager.state = this;
  }

  EditorState.blank({bool withInitialText = true})
    : this(document: Document.blank(withInitialText: withInitialText));

  final Document document;

  // the minimum duration for saving the history item.
  // Satisfies [HistoryMixin.minHistoryItemDuration] abstract getter.
  @override
  final Duration minHistoryItemDuration;

  /// Whether the editor should disable auto scroll.
  bool disableAutoScroll = false;

  /// The edge offset of the auto scroll.
  double autoScrollEdgeOffset = appFlowyEditorAutoScrollEdgeOffset;

  // Selection/highlight/tap notifiers + selectionType/selectionUpdateReason
  // + selectionExtraInfo live in [SelectionStyleMixin].

  final ValueNotifier<bool> isAutoScrollHighlightNotifier = ValueNotifier(
    false,
  );

  bool get isAutoScrollHighlight => isAutoScrollHighlightNotifier.value;

  set isAutoScrollHighlight(bool value) {
    isAutoScrollHighlightNotifier.value = value;
  }

  // Service reference.
  final service = EditorService();

  AppFlowyScrollService? get scrollService => service.scrollService;

  AppFlowySelectionService get selectionService => service.selectionService;

  BlockComponentRendererService get renderer => service.rendererService;

  set renderer(BlockComponentRendererService value) {
    service.rendererService = value;
  }

  /// store the auto scroller instance in here temporarily.
  AutoScroller? autoScroller;
  ScrollableState? scrollableState;

  /// Configures log output parameters,
  /// such as log level and log output callbacks,
  /// with this variable.
  AppFlowyLogConfiguration get logConfiguration => AppFlowyLogConfiguration();

  /// listen to this stream to get notified when the transaction applies.
  Stream<EditorTransactionValue> get transactionStream => _observer.stream;
  final StreamController<EditorTransactionValue> _observer =
      StreamController.broadcast(sync: true);
  final StreamController<EditorTransactionValue> _asyncObserver =
      StreamController.broadcast();

  // toggledStyle / sliceUpcomingAttributes live in [SelectionStyleMixin].

  Transaction get transaction {
    final transaction = Transaction(document: document);
    transaction.beforeSelection = selection;

    return transaction;
  }

  /// The rules to apply to the document.
  List<DocumentRule> get documentRules => _documentRules;
  List<DocumentRule> _documentRules = [];

  set documentRules(List<DocumentRule> value) {
    _documentRules = value;

    _subscription?.cancel();
    _subscription = _asyncObserver.stream.listen((value) async {
      for (final rule in _documentRules) {
        if (rule.shouldApply(editorState: this, value: value)) {
          await rule.apply(editorState: this, value: value);
        }
      }
    });
  }

  StreamSubscription? _subscription;

  final Set<VoidCallback> _onScrollViewScrolledListeners = {};

  void addScrollViewScrolledListener(VoidCallback callback) =>
      _onScrollViewScrolledListeners.add(callback);

  void removeScrollViewScrolledListener(VoidCallback callback) =>
      _onScrollViewScrolledListeners.remove(callback);

  void _notifyScrollViewScrolledListeners() {
    for (final listener in Set.of(_onScrollViewScrolledListeners)) {
      listener.call();
    }
  }

  RenderBox? get renderBox {
    final renderObject = service.scrollServiceKey.currentContext
        ?.findRenderObject();
    if (renderObject != null && renderObject is RenderBox) {
      return renderObject;
    }

    return null;
  }

  // updateSelectionWithReason / updateHighlight / updateTap live in
  // [SelectionStyleMixin].

  final bool _enableCheckIntegrity = false;

  // the value of the notifier is meaningless, just for triggering the callbacks.
  final ValueNotifier<int> onDispose = ValueNotifier(0);

  bool isDisposed = false;

  void dispose() {
    isAutoScrollHighlightNotifier.dispose();
    isDisposed = true;
    _observer.close();
    _asyncObserver.close();
    _disposeHistory();
    onDispose.value += 1;
    onDispose.dispose();
    document.dispose();
    _disposeSelectionStyle();
    disposeChrome();
    _subscription?.cancel();
    _onScrollViewScrolledListeners.clear();
  }

  /// Apply the transaction to the state.
  ///
  /// The options can be used to determine whether the editor
  /// should record the transaction in undo/redo stack.
  ///
  /// The maximumRuleApplyLoop is used to prevent infinite loop.
  ///
  /// The withUpdateSelection is used to determine whether the editor
  /// should update the selection after applying the transaction.
  Future<void> apply(
    Transaction transaction, {
    bool isRemote = false,
    ApplyOptions options = const ApplyOptions(),
    bool withUpdateSelection = true,
    bool skipHistoryDebounce = false,
  }) async {
    if (!editable || isDisposed) {
      return;
    }

    // it's a time consuming task, only enable it if necessary.
    if (_enableCheckIntegrity) {
      document.root.checkDocumentIntegrity();
    }

    final completer = Completer<void>();

    if (isRemote) {
      _selectionUpdateReason = SelectionUpdateReason.remote;
      selection = _applyTransactionFromRemote(transaction);
    } else {
      // broadcast to other users here, before applying the transaction
      if (!_observer.isClosed) {
        _observer.add((TransactionTime.before, transaction, options));
      }

      if (!_asyncObserver.isClosed) {
        _asyncObserver.add((TransactionTime.before, transaction, options));
      }

      _applyTransactionInLocal(transaction);

      // broadcast to other users here, after applying the transaction
      if (!_observer.isClosed) {
        _observer.add((TransactionTime.after, transaction, options));
      }

      if (!_asyncObserver.isClosed) {
        _asyncObserver.add((TransactionTime.after, transaction, options));
      }

      _recordRedoOrUndo(options, transaction, skipHistoryDebounce);

      if (withUpdateSelection) {
        _selectionUpdateReason =
            transaction.reason ?? SelectionUpdateReason.transaction;
        _selectionType = transaction.customSelectionType;
        if (transaction.selectionExtraInfo != null) {
          selectionExtraInfo = transaction.selectionExtraInfo;
        }
        selection = transaction.afterSelection;
      }
    }

    completer.complete();

    return completer.future;
  }

  /// Force rebuild the editor.
  void reload() {
    document.root.notify();
  }

  /// get nodes in selection
  ///
  /// if selection is backward, return nodes in order
  /// if selection is forward, return nodes in reverse order
  ///
  List<Node> getNodesInSelection(Selection selection) {
    // Normalize the selection.
    final normalized = selection.normalized;

    // Get the start and end nodes.
    final startNode = document.nodeAtPath(normalized.start.path);
    final endNode = document.nodeAtPath(normalized.end.path);

    // If we have both nodes, we can find the nodes in the selection.
    if (startNode != null && endNode != null) {
      final nodes = NodeIterator(
        document: document,
        startNode: startNode,
        endNode: endNode,
      ).toList();

      return selection.isForward ? nodes.reversed.toList() : nodes;
    }

    // If we don't have both nodes, we can't find the nodes in the selection.
    return [];
  }

  List<Node> getSelectedNodes({Selection? selection, bool withCopy = true}) {
    List<Node> res = [];
    selection ??= this.selection;
    if (selection == null) {
      return res;
    }
    final nodes = getNodesInSelection(selection);
    for (final node in nodes) {
      if (res.any((element) => element.isParentOf(node))) {
        continue;
      }
      res.add(node);
    }

    if (withCopy) {
      res = res.map((e) => e.copyWith()).toList();
    }

    if (res.isNotEmpty) {
      var delta = res.first.delta;
      if (delta != null) {
        res.first.updateAttributes({
          ...res.first.attributes,
          blockComponentDelta: delta
              .slice(
                selection.startIndex,
                selection.isSingle ? selection.endIndex : delta.length,
              )
              .toJson(),
        });
      }

      var node = res.last;
      while (node.children.isNotEmpty) {
        node = node.children.last;
      }
      delta = node.delta;
      if (delta != null && !selection.isSingle) {
        if (node.parent != null) {
          node.insertBefore(
            node.copyWith(
              attributes: {
                ...node.attributes,
                blockComponentDelta: delta
                    .slice(0, selection.endIndex)
                    .toJson(),
              },
            ),
          );
          node.unlink();
        } else {
          node.updateAttributes({
            ...node.attributes,
            blockComponentDelta: delta.slice(0, selection.endIndex).toJson(),
          });
        }
      }
    }

    return res;
  }

  Node? getNodeAtPath(Path path) {
    return document.nodeAtPath(path);
  }

  /// The current selection areas's rect in editor.
  List<Rect> selectionRects() {
    final selection = this.selection;
    if (selection == null) {
      return [];
    }

    final nodes = getNodesInSelection(selection);
    final rects = <Rect>[];

    if (selection.isCollapsed && nodes.length == 1) {
      final selectable = nodes.first.selectable;
      if (selectable != null) {
        final rect = selectable.getCursorRectInPosition(
          selection.end,
          shiftWithBaseOffset: true,
        );
        if (rect != null) {
          rects.add(
            selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true),
          );
        }
      }
    } else {
      for (final node in nodes) {
        final selectable = node.selectable;
        if (selectable == null) {
          continue;
        }
        final nodeRects = selectable.getRectsInSelection(
          selection,
          shiftWithBaseOffset: true,
        );
        if (nodeRects.isEmpty) {
          continue;
        }
        final renderBox = node.renderBox;
        if (renderBox == null) {
          continue;
        }
        for (final rect in nodeRects) {
          final globalOffset = renderBox.localToGlobal(rect.topLeft);
          rects.add(globalOffset & rect.size);
        }
      }
    }

    return rects;
  }

  List<Rect> highlightRects(Selection? selection) {
    if (selection == null) {
      return [];
    }

    final nodes = getNodesInSelection(selection);
    final rects = <Rect>[];

    if (selection.isCollapsed && nodes.length == 1) {
      final selectable = nodes.first.selectable;
      if (selectable != null) {
        final rect = selectable.getCursorRectInPosition(
          selection.end,
          shiftWithBaseOffset: true,
        );
        if (rect != null) {
          rects.add(
            selectable.transformRectToGlobal(rect, shiftWithBaseOffset: true),
          );
        }
      }
    } else {
      for (final node in nodes) {
        final selectable = node.selectable;
        if (selectable == null) {
          continue;
        }
        final nodeRects = selectable.getRectsInSelection(
          selection,
          shiftWithBaseOffset: true,
        );
        if (nodeRects.isEmpty) {
          continue;
        }
        final renderBox = node.renderBox;
        if (renderBox == null) {
          continue;
        }
        for (final rect in nodeRects) {
          final globalOffset = renderBox.localToGlobal(rect.topLeft);
          rects.add(globalOffset & rect.size);
        }
      }
    }

    return rects;
  }

  void scrollToHighlight(
    EditorScrollController editorScrollController, {
    Selection? selection,
    bool fromInside = false,
    bool alignToTop = true,
  }) {
    final askedSelection = selection ?? highlight;
    final highlightRects = this.highlightRects(askedSelection);

    final top = highlightRects.firstOrNull?.top;

    if (top != null) {
      editorScrollController.safeAnimateScroll(
        offset: top - 300,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    } else {
      if (fromInside) return;
      final index = askedSelection?.start.path.firstOrNull;
      if (index != null) {
        editorScrollController.jumpToIndex(
          index: index,
          alignment: alignToTop ? 0 : 1,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        Future.delayed(Duration(milliseconds: 0), () {
          scrollToHighlight(
            editorScrollController,
            selection: selection,
            fromInside: true,
          );
        });
      });
    }
  }

  // void jumpToHighlight(EditorScrollController editorScrollController,
  //     {Selection? selection}) {
  //   final askedSelection = selection ?? highlight;
  //   final highlightRects = this.highlightRects(askedSelection);

  //   final top = highlightRects.firstOrNull?.top;

  //   if (top != null) {
  //     editorScrollController.scrollOffsetController.safeJumpTo(
  //       offset: top,
  //     );
  //   }
  // }

  void enableAutoScrollHighlight(
    EditorScrollController editorScrollController,
  ) {
    isAutoScrollHighlightNotifier.value = true;
    highlightChanged(editorScrollController);
  }

  void disableAutoScrollHighlight() {
    isAutoScrollHighlightNotifier.value = false;
  }

  void highlightChanged(EditorScrollController editorScrollController) {
    if (isAutoScrollHighlightNotifier.value) {
      scrollToHighlight(editorScrollController);
    }
  }

  void cancelSubscription() {
    _observer.close();
  }

  void updateAutoScroller(ScrollableState scrollableState) {
    if (this.scrollableState != scrollableState) {
      autoScroller?.stopAutoScroll();
      final bool isDesktopOrWeb = PlatformExtension.isDesktopOrWeb;
      late AutoScroller scroller;
      scroller = AutoScroller(
        scrollableState,
        // Framework EdgeDraggingAutoScroller: per-tick duration is
        // `1000 / velocityScalar` ms, delta per tick is the raw over-drag
        // (capped to 20 px). 50 ≈ 20ms tick → ~1000 px/s top speed when the
        // cursor sits hard against the edge. The old fork value 0.15 (with
        // an 80ms desktop tick) worked out to ~40 px/s, which felt unusably
        // slow on long documents.
        velocityScalar: 50,
        onScrollViewScrolled: () {
          _notifyScrollViewScrolledListeners();
          if (!isDesktopOrWeb) {
            // The field is the untyped `Map?` we publish to the rest of
            // the editor; cast at the boundary so the typed accessor can
            // do its work.
            final info = SelectionExtraInfo.from(
              selectionExtraInfo?.cast<String, Object?>(),
            );
            if (!info.isDraggingSelection) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (autoScroller == scroller) {
                scroller.continueToAutoScroll();
              }
            });
          }
        },
      );
      autoScroller = scroller;
      this.scrollableState = scrollableState;
    }
  }

  void _applyTransactionInLocal(Transaction transaction) {
    for (final op in transaction.operations) {
      AppFlowyEditorLog.editor.debug('apply op (local): ${op.toJson()}');

      if (op is InsertOperation) {
        document.insert(op.path, op.nodes);
      } else if (op is UpdateOperation) {
        // ignore the update operation if the attributes are the same.
        if (!mapEquals(op.attributes, op.oldAttributes)) {
          document.update(op.path, op.attributes);
        }
      } else if (op is DeleteOperation) {
        document.delete(op.path, op.nodes.length);
      } else if (op is UpdateTextOperation) {
        document.updateText(op.path, op.delta);
      }
    }
  }

  Selection? _applyTransactionFromRemote(Transaction transaction) {
    var selection = this.selection;

    for (final op in transaction.operations) {
      AppFlowyEditorLog.editor.debug('apply op (remote): ${op.toJson()}');

      if (op is InsertOperation) {
        document.insert(op.path, op.nodes);
        if (selection != null) {
          if (op.path <= selection.start.path) {
            selection = Selection(
              start: selection.start.copyWith(
                path: selection.start.path.nextNPath(op.nodes.length),
              ),
              end: selection.end.copyWith(
                path: selection.end.path.nextNPath(op.nodes.length),
              ),
            );
          }
        }
      } else if (op is UpdateOperation) {
        document.update(op.path, op.attributes);
      } else if (op is DeleteOperation) {
        document.delete(op.path, op.nodes.length);
        if (selection != null) {
          if (op.path <= selection.start.path) {
            selection = Selection(
              start: selection.start.copyWith(
                path: selection.start.path.previous,
              ),
              end: selection.end.copyWith(path: selection.end.path.previous),
            );
          }
        }
      } else if (op is UpdateTextOperation) {
        document.updateText(op.path, op.delta);
      }
    }

    return selection;
  }
}
