import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage for the auto-scroll-highlight subscription wired into
/// [EditorState] via `_ScrollCoordinatorMixin`. The mixin should
/// subscribe to `highlightNotifier` when `enableAutoScrollHighlight` is
/// called and call `scrollToHighlight` on every change until disabled.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

EditorState _makeEditorState({int paragraphs = 30}) {
  return EditorState(
    document: Document.blank()
      ..insert(
        [0],
        List.generate(
          paragraphs,
          (i) => paragraphNode(text: 'Paragraph $i — some words to scroll past'),
        ),
      ),
  );
}

void main() {
  group('EditorState auto-scroll-highlight subscription', () {
    testWidgets(
      'enableAutoScrollHighlight subscribes to highlightNotifier and drives '
      'scrollToHighlight on each updateHighlight without an explicit '
      'highlightChanged call',
      (tester) async {
        final editorState = _makeEditorState();
        final controller = EditorScrollController(editorState: editorState);

        await tester.pumpWidget(
          _wrap(
            AppFlowyEditor(
              editorState: editorState,
              editorScrollController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Count safeAnimateScroll triggers by listening to scrollController.
        // visibleRangeNotifier flips as scroll lands; rather than depend on
        // that, observe the first/last visible index window before vs after
        // calling updateHighlight on a far-away highlight.
        editorState.enableAutoScrollHighlight(controller);
        await tester.pumpAndSettle();

        final initialRange = controller.visibleRangeNotifier.value;

        // Highlight a paragraph well below the viewport. The subscription
        // should kick the scroller without us calling highlightChanged.
        editorState.updateHighlight(
          Selection.collapsed(Position(path: [25])),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final afterRange = controller.visibleRangeNotifier.value;
        // Either the visible window moved, or scrollToHighlight resolved a
        // top offset and animated — both are evidence the subscription
        // fired. Compare for inequality on the first index.
        expect(
          afterRange.$1 != initialRange.$1 || afterRange.$2 != initialRange.$2,
          isTrue,
          reason:
              'Expected visible range to shift after updateHighlight while '
              'auto-scroll subscription is active (range was $initialRange, '
              'now $afterRange).',
        );

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        controller.dispose();
        editorState.dispose();
      },
    );

    testWidgets(
      'disableAutoScrollHighlight detaches the listener — subsequent '
      'updateHighlight calls do not move the viewport',
      (tester) async {
        final editorState = _makeEditorState();
        final controller = EditorScrollController(editorState: editorState);

        await tester.pumpWidget(
          _wrap(
            AppFlowyEditor(
              editorState: editorState,
              editorScrollController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        editorState.enableAutoScrollHighlight(controller);
        await tester.pumpAndSettle();
        editorState.disableAutoScrollHighlight();
        await tester.pump();

        final rangeBefore = controller.visibleRangeNotifier.value;

        editorState.updateHighlight(
          Selection.collapsed(Position(path: [25])),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final rangeAfter = controller.visibleRangeNotifier.value;
        expect(
          rangeAfter,
          rangeBefore,
          reason:
              'Disabled subscription must not move the viewport on '
              'updateHighlight (was $rangeBefore, now $rangeAfter).',
        );

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        controller.dispose();
        editorState.dispose();
      },
    );

    testWidgets(
      'repeated enableAutoScrollHighlight does not stack listeners — '
      'one updateHighlight produces a single scroll-to-highlight pass',
      (tester) async {
        // We can't directly count framework safeAnimateScroll calls, but we
        // can inspect highlightNotifier's listener-count semantics:
        // PropertyValueNotifier (a ChangeNotifier) exposes
        // `hasListeners` (protected). We instead verify behavioural
        // idempotence: calling enable N times then disable once must fully
        // unsubscribe (no residual scroll on a later updateHighlight).
        final editorState = _makeEditorState();
        final controller = EditorScrollController(editorState: editorState);

        await tester.pumpWidget(
          _wrap(
            AppFlowyEditor(
              editorState: editorState,
              editorScrollController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Three engagements — second/third must be no-op on the listener
        // (idempotent subscribe).
        editorState.enableAutoScrollHighlight(controller);
        editorState.enableAutoScrollHighlight(controller);
        editorState.enableAutoScrollHighlight(controller);
        await tester.pumpAndSettle();

        // A single disable must fully detach.
        editorState.disableAutoScrollHighlight();
        await tester.pump();

        final rangeBefore = controller.visibleRangeNotifier.value;
        editorState.updateHighlight(
          Selection.collapsed(Position(path: [25])),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final rangeAfter = controller.visibleRangeNotifier.value;
        expect(
          rangeAfter,
          rangeBefore,
          reason:
              'After a single disableAutoScrollHighlight, no listener '
              'should remain — but viewport moved from $rangeBefore to '
              '$rangeAfter, suggesting stacked listeners.',
        );

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        controller.dispose();
        editorState.dispose();
      },
    );

    testWidgets(
      'disposing the editorState mid-subscription does not fire the listener',
      (tester) async {
        final editorState = _makeEditorState();
        final controller = EditorScrollController(editorState: editorState);

        await tester.pumpWidget(
          _wrap(
            AppFlowyEditor(
              editorState: editorState,
              editorScrollController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        editorState.enableAutoScrollHighlight(controller);
        await tester.pumpAndSettle();

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        controller.dispose();
        editorState.dispose();

        // Editor is disposed; the highlightNotifier was also disposed by
        // _disposeSelectionStyle. The mixin must have detached its
        // listener in _disposeScrollCoordinator, or this pump would throw
        // "A disposed ChangeNotifier was used".
        await tester.pump();
      },
    );

    testWidgets(
      'highlight changes within the same section do not trigger scroll; '
      'crossing a section boundary does',
      (tester) async {
        // Long paragraphs so each holds multiple sentence sections; soft=20
        // makes the parser split on the first sentence boundary past 20
        // characters, ensuring multiple sections per node.
        final editorState = EditorState(
          document: Document.blank()
            ..insert(
              [0],
              List.generate(
                30,
                (i) => paragraphNode(
                  text:
                      'First sentence of paragraph $i is here. Second '
                      'sentence of the same paragraph follows. Third one '
                      'finishes the block.',
                ),
              ),
            ),
        );
        editorState.sectionParser = (node) =>
            defaultSentenceSectionParser(node, soft: 20, hard: 200);
        final controller = EditorScrollController(editorState: editorState);

        await tester.pumpWidget(
          _wrap(
            AppFlowyEditor(
              editorState: editorState,
              editorScrollController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        editorState.enableAutoScrollHighlight(controller);

        // Land a highlight on the first sentence of paragraph 20.
        editorState.updateHighlight(
          Selection(
            start: Position(path: [20], offset: 0),
            end: Position(path: [20], offset: 5),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final rangeAfterInitial = controller.visibleRangeNotifier.value;

        // Move highlight within the SAME first sentence — same section.
        // Coalesce should kick in and the viewport must stay put.
        editorState.updateHighlight(
          Selection(
            start: Position(path: [20], offset: 10),
            end: Position(path: [20], offset: 15),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          controller.visibleRangeNotifier.value,
          rangeAfterInitial,
          reason:
              'Same-section highlight change must not re-trigger scroll '
              '(coalesce by enclosing Section).',
        );

        // Cross into a different block / different sections → fresh scroll.
        editorState.updateHighlight(
          Selection(
            start: Position(path: [5], offset: 0),
            end: Position(path: [5], offset: 5),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          controller.visibleRangeNotifier.value,
          isNot(rangeAfterInitial),
          reason:
              'Cross-section highlight change must trigger a scroll '
              '(viewport should now show a different block).',
        );

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        controller.dispose();
        editorState.dispose();
      },
    );
  });
}
