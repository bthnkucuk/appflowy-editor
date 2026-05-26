// Baseline benchmark for `Path` navigation hot paths. Each call currently
// allocates a `List<int>` clone via `Path.from(this, growable: true)`.
// Call audit (45 sites across 20 files) shows zero mutation of the returned
// Path, so the defensive clone may be eliminable. Numbers here are the
// floor we compare against if we change `path.dart` to return tighter
// allocations.
//
// Run with:
//   fvm flutter test --concurrency=1 test/performance/path_benchmark_test.dart

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Path navigation hot-path benchmark', () {
    test('Path.next on 3-element path — 500k ops', () {
      final p = <int>[3, 7, 2];
      for (var i = 0; i < 5000; i++) {
        // ignore: unused_local_variable
        final r = p.next;
      }
      final sw = Stopwatch()..start();
      const iters = 500000;
      for (var i = 0; i < iters; i++) {
        // ignore: unused_local_variable
        final r = p.next;
      }
      sw.stop();
      _report('Path.next (len=3)', sw, iters);
    });

    test('Path.parent on 5-element path — 500k ops', () {
      final p = <int>[3, 7, 2, 0, 1];
      for (var i = 0; i < 5000; i++) {
        // ignore: unused_local_variable
        final r = p.parent;
      }
      final sw = Stopwatch()..start();
      const iters = 500000;
      for (var i = 0; i < iters; i++) {
        // ignore: unused_local_variable
        final r = p.parent;
      }
      sw.stop();
      _report('Path.parent (len=5)', sw, iters);
    });

    test('Path.child on 3-element path — 500k ops', () {
      final p = <int>[3, 7, 2];
      for (var i = 0; i < 5000; i++) {
        // ignore: unused_local_variable
        final r = p.child(4);
      }
      final sw = Stopwatch()..start();
      const iters = 500000;
      for (var i = 0; i < iters; i++) {
        // ignore: unused_local_variable
        final r = p.child(4);
      }
      sw.stop();
      _report('Path.child (len=3+1)', sw, iters);
    });

    test('Path.previous on 3-element path — 500k ops', () {
      final p = <int>[3, 7, 2];
      for (var i = 0; i < 5000; i++) {
        // ignore: unused_local_variable
        final r = p.previous;
      }
      final sw = Stopwatch()..start();
      const iters = 500000;
      for (var i = 0; i < iters; i++) {
        // ignore: unused_local_variable
        final r = p.previous;
      }
      sw.stop();
      _report('Path.previous (len=3)', sw, iters);
    });

    test('Path.equals (equal) — 1M ops', () {
      final a = <int>[3, 7, 2];
      final b = <int>[3, 7, 2];
      for (var i = 0; i < 5000; i++) {
        a.equals(b);
      }
      final sw = Stopwatch()..start();
      const iters = 1000000;
      for (var i = 0; i < iters; i++) {
        a.equals(b);
      }
      sw.stop();
      _report('Path.equals (equal)', sw, iters);
    });

    test('Document traversal: walk 100 nodes, get parent at each — 10k iters', () {
      // Realistic workload — tree walk where each visit asks for `.parent`.
      final paths = List<List<int>>.generate(
        100,
        (i) => [i ~/ 10, i % 10, i % 3],
      );
      for (var i = 0; i < 50; i++) {
        for (final p in paths) {
          // ignore: unused_local_variable
          final parent = p.parent;
        }
      }
      final sw = Stopwatch()..start();
      const iters = 10000;
      for (var i = 0; i < iters; i++) {
        for (final p in paths) {
          // ignore: unused_local_variable
          final parent = p.parent;
        }
      }
      sw.stop();
      _report('walk 100 nodes × .parent', sw, iters);
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
