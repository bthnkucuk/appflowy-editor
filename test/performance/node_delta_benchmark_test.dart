// Baseline for `Node.delta` getter. Each call reconstructs a `Delta` tree
// from `attributes['delta']` JSON. Audit (194 call sites, zero in-place
// mutation of the underlying list) suggests the result can be cached on
// the Node and invalidated when `_attributes` is replaced.
//
// Run with:
//   fvm flutter test --concurrency=1 test/performance/node_delta_benchmark_test.dart

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Node.delta hot-path benchmark', () {
    test('repeated .delta access on same Node — 100k ops', () {
      final node = Node(
        type: 'paragraph',
        attributes: {
          'delta': [
            {'insert': 'Hello '},
            {
              'insert': 'world',
              'attributes': {'bold': true},
            },
            {'insert': ', this is a '},
            {
              'insert': 'link',
              'attributes': {'href': 'https://example.com'},
            },
            {'insert': ' and some '},
            {
              'insert': 'strikethrough',
              'attributes': {'strikethrough': true},
            },
            {'insert': ' tail.'},
          ],
        },
      );

      // Warm up.
      for (var i = 0; i < 2000; i++) {
        // ignore: unused_local_variable
        final d = node.delta;
      }

      final sw = Stopwatch()..start();
      const iters = 100000;
      for (var i = 0; i < iters; i++) {
        // ignore: unused_local_variable
        final d = node.delta;
      }
      sw.stop();
      _report('node.delta (repeat, cache-friendly)', sw, iters);
    });

    test('.delta access across many nodes — 50k iters × 20 nodes', () {
      // Mimics walking a document — each node is hit once per pass.
      final nodes = List.generate(
        20,
        (i) => Node(
          type: 'paragraph',
          attributes: {
            'delta': [
              {'insert': 'node $i header'},
              {
                'insert': ' bold $i',
                'attributes': {'bold': true},
              },
              {'insert': ' tail'},
            ],
          },
        ),
      );

      for (var i = 0; i < 500; i++) {
        for (final n in nodes) {
          // ignore: unused_local_variable
          final d = n.delta;
        }
      }

      final sw = Stopwatch()..start();
      const iters = 50000;
      for (var i = 0; i < iters; i++) {
        for (final n in nodes) {
          // ignore: unused_local_variable
          final d = n.delta;
        }
      }
      sw.stop();
      _report('node.delta across 20 nodes', sw, iters);
    });

    test('.delta then updateAttributes invalidate cycle — 20k iters', () {
      // Worst-case for a cache: every iteration mutates attributes, so the
      // cache invalidates and must rebuild. Tests that the cache logic
      // itself doesn't add overhead in the no-hit case.
      final node = Node(
        type: 'paragraph',
        attributes: {
          'delta': [
            {'insert': 'baseline'},
          ],
        },
      );

      for (var i = 0; i < 1000; i++) {
        // ignore: unused_local_variable
        final d = node.delta;
        node.updateAttributes({
          'delta': [
            {'insert': 'iter $i'},
          ],
        });
      }

      final sw = Stopwatch()..start();
      const iters = 20000;
      for (var i = 0; i < iters; i++) {
        // ignore: unused_local_variable
        final d = node.delta;
        node.updateAttributes({
          'delta': [
            {'insert': 'iter $i'},
          ],
        });
      }
      sw.stop();
      _report('node.delta after each updateAttributes', sw, iters);
    });
  });
}

void _report(String label, Stopwatch sw, int iters) {
  final perOpNs = (sw.elapsedMicroseconds * 1000) / iters;
  // ignore: avoid_print
  print(
    '[BENCH] $label: ${sw.elapsedMicroseconds / 1000}ms total, '
    '${perOpNs.toStringAsFixed(1)}ns/op',
  );
}
