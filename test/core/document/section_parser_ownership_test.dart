import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

// Cheap test parser: one section per node containing the full text.
Sections _wholeTextParser(Node node) {
  final text = node.delta?.toPlainText() ?? '';
  return Sections([
    Section(
      index: 0,
      text: text,
      selection: Selection(
        start: Position(path: node.path, offset: 0),
        end: Position(path: node.path, offset: text.length),
      ),
      parent: node,
    ),
  ]);
}

// Distinct output so we can detect cross-pollination between parsers.
Sections _prefixedParser(String prefix) {
  return Sections([
    Section(
      index: 0,
      text: prefix,
      selection: Selection(
        start: Position(path: [], offset: 0),
        end: Position(path: [], offset: prefix.length),
      ),
      parent: Node(type: 'paragraph'),
    ),
  ]);
}

Node _para(String text) => paragraphNode(delta: Delta()..insert(text));

void main() {
  group('per-Document sectionParser ownership', () {
    test('parser assignment does not eagerly walk the tree', () {
      final doc = Document(
        root: Node(
          type: 'page',
          children: [_para('Hello world.')],
        ),
      );

      doc.sectionParser = _wholeTextParser;

      // Internal cache backing field must still be untouched — assigning
      // the parser shouldn't run it. We verify via the public-ish path:
      // reading sections produces a result, but before that read the
      // computation hasn't happened (we can't directly peek private
      // state from outside the library, so we use an observable: the
      // parser is not invoked until sections is read).
      var invocations = 0;
      doc.sectionParser = (node) {
        invocations++;
        return _wholeTextParser(node);
      };
      expect(invocations, 0);
      // First read triggers compute.
      doc.first!.sections;
      expect(invocations, 1);
      // Second read uses cache.
      doc.first!.sections;
      expect(invocations, 1);
    });

    test('delta-ref change invalidates the cache', () {
      final doc = Document(
        root: Node(
          type: 'page',
          children: [_para('First text.')],
        ),
      );
      doc.sectionParser = _wholeTextParser;

      final node = doc.first!;
      expect(node.sections!.first.text, 'First text.');

      node.updateAttributes({
        'delta': (Delta()..insert('Second text.')).toJson(),
      });

      expect(node.sections!.first.text, 'Second text.');
    });

    test('parser swap invalidates the cache', () {
      final doc = Document(
        root: Node(
          type: 'page',
          children: [_para('Anything.')],
        ),
      );

      doc.sectionParser = (_) => _prefixedParser('A');
      expect(doc.first!.sections!.first.text, 'A');

      doc.sectionParser = (_) => _prefixedParser('B');
      expect(doc.first!.sections!.first.text, 'B');
    });

    test('independent documents do not see each other parsers', () {
      final docA = Document(
        root: Node(type: 'page', children: [_para('Doc A text.')]),
      );
      final docB = Document(
        root: Node(type: 'page', children: [_para('Doc B text.')]),
      );

      docA.sectionParser = (_) => _prefixedParser('FROM-A');
      // docB has no parser.

      expect(docA.first!.sections!.first.text, 'FROM-A');
      expect(docB.first!.sections, isNull);
    });

    test('no parser anywhere yields null sections', () {
      final doc = Document(
        root: Node(type: 'page', children: [_para('Hello.')]),
      );
      expect(doc.first!.sections, isNull);
    });

    test(
      'deep fromJson + late parser assignment resolves the deep path',
      () {
        final json = {
          'document': {
            'type': 'page',
            'children': [
              {
                'type': 'paragraph',
                'children': [
                  {
                    'type': 'paragraph',
                    'children': [
                      {
                        'type': 'paragraph',
                        'data': {
                          'delta': [
                            {'insert': 'Deep leaf text.'},
                          ],
                        },
                      },
                    ],
                  },
                ],
              },
            ],
          },
        };

        final doc = Document.fromJson(json);
        // Parser assigned AFTER tree exists — the original race
        // regression: leaf's path was [] when computed in the
        // constructor; now it's lazy, so this should report the
        // full nested path.
        doc.sectionParser = _wholeTextParser;

        final leaf = doc.root.children[0].children[0].children[0];
        expect(leaf.path, [0, 0, 0]);
        final sections = leaf.sections!;
        expect(sections, hasLength(1));
        expect(sections.first.selection.start.path, [0, 0, 0]);
        expect(sections.first.selection.end.path, [0, 0, 0]);
      },
    );

    test('manual override wins and clearing recomputes', () {
      final doc = Document(
        root: Node(type: 'page', children: [_para('Auto text.')]),
      );
      doc.sectionParser = _wholeTextParser;
      final node = doc.first!;

      // Computed first.
      expect(node.sections!.first.text, 'Auto text.');

      // Manual override wins.
      final override = Sections([
        Section(
          index: 0,
          text: 'OVERRIDE',
          selection: Selection(
            start: Position(path: node.path, offset: 0),
            end: Position(path: node.path, offset: 8),
          ),
          parent: node,
        ),
      ]);
      node.sections = override;
      expect(node.sections!.first.text, 'OVERRIDE');

      // Clearing override recomputes via parser.
      node.sections = null;
      expect(node.sections!.first.text, 'Auto text.');
    });

    test('EditorState.sectionParser delegates to Document', () {
      final doc = Document(
        root: Node(type: 'page', children: [_para('Hello.')]),
      );
      final state = EditorState(document: doc);
      addTearDown(state.dispose);

      state.sectionParser = (_) => _prefixedParser('VIA-STATE');
      expect(doc.sectionParser, isNotNull);
      expect(doc.first!.sections!.first.text, 'VIA-STATE');
    });
  });
}
