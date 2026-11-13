import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/base_component/selection/block_highlight_area.dart';
import 'package:appflowy_editor/src/editor/block_component/base_component/selection/selection_area_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Delegate with Diagnosticable implements SelectableMixin {
  int measurements = 0;
  double scale = 1;

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    measurements++;
    return [
      Rect.fromLTWH(
        selection.start.offset * 5 * scale,
        0,
        (selection.end.offset - selection.start.offset) * 5 * scale,
        20,
      ),
    ];
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    measurements++;
    return Rect.fromLTWH(position.offset * 5 * scale, 0, 1, 20);
  }

  @override
  bool get shouldCursorBlink => false;
  @override
  CursorStyle get cursorStyle => CursorStyle.verticalLine;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fixture {
  _Fixture() {
    editor = EditorState(
      document: Document(root: pageNode(children: [node])),
    );
    node.sections = Sections([
      Section(
        index: 0,
        text: 'one two',
        parent: node,
        selection: Selection.single(path: [], startOffset: 0, endOffset: 7),
      ),
    ]);
  }

  final node = paragraphNode(text: 'one two three');
  final delegate = _Delegate();
  late final EditorState editor;
  final selection = ValueNotifier<Selection?>(null);
  final highlight = ValueNotifier<Selection?>(null);
  final contentWidth = ValueNotifier<double>(100);

  Widget view({ValueNotifier<Selection?>? highlights}) => MaterialApp(
    home: Provider<EditorState>.value(
      value: editor,
      child: Align(
        alignment: Alignment.topLeft,
        child: BlockSelectionContainer(
          key: const ValueKey('block'),
          node: node,
          delegate: delegate,
          listenable: selection,
          highlight: highlights ?? highlight,
          highlightAreaColor: Colors.deepPurple.withValues(alpha: .2),
          child: ValueListenableBuilder<double>(
            valueListenable: contentWidth,
            builder: (_, width, _) => SizedBox(width: width, height: 40),
          ),
        ),
      ),
    ),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    selection.dispose();
    highlight.dispose();
    contentWidth.dispose();
    editor.dispose();
    editor.editableNotifier.dispose();
  }
}

Selection _word(int start, int end) =>
    Selection.single(path: [0], startOffset: start, endOffset: end);

void main() {
  for (final activeHighlight in [false, true]) {
    testWidgets(
      'unrelated frames do not poll block geometry (highlight: $activeHighlight)',
      (tester) async {
        final f = _Fixture();
        addTearDown(() => f.dispose(tester));
        if (activeHighlight) f.highlight.value = _word(0, 3);
        await tester.pumpWidget(f.view());
        await tester.pumpAndSettle();
        f.delegate.measurements = 0;
        for (var frame = 0; frame < 24; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(f.delegate.measurements, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets('playback highlights move between words and clear', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(() => f.dispose(tester));
    await tester.pumpWidget(f.view());
    await tester.pumpAndSettle();
    for (final word in [_word(0, 3), _word(4, 7), _word(8, 13)]) {
      f.highlight.value = word;
      await tester.pumpAndSettle();
      final wordPaint = tester
          .widgetList<HighlightAreaPaint>(find.byType(HighlightAreaPaint))
          .last;
      expect(wordPaint.rects, [
        Rect.fromLTWH(
          word.start.offset * 5,
          0,
          (word.end.offset - word.start.offset) * 5,
          20,
        ),
      ]);
    }
    f.highlight.value = null;
    await tester.pumpAndSettle();
    expect(find.byType(HighlightAreaPaint), findsNothing);
  });

  testWidgets('selection and cursor update without a continuing frame loop', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(() => f.dispose(tester));
    await tester.pumpWidget(f.view());
    await tester.pumpAndSettle();
    f.selection.value = _word(0, 3);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectionAreaPaint>(find.byType(SelectionAreaPaint)).rects,
      [const Rect.fromLTWH(0, 0, 15, 20)],
    );
    f.selection.value = _word(4, 4);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionAreaPaint), findsNothing);
    final measurements = f.delegate.measurements;
    await tester.pump(const Duration(milliseconds: 100));
    expect(f.delegate.measurements, measurements);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'layout changes refresh both the word and cached sentence geometry',
    (tester) async {
      final f = _Fixture();
      addTearDown(() => f.dispose(tester));
      f.highlight.value = _word(0, 3);
      await tester.pumpWidget(f.view());
      await tester.pumpAndSettle();
      final before = f.delegate.measurements;
      f.delegate.scale = 2;
      // Only the content changes size. The selection widgets are not rebuilt by
      // their parent, so this exercises actual layout invalidation.
      f.contentWidth.value = 200;
      await tester.pumpAndSettle();
      final paints = tester
          .widgetList<HighlightAreaPaint>(find.byType(HighlightAreaPaint))
          .toList();
      expect(paints.first.rects, [const Rect.fromLTWH(0, 0, 70, 20)]);
      expect(paints.last.rects, [const Rect.fromLTWH(0, 0, 30, 20)]);
      expect(f.delegate.measurements, greaterThan(before));
      final settled = f.delegate.measurements;
      await tester.pump(const Duration(milliseconds: 100));
      expect(f.delegate.measurements, settled);
    },
  );

  testWidgets(
    'replaced notifiers detach and queued updates are safe on disposal',
    (tester) async {
      final f = _Fixture();
      final replacement = ValueNotifier<Selection?>(_word(4, 7));
      addTearDown(replacement.dispose);
      addTearDown(() => f.dispose(tester));
      await tester.pumpWidget(f.view());
      await tester.pumpAndSettle();
      await tester.pumpWidget(f.view(highlights: replacement));
      await tester.pumpAndSettle();
      f.delegate.measurements = 0;
      f.highlight.value = _word(0, 3);
      await tester.pump();
      expect(f.delegate.measurements, 0);
      replacement.value = _word(8, 13);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
