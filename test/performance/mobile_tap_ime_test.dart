import 'package:appflowy_editor/src/editor/editor_component/service/selection/mobile_selection_service.dart'
    as mss;
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/editor_robot.dart';
import '../new/infra/testable_editor.dart';

/// Mobile gesture / IME regression scenarios driven through the
/// `EditorRobot` extension (`test/new/infra/editor_robot.dart`).
///
/// Each group flips `PlatformExtension.debugPlatformOverride` so the
/// `SelectionServiceWidget` mounts the mobile branch on the macOS test
/// host, then exercises:
///
/// * double-tap → word boundary selection (Android),
/// * triple-tap → whole-node selection (Android),
/// * IME insertion into the active caret selection (Android),
/// * iOS long-press magnifier visibility cycle.
void main() {
  group('EditorRobot — Android double-tap', () {
    setUp(() {
      PlatformExtension.debugPlatformOverride = DebugPlatform.android;
    });

    tearDown(() {
      PlatformExtension.debugPlatformOverride = null;
    });

    testWidgets('double-tap inside a word selects that word', (tester) async {
      final editor = tester.editor
        ..addParagraphs(3, initialText: 'Hello world foo bar');
      await editor.startTesting(inMobile: true);
      await tester.pumpAndSettle();

      // Tap inside "world" (offset 6 lands between 'w' and 'o').
      await tester.doubleTapInParagraph(0, 6);

      final selection = editor.selection;
      expect(
        selection,
        isNotNull,
        reason: 'Double-tap must produce a non-null selection — the gesture '
            'arena delivered the second tap to onDoubleTapUp.',
      );
      expect(selection!.isCollapsed, isFalse, reason: 'Word boundary is a range.');
      expect(selection.start.path, equals([0]));
      expect(selection.end.path, equals([0]));
      // 'Hello world foo bar' — "world" is offsets 6..11.
      expect(selection.start.offset, lessThanOrEqualTo(6));
      expect(selection.end.offset, greaterThanOrEqualTo(11));
      expect(
        selection.start.offset <= 6 && selection.end.offset >= 6,
        isTrue,
        reason: 'Selection should contain the tap offset 6.',
      );

      await editor.dispose();
    });
  });

  group('EditorRobot — Android triple-tap', () {
    setUp(() {
      PlatformExtension.debugPlatformOverride = DebugPlatform.android;
    });

    tearDown(() {
      PlatformExtension.debugPlatformOverride = null;
    });

    testWidgets('triple-tap selects the whole paragraph', (tester) async {
      final editor = tester.editor
        ..addParagraphs(3, initialText: 'Hello world foo bar');
      await editor.startTesting(inMobile: true);
      await tester.pumpAndSettle();

      await tester.tripleTapInParagraph(0, 6);

      final selection = editor.selection;
      expect(
        selection,
        isNotNull,
        reason: 'Triple-tap must produce a non-null selection.',
      );
      expect(selection!.start.path, equals([0]));
      expect(selection.end.path, equals([0]));
      // 'Hello world foo bar' is 19 characters.
      expect(selection.start.offset, equals(0));
      expect(selection.end.offset, equals(19));

      await editor.dispose();
    });
  });

  group('EditorRobot — Android IME', () {
    setUp(() {
      PlatformExtension.debugPlatformOverride = DebugPlatform.android;
    });

    tearDown(() {
      PlatformExtension.debugPlatformOverride = null;
    });

    testWidgets('typeImeText writes into the active caret selection', (
      tester,
    ) async {
      final editor = tester.editor..addParagraph(initialText: '');
      await editor.startTesting(inMobile: true);
      await tester.pumpAndSettle();

      await tester.placeCaretInParagraph(0, 0);
      await tester.typeImeText(editor, 'hello');

      final node = editor.editorState.getNodeAtPath([0]);
      expect(node, isNotNull);
      expect(
        node!.delta?.toPlainText(),
        equals('hello'),
        reason:
            'IME insertion at offset 0 of an empty paragraph should land '
            'literally — placeCaret writes the selection, MockIMEInput sends '
            'a TextEditingDeltaInsertion through the live TextInputService.',
      );

      await editor.dispose();
    });
  });

  group('EditorRobot — iOS magnifier visibility', () {
    setUp(() {
      PlatformExtension.debugPlatformOverride = DebugPlatform.ios;
      // Global default is true (magnifier off). Flip for this group so
      // MagnifierOverlay actually paints when pan.lastPanOffset is set.
      mss.disableMagnifier = false;
    });

    tearDown(() {
      // Reset both globals so we leave a clean harness behind — see
      // feedback_mixin_on_clause-style "sticky global" warning in the
      // task description.
      mss.disableMagnifier = true;
      PlatformExtension.debugPlatformOverride = null;
    });

    testWidgets('iOS magnifier appears during long-press and disappears on release', (
      tester,
    ) async {
      final editor = tester.editor
        ..addParagraphs(3, initialText: 'Hello world foo bar');
      await editor.startTesting(inMobile: true);
      await tester.pumpAndSettle();

      tester.expectMagnifierVisible(visible: false);

      final gesture = await tester.longPressInParagraph(0, 6);
      try {
        // The iOS strategy sets pan.lastPanOffset on onLongPressStart, so
        // MagnifierOverlay should resolve to a non-shrink subtree on the
        // next frame.
        await tester.pump();
        tester.expectMagnifierVisible(visible: true);
      } finally {
        await tester.releaseLongPress(gesture);
      }

      // onLongPressEnd → pan.clearPan() → lastPanOffset = null →
      // MagnifierOverlay collapses to SizedBox.shrink.
      tester.expectMagnifierVisible(visible: false);

      await editor.dispose();
    });
  });
}
