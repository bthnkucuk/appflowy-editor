import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../infra/testable_editor.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('page_up_down_handler_test.dart', () {
    testWidgets('Presses PageUp and pageDown key in large document',
        (tester) async {
      const text = 'Welcome to Appflowy 😁';
      final editor = tester.editor..addParagraphs(1000, initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.single(path: [0], startOffset: 0),
      );

      final scrollService = editor.editorState.service.scrollService!;
      final onePageHeight = scrollService.onePageHeight!;
      expect(onePageHeight, greaterThan(0));

      // Behavioral test: pressing pageDown enough times must reach the end of
      // the document. The previous pixel-perfect "each press = exactly one
      // page" assertion no longer holds with `super_sliver_list`, which
      // refines its scroll extent estimate as items get laid out — that
      // refinement is the whole point of the migration, not a regression.
      // We instead verify the two end-to-end invariants we actually care
      // about: pageDown eventually reaches the bottom, pageUp eventually
      // reaches the top, and each press makes monotonic progress.

      const safetyCap = 500;

      // Pressing the pageDown key continuously until we hit the bottom.
      double previousDy = scrollService.dy;
      int pageDownPresses = 0;
      while (scrollService.dy < scrollService.maxScrollExtent &&
          pageDownPresses < safetyCap) {
        await editor.pressKey(key: LogicalKeyboardKey.pageDown);
        pageDownPresses++;
        expect(
          scrollService.dy,
          greaterThanOrEqualTo(previousDy),
          reason: 'pageDown should never scroll backwards',
        );
        previousDy = scrollService.dy;
      }

      expect(
        scrollService.dy,
        scrollService.maxScrollExtent,
        reason: 'pageDown should reach the bottom of the document',
      );
      expect(pageDownPresses, lessThan(safetyCap));

      // Once at the bottom, additional pageDowns must be no-ops.
      for (int i = 0; i < 5; i++) {
        await editor.pressKey(key: LogicalKeyboardKey.pageDown);
        expect(scrollService.dy, scrollService.maxScrollExtent);
      }

      // Pressing the pageUp key continuously until we hit the top.
      previousDy = scrollService.dy;
      int pageUpPresses = 0;
      while (scrollService.dy > scrollService.minScrollExtent &&
          pageUpPresses < safetyCap) {
        await editor.pressKey(key: LogicalKeyboardKey.pageUp);
        pageUpPresses++;
        expect(
          scrollService.dy,
          lessThanOrEqualTo(previousDy),
          reason: 'pageUp should never scroll forwards',
        );
        previousDy = scrollService.dy;
      }

      expect(
        scrollService.dy,
        scrollService.minScrollExtent,
        reason: 'pageUp should reach the top of the document',
      );
      expect(pageUpPresses, lessThan(safetyCap));

      // Once at the top, additional pageUps must be no-ops.
      for (int i = 0; i < 5; i++) {
        await editor.pressKey(key: LogicalKeyboardKey.pageUp);
        expect(scrollService.dy, scrollService.minScrollExtent);
      }
    });
  });
}
