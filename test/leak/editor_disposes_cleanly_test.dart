import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

// Repro for downstream tearDownAll leak reports: generic framework classes
// (SingleChildRenderObjectElement, RenderConstrainedBox, RenderMouseRegion)
// flagged as notGCed after editor widgets detach. Tracks all leak types so
// the baseline shows everything the editor leaves behind on dispose.

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    AppFlowyEditorLocalizations.delegate,
  ],
  supportedLocales: AppFlowyEditorLocalizations.delegate.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

// Tracks notDisposed only — catches real "owner forgot to call dispose()"
// bugs. notGCed/gcedLate are intentionally off: in a full test-suite run
// (memory pressure, lots of widget churn) GC of widget-tree elements
// finalizes a frame or two late and `experimentalAllNotGCed` floods the
// report with framework classes (SingleChildRenderObjectElement, RenderObject
// subtypes) that are *eventually* GC'd. That noise drowns the real signal
// without flagging an actual dispose miss.
//
// Ignored notDisposed classes:
//   - ExtentManager: super_sliver_list 0.4.1 element never disposes its
//     ChangeNotifier (latest available, no upstream fix yet).
//   - KeepEditorFocusNotifier: package-level singleton; disposing it
//     would break the next editor instance.
final _leakSettings = LeakTesting.settings.withTrackedAll().withIgnored(
  notDisposed: {'ExtentManager': null, 'KeepEditorFocusNotifier': null},
);

void main() {
  group('leak baseline — editor mount/detach cycle', () {
    testWidgets(
      'blank editor disposes cleanly',
      experimentalLeakTesting: _leakSettings,
      (tester) async {
        final editorState = EditorState.blank(withInitialText: true);

        await tester.pumpWidget(
          _wrap(AppFlowyEditor(editorState: editorState)),
        );
        await tester.pump();

        // Detach widget tree.
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 100));

        // Caller owns editorState lifecycle (per editor.dart:273 — widget
        // only disposes the scroll controller it created itself).
        editorState.dispose();
      },
    );

    testWidgets(
      'editor with 20 paragraphs disposes cleanly',
      experimentalLeakTesting: _leakSettings,
      (tester) async {
        final editorState = EditorState(
          document: Document.blank()
            ..insert([
              0,
            ], List.generate(20, (i) => paragraphNode(text: 'Paragraph $i'))),
        );

        await tester.pumpWidget(
          _wrap(AppFlowyEditor(editorState: editorState)),
        );
        await tester.pump();

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 100));

        editorState.dispose();
      },
    );

    testWidgets(
      'editor with floating toolbar disposes cleanly',
      experimentalLeakTesting: _leakSettings,
      (tester) async {
        final editorState = EditorState(
          document: Document.blank()
            ..insert(
              [0],
              List.generate(
                10,
                (i) => paragraphNode(text: 'Paragraph $i with content'),
              ),
            ),
        );
        final scrollController = EditorScrollController(
          editorState: editorState,
        );

        await tester.pumpWidget(
          _wrap(
            FloatingToolbar(
              items: [paragraphItem, ...headingItems, ...markdownFormatItems],
              editorState: editorState,
              editorScrollController: scrollController,
              textDirection: TextDirection.ltr,
              child: AppFlowyEditor(
                editorState: editorState,
                editorScrollController: scrollController,
              ),
            ),
          ),
        );
        await tester.pump();

        // Range selection forces FloatingToolbar to materialize its overlay
        // (CompositedTransformFollower + MouseRegion + RenderConstrainedBox
        // — the cascade the downstream sees as notGCed).
        editorState.selection = Selection(
          start: Position(path: [0], offset: 0),
          end: Position(path: [0], offset: 5),
        );
        await tester.pump();
        // Debounce in _showAfterDelay is 200ms; pump past it plus a frame so
        // the overlay actually mounts before we tear down.
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(
          find.byType(FloatingToolbarWidget),
          findsOneWidget,
          reason: 'FloatingToolbar overlay must mount for this leak repro',
        );

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 100));

        scrollController.dispose();
        editorState.dispose();
      },
    );

    testWidgets(
      'editor with mobile floating toolbar disposes cleanly',
      experimentalLeakTesting: _leakSettings,
      (tester) async {
        final editorState = EditorState(
          document: Document.blank()
            ..insert(
              [0],
              List.generate(
                10,
                (i) => paragraphNode(text: 'Paragraph $i with content'),
              ),
            ),
        );
        final scrollController = EditorScrollController(
          editorState: editorState,
        );

        await tester.pumpWidget(
          _wrap(
            MobileFloatingToolbar(
              editorState: editorState,
              editorScrollController: scrollController,
              floatingToolbarHeight: 50,
              toolbarBuilder: (context, anchor, close) =>
                  const SizedBox(width: 200, height: 50, child: Placeholder()),
              child: AppFlowyEditor(
                editorState: editorState,
                editorScrollController: scrollController,
              ),
            ),
          ),
        );
        await tester.pump();

        editorState.selection = Selection(
          start: Position(path: [0], offset: 0),
          end: Position(path: [0], offset: 5),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 100));

        scrollController.dispose();
        editorState.dispose();
      },
    );

    testWidgets(
      'editor with mobile toolbar (always-mounted bar) disposes cleanly',
      experimentalLeakTesting: _leakSettings,
      (tester) async {
        final editorState = EditorState(
          document: Document.blank()
            ..insert([
              0,
            ], List.generate(10, (i) => paragraphNode(text: 'Paragraph $i'))),
        );

        await tester.pumpWidget(
          _wrap(
            MobileToolbarV2(
              editorState: editorState,
              toolbarItems: const [],
              child: AppFlowyEditor(editorState: editorState),
            ),
          ),
        );
        await tester.pump();

        // Set a selection so MobileToolbar's inner builder runs (it gates on
        // selection != null).
        editorState.selection = Selection.collapsed(
          Position(path: [0], offset: 1),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 100));

        editorState.dispose();
      },
    );
  });
}
