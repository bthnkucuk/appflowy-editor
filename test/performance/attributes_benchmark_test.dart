// Baseline benchmark for the `Attributes` (Map<String, dynamic>) hot paths
// — `composeAttributes`, `Node.copyWith`, `Operation` construction/toJson,
// `mapEquals`. Numbers here are the floor we compare against if/when we
// swap the backing store (e.g. to `IMap`).
//
// Run with: `fvm flutter test test/performance/attributes_benchmark_test.dart`
// Results debugPrint to stdout via testWidgets `addTearDown` debugPrint so they show
// even when the test passes silently.
//
// The benchmark does NOT assert on absolute timings — those vary by host.
// It asserts that the loop completes without errors, and prints per-op
// nanoseconds + total ms so you can eyeball wins after a migration.

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Attributes hot-path benchmark', () {
    test('composeAttributes — 100k ops', () {
      // Typical workload: merging a base (1-3 entries) with one new
      // attribute. Mimics a `toggleAttribute` or `formatDelta` call.
      final base = <String, dynamic>{'bold': true, 'italic': true};
      final patch = <String, dynamic>{'underline': true};

      // Warm up.
      for (var i = 0; i < 1000; i++) {
        composeAttributes(base, patch);
      }

      final sw = Stopwatch()..start();
      const iterations = 100000;
      for (var i = 0; i < iterations; i++) {
        composeAttributes(base, patch);
      }
      sw.stop();

      _report('composeAttributes', sw, iterations);
    });

    test('composeAttributes with null-removal — 100k ops', () {
      // Attribute unset path: a key with null value removes the entry.
      final base = <String, dynamic>{'bold': true, 'italic': true, 'href': 'https://x'};
      final patch = <String, dynamic>{'href': null};

      for (var i = 0; i < 1000; i++) {
        composeAttributes(base, patch);
      }

      final sw = Stopwatch()..start();
      const iterations = 100000;
      for (var i = 0; i < iterations; i++) {
        composeAttributes(base, patch);
      }
      sw.stop();

      _report('composeAttributes (null-removal)', sw, iterations);
    });

    test('Node.copyWith attribute spread — 50k ops', () {
      // Hot path during transaction processing: every UpdateOperation that
      // doesn't pass an explicit `attributes:` argument hits the
      // `{...this.attributes}` clone at node.dart:433.
      final node = Node(type: 'paragraph', attributes: {'delta': [], 'level': 1, 'backgroundColor': '#fff'});

      for (var i = 0; i < 500; i++) {
        node.copyWith();
      }

      final sw = Stopwatch()..start();
      const iterations = 50000;
      for (var i = 0; i < iterations; i++) {
        node.copyWith();
      }
      sw.stop();

      _report('Node.copyWith()', sw, iterations);
    });

    test('mapEquals on equal Attributes — 200k ops', () {
      // Hit on every selection-notifier check that diffs attributes.
      final a = <String, dynamic>{'bold': true, 'italic': true, 'level': 2};
      final b = <String, dynamic>{'bold': true, 'italic': true, 'level': 2};

      for (var i = 0; i < 2000; i++) {
        isAttributesEqual(a, b);
      }

      final sw = Stopwatch()..start();
      const iterations = 200000;
      for (var i = 0; i < iterations; i++) {
        isAttributesEqual(a, b);
      }
      sw.stop();

      _report('isAttributesEqual (equal maps)', sw, iterations);
    });

    test('UpdateOperation.copyWith(path) — 200k ops', () {
      // Hot path through `transformOperation` when `Transaction.add` walks
      // the existing op list. The defensive `{...attributes}` /
      // `{...oldAttributes}` clones at operation.dart copyWith showed up
      // in profiles. Mirrors the TextInsert.attributes shape.
      final op = UpdateOperation([0, 1], {'bold': true, 'italic': true, 'href': 'https://x'}, {
        'bold': null,
        'italic': null,
        'href': null,
      });

      for (var i = 0; i < 2000; i++) {
        op.copyWith(path: [i % 5, 1]);
      }

      final sw = Stopwatch()..start();
      const iterations = 200000;
      for (var i = 0; i < iterations; i++) {
        op.copyWith(path: [i % 5, 1]);
      }
      sw.stop();

      _report('UpdateOperation.copyWith(path)', sw, iterations);
    });

    test('UpdateOperation.toJson — 200k ops', () {
      final op = UpdateOperation([0, 1], {'bold': true, 'italic': true, 'href': 'https://x'}, {
        'bold': null,
        'italic': null,
        'href': null,
      });

      for (var i = 0; i < 2000; i++) {
        op.toJson();
      }

      final sw = Stopwatch()..start();
      const iterations = 200000;
      for (var i = 0; i < iterations; i++) {
        op.toJson();
      }
      sw.stop();

      _report('UpdateOperation.toJson', sw, iterations);
    });

    test('end-to-end: 1000 attribute toggles on a 20-node doc', () {
      // Closest thing to "user typing + applying bold a thousand times":
      // hits composeAttributes + transaction creation + clone in
      // UpdateOperation.
      final doc = Document.blank();
      for (var i = 0; i < 20; i++) {
        doc.insert(
          [i],
          [
            Node(type: 'paragraph', attributes: {'delta': []}),
          ],
        );
      }
      final editorState = EditorState(document: doc);

      // Warm up — 100 toggles.
      for (var i = 0; i < 100; i++) {
        final t = editorState.transaction;
        t.updateNode(doc.nodeAtPath([i % 20])!, {'bold': i.isEven});
        editorState.apply(t);
      }

      final sw = Stopwatch()..start();
      const iterations = 1000;
      for (var i = 0; i < iterations; i++) {
        final t = editorState.transaction;
        t.updateNode(doc.nodeAtPath([i % 20])!, {'bold': i.isEven});
        editorState.apply(t);
      }
      sw.stop();

      _report('end-to-end attribute toggle', sw, iterations);
    });
  });
}

void _report(String label, Stopwatch sw, int iterations) {
  final totalUs = sw.elapsedMicroseconds;
  final perOpNs = (totalUs * 1000) / iterations;

  debugPrint(
    '[BENCH] $label: '
    '${totalUs / 1000}ms total, '
    '${perOpNs.toStringAsFixed(1)}ns/op '
    '($iterations iterations)',
  );
}
