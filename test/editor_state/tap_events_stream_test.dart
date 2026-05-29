import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage for the `editorState.tapEvents` broadcast stream that
/// replaced the old `tapNotifier` channel. The mobile highlight service
/// publishes deliberate tap-ups here via `editorState.notifyTap`;
/// consumers subscribe with `.listen`. Crucially, publishing on this
/// stream does NOT mutate `editorState.selection` — so a tap on a
/// `highlightable: true` + `editable: false` viewer doesn't paint a
/// stale selection rect via `BlockSelectionArea`.
EditorState _makeEditorState() {
  return EditorState(
    document: Document.blank()
      ..insert(
        [0],
        [paragraphNode(text: 'Hello world')],
      ),
  );
}

void main() {
  group('EditorState.tapEvents stream', () {
    test('notifyTap publishes the selection on tapEvents', () async {
      final editorState = _makeEditorState();
      final selection = Selection.collapsed(Position(path: [0], offset: 3));

      final completer = Completer<Selection>();
      final sub = editorState.tapEvents.listen(completer.complete);

      editorState.notifyTap(selection);

      expect(await completer.future, selection);

      await sub.cancel();
      editorState.dispose();
    });

    test(
      'notifyTap does NOT mutate selection or stamp '
      'SelectionUpdateReason.tap (no selection-rect paint side effect)',
      () async {
        final editorState = _makeEditorState();
        final selection = Selection.collapsed(Position(path: [0], offset: 4));

        final sub = editorState.tapEvents.listen((_) {});

        editorState.notifyTap(selection);
        // Let the broadcast microtask flush.
        await Future<void>.value();

        expect(
          editorState.selection,
          isNull,
          reason:
              'tapEvents is a side-channel — it must not write the '
              "editor's selection.",
        );
        expect(
          editorState.selectionUpdateReason,
          isNot(SelectionUpdateReason.tap),
          reason:
              'No selection update should be recorded; the default '
              'reason should remain.',
        );

        await sub.cancel();
        editorState.dispose();
      },
    );

    test('tapEvents is broadcast — multiple subscribers each receive the event',
        () async {
      final editorState = _makeEditorState();
      final selection = Selection.collapsed(Position(path: [0], offset: 2));

      final firstCompleter = Completer<Selection>();
      final secondCompleter = Completer<Selection>();
      final sub1 = editorState.tapEvents.listen(firstCompleter.complete);
      final sub2 = editorState.tapEvents.listen(secondCompleter.complete);

      editorState.notifyTap(selection);

      expect(await firstCompleter.future, selection);
      expect(await secondCompleter.future, selection);

      await sub1.cancel();
      await sub2.cancel();
      editorState.dispose();
    });

    test('tapEvents closes when EditorState is disposed', () async {
      final editorState = _makeEditorState();

      final doneCompleter = Completer<void>();
      final sub = editorState.tapEvents.listen(
        (_) {},
        onDone: doneCompleter.complete,
      );

      editorState.dispose();

      // The done event should arrive without timing out.
      await doneCompleter.future.timeout(const Duration(seconds: 1));
      await sub.cancel();
    });

    test(
      'notifyTap after dispose is a no-op (does not throw)',
      () async {
        final editorState = _makeEditorState();
        editorState.dispose();

        // After dispose the stream controller is closed; a stray late
        // emission from a not-yet-detached service must not crash.
        // `notifyTap` guards on `isClosed` for exactly this reason.
        expect(
          () => editorState.notifyTap(
            Selection.collapsed(Position(path: [0], offset: 0)),
          ),
          returnsNormally,
        );
      },
    );

    // End-to-end integration of MobileHighlightServiceWidget._applySelection
    // -> notifyTap -> tapEvents is exercised by the example's
    // `tts_reader_page.dart` and verified manually on device; replicating
    // it here would require driving platform-specific pointer events
    // through the gesture detector, which produces a flaky timer-bound
    // test (a fully mounted editor keeps unrelated post-frame work
    // running). The unit tests above plus the unconditional
    // `notifyTap` call site in `_applySelection` cover the contract.
  });
}
