// Microbenchmarks for render-layer micro-optimization candidates.
//
// Targets the "view / render / selection / listener" surface area:
// - List<Rect> equality used to gate selection-area repaints
//   (`block_selection_area.dart`, `block_highlight_area.dart`,
//   `selection_area_painter.dart`)
// - Per-build text-style construction in `appflowy_rich_text.dart`
//
// The benchmark prints per-op nanoseconds via _report. No absolute timing
// asserts (host-dependent). Each test runs warm-up first.
//
// Run with:
//   fvm flutter test test/performance/render_layer_benchmark_test.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Stand-in for BlockSelectionType — keeps this benchmark independent of
// any editor import and matches the shape (a small enum).
enum BSType { cursor, selection, highlight, block }

void main() {
  group('Render-layer rect-equality benchmark', () {
    // Typical selection-area workload: 1-3 rects per block, all elements
    // compare equal in steady state (selection didn't move).
    final shortA = <Rect>[const Rect.fromLTWH(0, 0, 100, 20), const Rect.fromLTWH(0, 20, 80, 20)];
    final shortB = <Rect>[const Rect.fromLTWH(0, 0, 100, 20), const Rect.fromLTWH(0, 20, 80, 20)];

    final longA = List<Rect>.generate(20, (i) => Rect.fromLTWH(i * 10.0, i * 5.0, 100, 20));
    final longB = List<Rect>.generate(20, (i) => Rect.fromLTWH(i * 10.0, i * 5.0, 100, 20));

    test('DeepCollectionEquality — equal 2-element List<Rect> — 500k ops', () {
      const eq = DeepCollectionEquality();
      // warm
      for (var i = 0; i < 5000; i++) {
        eq.equals(shortA, shortB);
      }
      final sw = Stopwatch()..start();
      const iterations = 500000;
      for (var i = 0; i < iterations; i++) {
        eq.equals(shortA, shortB);
      }
      sw.stop();
      _report('DeepCollectionEquality (2-rect equal)', sw, iterations);
    });

    test('manual list-of-Rect equality — equal 2-element List<Rect> — 500k ops', () {
      // warm
      for (var i = 0; i < 5000; i++) {
        _rectListEq(shortA, shortB);
      }
      final sw = Stopwatch()..start();
      const iterations = 500000;
      for (var i = 0; i < iterations; i++) {
        _rectListEq(shortA, shortB);
      }
      sw.stop();
      _report('manual rect-list eq (2-rect equal)', sw, iterations);
    });

    test('DeepCollectionEquality — equal 20-element List<Rect> — 200k ops', () {
      const eq = DeepCollectionEquality();
      for (var i = 0; i < 2000; i++) {
        eq.equals(longA, longB);
      }
      final sw = Stopwatch()..start();
      const iterations = 200000;
      for (var i = 0; i < iterations; i++) {
        eq.equals(longA, longB);
      }
      sw.stop();
      _report('DeepCollectionEquality (20-rect equal)', sw, iterations);
    });

    test('manual list-of-Rect equality — equal 20-element List<Rect> — 200k ops', () {
      for (var i = 0; i < 2000; i++) {
        _rectListEq(longA, longB);
      }
      final sw = Stopwatch()..start();
      const iterations = 200000;
      for (var i = 0; i < iterations; i++) {
        _rectListEq(longA, longB);
      }
      sw.stop();
      _report('manual rect-list eq (20-rect equal)', sw, iterations);
    });

    test('DeepCollectionEquality — first-element-differs 2-rect — 500k ops', () {
      const eq = DeepCollectionEquality();
      final shortC = <Rect>[const Rect.fromLTWH(1, 0, 100, 20), const Rect.fromLTWH(0, 20, 80, 20)];
      for (var i = 0; i < 5000; i++) {
        eq.equals(shortA, shortC);
      }
      final sw = Stopwatch()..start();
      const iterations = 500000;
      for (var i = 0; i < iterations; i++) {
        eq.equals(shortA, shortC);
      }
      sw.stop();
      _report('DeepCollectionEquality (2-rect diff)', sw, iterations);
    });

    test('manual rect-list eq — first-element-differs 2-rect — 500k ops', () {
      final shortC = <Rect>[const Rect.fromLTWH(1, 0, 100, 20), const Rect.fromLTWH(0, 20, 80, 20)];
      for (var i = 0; i < 5000; i++) {
        _rectListEq(shortA, shortC);
      }
      final sw = Stopwatch()..start();
      const iterations = 500000;
      for (var i = 0; i < iterations; i++) {
        _rectListEq(shortA, shortC);
      }
      sw.stop();
      _report('manual rect-list eq (2-rect diff)', sw, iterations);
    });

    test('ValueKey suffix — supportTypes.toString() per build vs cached', () {
      // Mirrors `block_selection_area.dart` ValueKey construction:
      //   ValueKey(node.id + supportTypes.toString())
      // `supportTypes` is a const `List<BlockSelectionType>`; `.toString()`
      // walks the list and constructs a new String each call.
      const supportTypes = [BSType.cursor, BSType.selection];
      const nodeId = 'abc123-deadbeef-uuidv4';

      for (var i = 0; i < 5000; i++) {
        // ignore: unused_local_variable
        final k = ValueKey<String>(nodeId + supportTypes.toString());
      }
      final sw1 = Stopwatch()..start();
      const iter = 500000;
      for (var i = 0; i < iter; i++) {
        // ignore: unused_local_variable
        final k = ValueKey<String>(nodeId + supportTypes.toString());
      }
      sw1.stop();
      _report('ValueKey current (toString per build)', sw1, iter);

      final suffix = supportTypes.toString();
      for (var i = 0; i < 5000; i++) {
        // ignore: unused_local_variable
        final k = ValueKey<String>(nodeId + suffix);
      }
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < iter; i++) {
        // ignore: unused_local_variable
        final k = ValueKey<String>(nodeId + suffix);
      }
      sw2.stop();
      _report('ValueKey cached suffix', sw2, iter);
    });

    test('correctness — manual eq matches DeepCollectionEquality on rects', () {
      const eq = DeepCollectionEquality();
      expect(_rectListEq(shortA, shortB), eq.equals(shortA, shortB));
      expect(_rectListEq(shortA, null), eq.equals(shortA, null));
      expect(_rectListEq(null, null), eq.equals(null, null));
      expect(_rectListEq(longA, shortB), eq.equals(longA, shortB));
      final diff = <Rect>[
        const Rect.fromLTWH(0, 0, 100, 20),
        const Rect.fromLTWH(0, 21, 80, 20), // top differs
      ];
      expect(_rectListEq(shortA, diff), eq.equals(shortA, diff));
      expect(_rectListEq(<Rect>[], <Rect>[]), eq.equals(<Rect>[], <Rect>[]));
    });
  });
}

// Mirror of the helper we'll inline into the production sites: same null
// semantics as `DeepCollectionEquality.equals` for List<Rect> (Rect has
// value equality + `hashCode` already).
bool _rectListEq(List<Rect>? a, List<Rect>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  final n = a.length;
  if (b.length != n) return false;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
