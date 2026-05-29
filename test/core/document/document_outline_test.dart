import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Document.computeOutline', () {
    test(
      'reflects existing headings, drops empty-text ones',
      () {
        final document = Document.blank(withInitialText: false);
        document.insert([0], [headingNode(level: 1, text: 'Intro')]);
        document.insert([1], [paragraphNode(text: 'body')]);
        document.insert([2], [headingNode(level: 2, text: 'Details')]);
        // Empty-text heading should be dropped.
        document.insert([3], [headingNode(level: 3, text: '')]);

        final entries = document.computeOutline();
        expect(entries.length, 2);
        expect(entries[0].text, 'Intro');
        expect(entries[0].level, 1);
        expect(entries[0].path, [0]);
        expect(entries[0].isNested, false);
        expect(entries[1].text, 'Details');
        expect(entries[1].level, 2);
        expect(entries[1].path, [2]);
        expect(entries[1].isNested, false);
      },
    );

    test('reads level from node.attributes (not tree depth)', () {
      // A heading nested inside a bulleted-list item with attribute
      // level=2 must yield level: 2, NOT the tree depth of 3.
      final document = Document.blank(withInitialText: false);
      final nestedHeading = headingNode(level: 2, text: 'Nested');
      final listItem = bulletedListNode(
        text: 'item',
        children: [nestedHeading],
      );
      document.insert([0], [listItem]);

      final entries = document.computeOutline();
      expect(entries.length, 1);
      expect(entries[0].text, 'Nested');
      expect(entries[0].level, 2);
      expect(entries[0].isNested, true);
      expect(entries[0].path, [0, 0]);
    });

    test('isNested is false for top-level, true for nested', () {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'Top')]);
      final nestedHeading = headingNode(level: 3, text: 'Inside');
      final listItem = bulletedListNode(
        text: 'wrapper',
        children: [nestedHeading],
      );
      document.insert([1], [listItem]);

      final entries = document.computeOutline();
      expect(entries.length, 2);
      expect(entries[0].text, 'Top');
      expect(entries[0].isNested, false);
      expect(entries[1].text, 'Inside');
      expect(entries[1].isNested, true);
    });

    test('clamps out-of-range level attribute to 1..6', () {
      final document = Document.blank(withInitialText: false);
      final outOfRange = Node(
        type: HeadingBlockKeys.type,
        attributes: {
          HeadingBlockKeys.delta: (Delta()..insert('Huge')).toJson(),
          HeadingBlockKeys.level: 99,
        },
      );
      final tooSmall = Node(
        type: HeadingBlockKeys.type,
        attributes: {
          HeadingBlockKeys.delta: (Delta()..insert('Tiny')).toJson(),
          HeadingBlockKeys.level: -3,
        },
      );
      document.insert([0], [outOfRange, tooSmall]);

      final entries = document.computeOutline();
      expect(entries.length, 2);
      expect(entries[0].level, 6);
      expect(entries[1].level, 1);
    });

    test('maxDepth filters out deeper headings', () {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'H1')]);
      document.insert([1], [headingNode(level: 2, text: 'H2')]);
      document.insert([2], [headingNode(level: 3, text: 'H3')]);
      document.insert([3], [headingNode(level: 4, text: 'H4')]);

      final all = document.computeOutline();
      expect(all.length, 4);

      final shallow = document.computeOutline(maxDepth: 2);
      expect(shallow.length, 2);
      expect(shallow.map((e) => e.level), [1, 2]);
    });

    test('OutlineEntry equality is value-based', () {
      const a = OutlineEntry(
        text: 'Hello',
        level: 2,
        nodeId: 'n1',
        path: [0, 1],
        isNested: true,
      );
      const b = OutlineEntry(
        text: 'Hello',
        level: 2,
        nodeId: 'n1',
        path: [0, 1],
        isNested: true,
      );
      const c = OutlineEntry(
        text: 'Hello',
        level: 3,
        nodeId: 'n1',
        path: [0, 1],
        isNested: true,
      );
      expect(a, b);
      expect(a == c, false);
    });

    test('selection getter returns a collapsed Selection at the path', () {
      final entry = OutlineEntry(
        text: 'Heading',
        level: 1,
        nodeId: 'n0',
        path: const [2],
        isNested: false,
      );
      final selection = entry.selection;
      expect(selection.isCollapsed, true);
      expect(selection.start.path, [2]);
      expect(selection.start.offset, 0);
    });
  });

  group('Document.tableOfContents', () {
    test('synonym for computeOutline() with default args', () {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'A')]);
      document.insert([1], [headingNode(level: 2, text: 'B')]);

      expect(document.tableOfContents, document.computeOutline());
    });
  });

  group('EditorState.tableOfContents', () {
    test('emits the current outline on first read', () {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'Intro')]);
      document.insert([1], [paragraphNode(text: 'body')]);
      final state = EditorState(document: document);
      addTearDown(state.dispose);

      final outline = state.tableOfContents.value;
      expect(outline.length, 1);
      expect(outline.first.text, 'Intro');
    });

    test('the same notifier is returned across reads', () {
      final state = EditorState.blank();
      addTearDown(state.dispose);

      expect(identical(state.tableOfContents, state.tableOfContents), true);
    });

    test('fires listeners when a heading is inserted via apply()', () async {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [paragraphNode(text: 'body')]);
      final state = EditorState(document: document);
      addTearDown(state.dispose);

      final firedValues = <List<OutlineEntry>>[];
      state.tableOfContents.addListener(() {
        firedValues.add(state.tableOfContents.value);
      });

      final transaction = state.transaction
        ..insertNode([0], headingNode(level: 1, text: 'New heading'));
      await state.apply(transaction);

      expect(firedValues, isNotEmpty);
      expect(firedValues.last.length, 1);
      expect(firedValues.last.first.text, 'New heading');
    });

    test('skips listener fire when transaction does not change the outline',
        () async {
      // A keystroke inside a paragraph still emits a transaction, but the
      // computed outline is byte-equal to the previous one — listEquals
      // short-circuits, no listener fire.
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'Stable')]);
      document.insert([1], [paragraphNode(text: 'body')]);
      final state = EditorState(document: document);
      addTearDown(state.dispose);

      // Engage the notifier so the subscription is attached.
      state.tableOfContents.value;

      var listenerCount = 0;
      state.tableOfContents.addListener(() => listenerCount++);

      // Mutate the paragraph (not a heading) — outline shouldn't change.
      final transaction = state.transaction
        ..updateNode(document.nodeAtPath([1])!, {
          ParagraphBlockKeys.delta: (Delta()..insert('different body')).toJson(),
        });
      await state.apply(transaction);

      expect(listenerCount, 0);
    });
  });
}
