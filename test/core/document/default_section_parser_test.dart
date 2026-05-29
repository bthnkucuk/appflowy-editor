import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

Node _nodeWithText(String text) =>
    paragraphNode(delta: Delta()..insert(text));

void main() {
  group('defaultSentenceSectionParser', () {
    test('returns null for a node with no delta', () {
      final node = Node(type: 'paragraph');
      expect(
        defaultSentenceSectionParser(node, soft: 50, hard: 500),
        isNull,
      );
    });

    test('returns null for empty plain text', () {
      // Node with a delta whose plain text is '' — `text` getter is null
      // in this case, so `delta?.toPlainText()` returns ''. Parser must
      // not produce a single empty section.
      final node = paragraphNode(delta: Delta()..insert(''));
      expect(
        defaultSentenceSectionParser(node, soft: 50, hard: 500),
        isNull,
      );
    });

    test('returns a single section for text shorter than soft', () {
      final node = _nodeWithText('Hello world.');
      final sections = defaultSentenceSectionParser(node, soft: 50, hard: 500)!;
      expect(sections, hasLength(1));
      expect(sections.first.text, 'Hello world.');
      expect(sections.first.selection.start.offset, 0);
      expect(sections.first.selection.end.offset, 'Hello world.'.length);
    });

    test('splits at sentence boundary inside [soft, hard]', () {
      // Two sentences, each ~30 chars; with soft=20 we expect a cut at
      // the first sentence boundary found after offset 20.
      const first = 'The quick brown fox jumps over.';
      const second = 'Then the dog barks loudly.';
      final node = _nodeWithText('$first $second');

      final sections = defaultSentenceSectionParser(node, soft: 20, hard: 200)!;
      expect(sections.length, greaterThanOrEqualTo(2));
      expect(sections.first.text.endsWith('over. '), isTrue);
    });

    test('hard-cuts when no sentence boundary inside the window', () {
      // 600-char run of lowercase + commas — no sentence terminator at
      // all. Parser must still terminate, cutting at hard=100.
      final text = ('lorem ipsum dolor sit amet, ' * 30).substring(0, 600);
      final node = _nodeWithText(text);

      final sections = defaultSentenceSectionParser(node, soft: 50, hard: 100)!;
      // Every section but the last is exactly hard chars; last is the
      // remainder.
      for (var i = 0; i < sections.length - 1; i++) {
        expect(sections[i].text.length, 100);
      }
    });

    test('offsets sum to the full text length with no gaps or overlaps', () {
      final text =
          'First sentence here. Second sentence follows. Third one wraps things up. '
          'And here is a longer continuation that crosses the soft window without a terminator '
          'until eventually we land on another full stop.';
      final node = _nodeWithText(text);

      final sections = defaultSentenceSectionParser(node, soft: 40, hard: 200)!;
      expect(sections.first.selection.start.offset, 0);
      for (var i = 1; i < sections.length; i++) {
        expect(
          sections[i].selection.start.offset,
          sections[i - 1].selection.end.offset,
          reason: 'section $i should start where section ${i - 1} ends',
        );
      }
      expect(sections.last.selection.end.offset, text.length);
      expect(
        sections.map((s) => s.text).join(),
        text,
        reason: 'concatenated section texts must equal the original',
      );
    });

    test('respects non-ASCII sentence boundaries (Turkish, Arabic, English)', () {
      // Turkish + English + Arabic question mark. The regex's terminator
      // class includes '؟' and the trailing context allows non-cased
      // scripts, so each sentence here is a valid cut point.
      const text =
          'Merhaba dünya. Hello again. مرحبا؟ Final sentence here finishes the paragraph.';
      final node = _nodeWithText(text);

      final sections = defaultSentenceSectionParser(node, soft: 10, hard: 200)!;
      expect(
        sections.length,
        greaterThan(1),
        reason: 'multilingual terminators should produce multiple sections',
      );
      expect(
        sections.map((s) => s.text).join(),
        text,
      );
    });
  });
}
