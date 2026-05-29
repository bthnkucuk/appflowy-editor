@Tags(['benchmark'])
library;

import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

// Drop large `.md` files into `test/plugins/markdown/fixtures/` and re-run
// to compare before/after timings of `markdownToDocument`.
//
//     flutter test --tags benchmark test/plugins/markdown/markdown_benchmark_test.dart
//
// Tagged so it's skipped by default `flutter test` runs.

const int _warmupIters = 2;
const int _measureIters = 10;

void main() {
  final fixturesDir = Directory('test/plugins/markdown/fixtures');

  test('markdownToDocument benchmark', () {
    if (!fixturesDir.existsSync()) {
      debugPrint('No fixtures dir at ${fixturesDir.path}, skipping.');
      return;
    }

    final files = fixturesDir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.md')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      debugPrint('No .md fixtures found in ${fixturesDir.path}.');
      return;
    }

    debugPrint(
      '\nmarkdownToDocument benchmark (warmup=$_warmupIters, '
      'measure=$_measureIters)',
    );

    debugPrint('=' * 78);

    debugPrint(
      '${'file'.padRight(40)} ${'size'.padLeft(8)} '
      '${'min'.padLeft(8)} ${'avg'.padLeft(8)} ${'max'.padLeft(8)} '
      '${'nodes'.padLeft(8)}',
    );

    debugPrint('-' * 78);

    for (final file in files) {
      final content = file.readAsStringSync();
      final sizeKb = (content.length / 1024).toStringAsFixed(1);
      final name = file.uri.pathSegments.last;

      // Warmup.
      Document? lastDoc;
      for (var i = 0; i < _warmupIters; i++) {
        lastDoc = markdownToDocument(content);
      }

      // Measure.
      var minUs = -1;
      var maxUs = -1;
      var totalUs = 0;
      for (var i = 0; i < _measureIters; i++) {
        final sw = Stopwatch()..start();
        lastDoc = markdownToDocument(content);
        sw.stop();
        final us = sw.elapsedMicroseconds;
        totalUs += us;
        if (minUs < 0 || us < minUs) minUs = us;
        if (us > maxUs) maxUs = us;
      }
      final avgUs = totalUs ~/ _measureIters;

      final nodeCount = lastDoc!.root.children.length;

      debugPrint(
        '${name.padRight(40)} ${'${sizeKb}K'.padLeft(8)} '
        '${_fmtMs(minUs).padLeft(8)} '
        '${_fmtMs(avgUs).padLeft(8)} '
        '${_fmtMs(maxUs).padLeft(8)} '
        '${nodeCount.toString().padLeft(8)}',
      );
    }

    debugPrint('=' * 78);
  });
}

String _fmtMs(int us) => '${(us / 1000).toStringAsFixed(2)}ms';
