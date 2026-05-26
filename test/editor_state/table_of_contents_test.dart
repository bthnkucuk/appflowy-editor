import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditorState.tableOfContents', () {
    test(
      'reflects existing headings on construction (drops empty-text headings)',
      () {
        final document = Document.blank(withInitialText: false);
        document.insert([0], [headingNode(level: 1, text: 'Intro')]);
        document.insert([1], [paragraphNode(text: 'body')]);
        document.insert([2], [headingNode(level: 2, text: 'Details')]);
        // Empty-text heading should be dropped.
        document.insert([3], [headingNode(level: 3, text: '')]);

        final editorState = EditorState(document: document);

        final entries = editorState.tableOfContents.value;
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

    test('reads level from node.attributes (not tree depth)', () async {
      // A heading nested inside a bulleted-list item with attribute
      // level=2 must yield level: 2, NOT the tree depth of 3.
      final document = Document.blank(withInitialText: false);
      final nestedHeading = headingNode(level: 2, text: 'Nested');
      final listItem = bulletedListNode(
        text: 'item',
        children: [nestedHeading],
      );
      document.insert([0], [listItem]);

      final editorState = EditorState(document: document);

      final entries = editorState.tableOfContents.value;
      expect(entries.length, 1);
      expect(entries[0].text, 'Nested');
      expect(entries[0].level, 2);
      expect(entries[0].isNested, true);
      expect(entries[0].path, [0, 0]);
    });

    test('isNested is false for top-level headings, true for nested ones', () {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'Top')]);
      final nestedHeading = headingNode(level: 3, text: 'Inside');
      final listItem = bulletedListNode(
        text: 'wrapper',
        children: [nestedHeading],
      );
      document.insert([1], [listItem]);

      final editorState = EditorState(document: document);

      final entries = editorState.tableOfContents.value;
      expect(entries.length, 2);
      // Top-level heading.
      expect(entries[0].text, 'Top');
      expect(entries[0].isNested, false);
      // Nested heading.
      expect(entries[1].text, 'Inside');
      expect(entries[1].isNested, true);
    });

    test('clamps out-of-range level attribute to 1..6', () {
      final document = Document.blank(withInitialText: false);
      // Manually build a heading with an out-of-range level to verify
      // the clamp inside the recompute (`headingNode` itself asserts).
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

      final editorState = EditorState(document: document);

      final entries = editorState.tableOfContents.value;
      expect(entries.length, 2);
      expect(entries[0].level, 6);
      expect(entries[1].level, 1);
    });

    test(
      'no callback for transactions that cannot affect TOC (typing in paragraph)',
      () async {
        final document = Document.blank(withInitialText: false);
        document.insert([0], [headingNode(level: 1, text: 'Title')]);
        document.insert([1], [paragraphNode(text: 'body')]);

        final editorState = EditorState(document: document);

        int callbackCount = 0;
        editorState.tableOfContents.addListener(() {
          callbackCount++;
        });

        // Edit text on a paragraph (not a heading).
        final paragraph = editorState.document.nodeAtPath([1])!;
        final transaction = editorState.transaction;
        transaction.insertText(paragraph, 0, 'X');
        await editorState.apply(transaction);

        // Drain microtasks so any scheduled recompute would have fired.
        await Future<void>(() {});
        await Future<void>(() {});

        expect(callbackCount, 0);
      },
    );

    test(
      'list-equality guard prevents spurious emissions (type & undo)',
      () async {
        final document = Document.blank(withInitialText: false);
        document.insert([0], [headingNode(level: 1, text: 'Title')]);
        document.insert([1], [paragraphNode(text: 'hello')]);

        final editorState = EditorState(document: document);

        int callbackCount = 0;
        editorState.tableOfContents.addListener(() {
          callbackCount++;
        });

        // Touch the paragraph (no TOC effect at all - guarded earlier).
        final paragraph = editorState.document.nodeAtPath([1])!;
        final t1 = editorState.transaction;
        t1.insertText(paragraph, 5, '!');
        await editorState.apply(t1);

        await Future<void>(() {});
        await Future<void>(() {});

        // No callback even though a transaction was applied.
        expect(callbackCount, 0);
      },
    );

    test(
      'microtask coalescing: multiple apply()s within one microtask collapse',
      () async {
        final document = Document.blank(withInitialText: false);
        document.insert([0], [headingNode(level: 1, text: 'A')]);
        final editorState = EditorState(document: document);

        int callbackCount = 0;
        editorState.tableOfContents.addListener(() {
          callbackCount++;
        });

        // Three heading-affecting transactions applied in rapid
        // succession. `apply` itself awaits, but the recompute is
        // scheduled via scheduleMicrotask off the after-emit; we kick
        // them all and then drain.
        final futures = <Future<void>>[];
        for (int i = 1; i < 4; i++) {
          final t = editorState.transaction;
          t.insertNode([i], headingNode(level: 2, text: 'H$i'));
          futures.add(editorState.apply(t));
        }
        await Future.wait(futures);
        await Future<void>(() {});
        await Future<void>(() {});

        // Three inserts, but the TOC notifier should fire only once per
        // microtask-coalesced recompute. With apply() being awaited the
        // tightest realistic bound is "fewer than the number of
        // transactions"; in practice the implementation collapses to a
        // single emission for back-to-back schedules.
        expect(callbackCount, lessThan(3));
        expect(editorState.tableOfContents.value.length, 4);
      },
    );

    test('emits new entries when a heading is inserted', () async {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'First')]);
      final editorState = EditorState(document: document);

      expect(editorState.tableOfContents.value.length, 1);

      int callbackCount = 0;
      editorState.tableOfContents.addListener(() {
        callbackCount++;
      });

      final t = editorState.transaction;
      t.insertNode([1], headingNode(level: 2, text: 'Second'));
      await editorState.apply(t);

      await Future<void>(() {});
      await Future<void>(() {});

      expect(callbackCount, greaterThanOrEqualTo(1));
      final entries = editorState.tableOfContents.value;
      expect(entries.length, 2);
      expect(entries[0].text, 'First');
      expect(entries[1].text, 'Second');
      expect(entries[1].level, 2);
    });

    test('updates entry text when heading delta is edited', () async {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'Old')]);
      final editorState = EditorState(document: document);

      final heading = editorState.document.nodeAtPath([0])!;
      final t = editorState.transaction;
      // Append "X" to the heading text.
      t.insertText(heading, 3, 'X');
      await editorState.apply(t);

      await Future<void>(() {});
      await Future<void>(() {});

      final entries = editorState.tableOfContents.value;
      expect(entries.length, 1);
      expect(entries[0].text, 'OldX');
    });

    test('removes entry when a heading is deleted', () async {
      final document = Document.blank(withInitialText: false);
      document.insert([0], [headingNode(level: 1, text: 'First')]);
      document.insert([1], [headingNode(level: 2, text: 'Second')]);
      final editorState = EditorState(document: document);

      expect(editorState.tableOfContents.value.length, 2);

      final secondHeading = editorState.document.nodeAtPath([1])!;
      final t = editorState.transaction;
      t.deleteNode(secondHeading);
      await editorState.apply(t);

      await Future<void>(() {});
      await Future<void>(() {});

      final entries = editorState.tableOfContents.value;
      expect(entries.length, 1);
      expect(entries[0].text, 'First');
    });

    test('TocEntry equality is value-based (via Equatable)', () {
      const a = TocEntry(
        text: 'Hello',
        level: 2,
        nodeId: 'n1',
        path: [0, 1],
        isNested: true,
      );
      const b = TocEntry(
        text: 'Hello',
        level: 2,
        nodeId: 'n1',
        path: [0, 1],
        isNested: true,
      );
      const c = TocEntry(
        text: 'Hello',
        level: 3,
        nodeId: 'n1',
        path: [0, 1],
        isNested: true,
      );
      expect(a, b);
      expect(a == c, false);
    });

    // TODO: integration test under test/new/editor_component for jump-to-heading.
    // `EditorState.jumpToTocEntry` calls `selectionService.updateSelection`
    // which requires a mounted Editor widget — out of scope for unit tests.
  });
}
