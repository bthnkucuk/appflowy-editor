// Baseline + comparison benchmark for `Delta` hot paths (compose, slice,
// transform, diff). Numbers serve as the floor against which a potential
// `dart_quill_delta` adoption is judged.
//
// Run with: `fvm flutter test test/performance/delta_benchmark_test.dart`
//
// The benchmark prints per-op nanoseconds via _report. No absolute timing
// asserts (host-dependent). Asserts only that the loops complete cleanly.

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

Delta _buildMixedDelta() {
  // ~5-7 ops, mixed attributes (BIUS + href + plain) — typical paragraph.
  return Delta()
    ..insert('Hello ', attributes: {'bold': true})
    ..insert('world', attributes: {'italic': true, 'underline': true})
    ..insert(', this is a ')
    ..insert('link', attributes: {'href': 'https://example.com'})
    ..insert(' and some ')
    ..insert('strikethrough', attributes: {'strikethrough': true})
    ..insert(' tail.');
}

Delta _buildLongDelta(int runs) {
  // 100-char-ish delta with `runs` mixed attribute runs.
  final d = Delta();
  for (var i = 0; i < runs; i++) {
    d.insert(
      'chunk_${i.toString().padLeft(2, '0')}_',
      attributes: {
        if (i.isEven) 'bold': true,
        if (i % 3 == 0) 'italic': true,
        if (i % 4 == 0) 'href': 'https://x.example/$i',
      },
    );
  }
  return d;
}

Delta _retainBoldChange() {
  // Typical "format selection bold" patch: retain 6, retain 5 bold.
  return Delta()
    ..retain(6)
    ..retain(5, attributes: {'bold': true});
}

void main() {
  group('Delta hot-path benchmark — current AppFlowy impl', () {
    test('Delta.compose — base vs format-bold patch — 50k ops', () {
      final base = _buildMixedDelta();
      final patch = _retainBoldChange();

      for (var i = 0; i < 1000; i++) {
        base.compose(patch);
      }

      final sw = Stopwatch()..start();
      const iterations = 50000;
      for (var i = 0; i < iterations; i++) {
        base.compose(patch);
      }
      sw.stop();

      _report('Delta.compose (mixed + bold patch)', sw, iterations);
    });

    test('Delta.slice(start,end) — 5-run delta — 100k ops', () {
      final d = _buildLongDelta(5);

      for (var i = 0; i < 1000; i++) {
        d.slice(10, 60);
      }

      final sw = Stopwatch()..start();
      const iterations = 100000;
      for (var i = 0; i < iterations; i++) {
        d.slice(10, 60);
      }
      sw.stop();

      _report('Delta.slice(10,60) (5 runs)', sw, iterations);
    });

    test(
      'Delta.slice(i-1, i+1) — appflowy sliceAttributes hot path — 100k ops',
      () {
        // Mimics how `appflowyEditorSliceAttributes` calls slice twice per
        // index — this is the hot path during selection toggles.
        final d = _buildMixedDelta();

        for (var i = 0; i < 1000; i++) {
          d.slice(5, 6);
          d.slice(4, 5);
        }

        final sw = Stopwatch()..start();
        const iterations = 100000;
        for (var i = 0; i < iterations; i++) {
          d.slice(5, 6);
          d.slice(4, 5);
        }
        sw.stop();

        _report('Delta.slice(short) x2 (appflowy slice-attrs)', sw, iterations);
      },
    );

    test('Delta.diff — small change — 5k ops', () {
      // diff_match_patch is the most expensive method by far. Lower iter
      // count to keep total < ~3s.
      final a = Delta()..insert('The quick brown fox jumps over the lazy dog.');
      final b = Delta()..insert('The quick brown cat jumps over the lazy dog.');

      for (var i = 0; i < 100; i++) {
        a.diff(b);
      }

      final sw = Stopwatch()..start();
      const iterations = 5000;
      for (var i = 0; i < iterations; i++) {
        a.diff(b);
      }
      sw.stop();

      _report('Delta.diff (1-word change)', sw, iterations);
    });

    test('Delta.invert — small change — 50k ops', () {
      final base = _buildMixedDelta();
      // Patch: retain 6, insert 'X', delete 5.
      final patch = Delta()
        ..retain(6)
        ..insert('X')
        ..delete(5);
      final composed = base.compose(patch);
      // invert applies to composed against base.
      for (var i = 0; i < 500; i++) {
        patch.invert(base);
      }

      final sw = Stopwatch()..start();
      const iterations = 50000;
      for (var i = 0; i < iterations; i++) {
        patch.invert(base);
      }
      sw.stop();

      // ignore: unused_local_variable
      final _ = composed; // keep ref to suppress unused warning
      _report('Delta.invert (small patch)', sw, iterations);
    });

    test('Delta.fromJson + toJson roundtrip — 50k ops', () {
      final json = _buildMixedDelta().toJson();

      for (var i = 0; i < 500; i++) {
        Delta.fromJson(json).toJson();
      }

      final sw = Stopwatch()..start();
      const iterations = 50000;
      for (var i = 0; i < iterations; i++) {
        Delta.fromJson(json).toJson();
      }
      sw.stop();

      _report('Delta fromJson+toJson', sw, iterations);
    });
  });
}

void _report(String label, Stopwatch sw, int iterations) {
  final totalUs = sw.elapsedMicroseconds;
  final perOpNs = (totalUs * 1000) / iterations;
  // ignore: avoid_print
  print(
    '[BENCH] $label: '
    '${totalUs / 1000}ms total, '
    '${perOpNs.toStringAsFixed(1)}ns/op '
    '($iterations iterations)',
  );
}
