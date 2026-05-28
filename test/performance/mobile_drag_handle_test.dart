import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/editor_robot.dart';
import '../new/infra/testable_editor.dart';

/// Regression tests for the mobile long-press + drag-handle gesture
/// chain.
///
/// These exercises sit on top of the `EditorRobot` extension in
/// `test/new/infra/editor_robot.dart` and gate behaviors recently
/// landed under ROADMAP H2.3.x / H2.8.x.
void main() {
  group('EditorRobot — Android long-press drag across blocks', () {
    setUp(() {
      PlatformExtension.debugPlatformOverride = DebugPlatform.android;
    });

    tearDown(() {
      PlatformExtension.debugPlatformOverride = null;
    });

    testWidgets(
      'long-press + drag extends selection across blocks (H2.3.e gate)',
      (tester) async {
        // Pre-H2.3.e a long-press drag that crossed block boundaries
        // could be clobbered by the AutoScroller writing a collapsed
        // cursor back into selection, losing the cross-block extension.
        final editor = tester.editor
          ..addParagraphs(5, initialText: 'Hello world this is a test');
        await editor.startTesting(inMobile: true);
        await tester.pumpAndSettle();

        // Long-press in paragraph 0 mid-word "world" — Android strategy
        // expands selection to the word boundary.
        final gesture = await tester.longPressInParagraph(0, 6);

        try {
          var selection = editor.selection;
          expect(selection, isNotNull, reason: 'long-press start');
          expect(selection!.start.path, equals([0]));
          expect(selection.end.path, equals([0]));
          expect(selection.isCollapsed, isFalse);

          // Drag the in-flight long-press to paragraph 3 — the
          // word-boundary at offset 5 lands inside the second word.
          await tester.dragLongPressTo(gesture, 3, 5);

          selection = editor.selection;
          expect(
            selection,
            isNotNull,
            reason: 'selection must survive drag across blocks',
          );
          expect(
            selection!.start.path,
            equals([0]),
            reason:
                'Selection anchor should stay in paragraph 0 — the '
                'long-press started there.',
          );
          expect(
            selection.end.path,
            equals([3]),
            reason:
                'Drag target is in paragraph 3 — selection should '
                'extend to that block. Pre-H2.3.e a mid-drag scroll '
                'tick could collapse this back to paragraph 0.',
          );
          expect(
            selection.isCollapsed,
            isFalse,
            reason: 'cross-block selection cannot be collapsed',
          );
        } finally {
          await tester.releaseLongPress(gesture);
        }

        await editor.dispose();
      },
    );

    testWidgets(
      'long-press end resets dragMode to none (H2.3.f IME wiring gate)',
      (tester) async {
        // Pre-H2.3.f, the IME-skip flag set by the long-press path
        // wasn't cleared on release, so subsequent taps would skip
        // re-attaching the text service and the keyboard wouldn't
        // come back. The contract is: after `onLongPressEnd`,
        // `pan.dragMode == MobileSelectionDragMode.none` and the
        // selectionExtraInfo published to listeners no longer carries
        // a non-none dragMode.
        final editor = tester.editor
          ..addParagraphs(3, initialText: 'Hello world this is a test');
        await editor.startTesting(inMobile: true);
        await tester.pumpAndSettle();

        final gesture = await tester.longPressInParagraph(1, 6);
        // Sanity: while held, the dragMode key is published.
        expect(
          editor.editorState.selectionExtraInfo?[selectionDragModeKey],
          equals(MobileSelectionDragMode.cursor),
          reason:
              'while long-press is held, selectionExtraInfo must '
              'publish dragMode=cursor (Android strategy contract).',
        );

        await tester.releaseLongPress(gesture);

        final dragModeAfter =
            editor.editorState.selectionExtraInfo?[selectionDragModeKey];
        expect(
          dragModeAfter == null ||
              dragModeAfter == MobileSelectionDragMode.none,
          isTrue,
          reason:
              'After onLongPressEnd, selectionExtraInfo must not carry '
              'a non-none MobileSelectionDragMode. Got: $dragModeAfter. '
              'Pre-H2.3.f this leaked, keeping the IME attached/skip '
              'flag stuck.',
        );

        await editor.dispose();
      },
    );
  });

  group('EditorRobot — iOS long-press places collapsed cursor', () {
    setUp(() {
      PlatformExtension.debugPlatformOverride = DebugPlatform.ios;
    });

    tearDown(() {
      PlatformExtension.debugPlatformOverride = null;
    });

    testWidgets(
      'iOS long-press places a collapsed cursor at the press position',
      (tester) async {
        // iOS uses the long-press to enter cursor-drag mode with a
        // collapsed selection (and a magnifier in production). The
        // Android path expands to a word boundary; iOS deliberately
        // does not.
        final editor = tester.editor
          ..addParagraphs(5, initialText: 'Hello world this is a test');
        await editor.startTesting(inMobile: true);
        await tester.pumpAndSettle();

        final gesture = await tester.longPressInParagraph(2, 6);

        try {
          final selection = editor.selection;
          expect(selection, isNotNull);
          expect(
            selection!.isCollapsed,
            isTrue,
            reason:
                'iOS onLongPressStart writes a collapsed cursor — only '
                'the long-press *move* should grow the selection. If '
                'this becomes a word-range, the iOS path has drifted '
                'into Android behavior.',
          );
          expect(selection.start.path, equals([2]));
          // Round to a character bucket: layout drift across host
          // platforms can push the hit-test to the adjacent character,
          // but it must stay within "Hello "..."world" (offsets ~4-9).
          expect(
            selection.start.offset,
            inInclusiveRange(4, 9),
            reason:
                'Press was inside "world" (offset 6) — collapsed '
                'cursor should land in the same character bucket.',
          );

          // H2.9.b probe: an earlier agent report claimed iOS does NOT
          // publish `selectionDragModeKey` to `selectionExtraInfo` the
          // way Android does — but iOS routes through the wrapper
          // `_MobileSelectionServiceWidgetState.updateSelection`
          // (mobile_selection_service.dart:189-216), which DOES include
          // the dragMode in its extraInfo. Lock that in here so the
          // scroll-service / IME-skip paths can rely on the same
          // contract on both platforms.
          final dragMode = editor
              .editorState
              .selectionExtraInfo?[selectionDragModeKey];
          expect(
            dragMode,
            equals(MobileSelectionDragMode.cursor),
            reason:
                'iOS onLongPressStart must publish dragMode=cursor '
                'so the scroll-service auto-scroll path and the '
                'keyboard-service IME-skip gate can branch on the '
                'same key Android uses.',
          );
        } finally {
          await tester.releaseLongPress(gesture);
        }

        await editor.dispose();
      },
    );
  });
}
