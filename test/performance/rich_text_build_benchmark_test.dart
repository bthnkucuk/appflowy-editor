// Microbenchmark for `AppFlowyRichText.getTextSpan` per-iteration text-style
// construction. The production path in `appflowy_rich_text.dart:553` does:
//   for (final textInsert in textInserts) {
//     TextStyle textStyle = textStyleConfiguration.text.copyWith(
//       height: textStyleConfiguration.lineHeight,
//     );
//     ...
//   }
// `textStyleConfiguration.text` and `.lineHeight` are invariant across the
// loop, so the `copyWith` can be hoisted. This bench measures the win on a
// realistic mixed-attribute span (5-7 inserts).
//
// Run with:
//   fvm flutter test test/performance/rich_text_build_benchmark_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simulated lightweight "TextInsert" — text + attributes flags. We don't
// depend on the editor library here; we're measuring the TextStyle path.
class _Insert {
  const _Insert(this.text, {this.bold = false, this.italic = false});
  final String text;
  final bool bold;
  final bool italic;
}

class _Cfg {
  const _Cfg({required this.text, required this.lineHeight, required this.bold, required this.italic});
  final TextStyle text;
  final double lineHeight;
  final TextStyle bold;
  final TextStyle italic;
}

const _cfg = _Cfg(
  text: TextStyle(fontSize: 16, color: Colors.black),
  lineHeight: 1.5,
  bold: TextStyle(fontWeight: FontWeight.bold),
  italic: TextStyle(fontStyle: FontStyle.italic),
);

final _inserts = <_Insert>[
  const _Insert('Hello '),
  const _Insert('world', bold: true),
  const _Insert(', this is a '),
  const _Insert('link', italic: true),
  const _Insert(' and tail '),
  const _Insert('end', bold: true, italic: true),
];

// Mirror of current production path: copyWith inside loop.
TextSpan _buildCurrent(_Cfg cfg, List<_Insert> inserts) {
  final spans = <InlineSpan>[];
  for (final insert in inserts) {
    TextStyle style = cfg.text.copyWith(height: cfg.lineHeight);
    if (insert.bold) style = style.merge(cfg.bold);
    if (insert.italic) style = style.merge(cfg.italic);
    spans.add(TextSpan(text: insert.text, style: style));
  }
  return TextSpan(children: spans);
}

// Hoisted: copyWith once per build, then `final` and reused.
TextSpan _buildHoisted(_Cfg cfg, List<_Insert> inserts) {
  final base = cfg.text.copyWith(height: cfg.lineHeight);
  final spans = <InlineSpan>[];
  for (final insert in inserts) {
    TextStyle style = base;
    if (insert.bold) style = style.merge(cfg.bold);
    if (insert.italic) style = style.merge(cfg.italic);
    spans.add(TextSpan(text: insert.text, style: style));
  }
  return TextSpan(children: spans);
}

void main() {
  group('Rich-text getTextSpan benchmark', () {
    test('current (copyWith per insert) — 50k builds, 6 inserts each', () {
      for (var i = 0; i < 500; i++) {
        _buildCurrent(_cfg, _inserts);
      }
      final sw = Stopwatch()..start();
      const iterations = 50000;
      for (var i = 0; i < iterations; i++) {
        _buildCurrent(_cfg, _inserts);
      }
      sw.stop();
      _report('getTextSpan current', sw, iterations);
    });

    test('hoisted (copyWith once) — 50k builds, 6 inserts each', () {
      for (var i = 0; i < 500; i++) {
        _buildHoisted(_cfg, _inserts);
      }
      final sw = Stopwatch()..start();
      const iterations = 50000;
      for (var i = 0; i < iterations; i++) {
        _buildHoisted(_cfg, _inserts);
      }
      sw.stop();
      _report('getTextSpan hoisted', sw, iterations);
    });

    test('correctness — both yield equivalent spans', () {
      final a = _buildCurrent(_cfg, _inserts);
      final b = _buildHoisted(_cfg, _inserts);
      expect(a.children!.length, b.children!.length);
      for (var i = 0; i < a.children!.length; i++) {
        final ac = a.children![i] as TextSpan;
        final bc = b.children![i] as TextSpan;
        expect(ac.text, bc.text);
        expect(ac.style, bc.style);
      }
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
