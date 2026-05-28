/// AppFlowyEditor encoder/decoder plugins.
///
/// Document <-> external format conversions: Markdown, HTML, Quill delta,
/// PDF, plus the word-counter service. Also exposes the bundled
/// `columns` block component (lives under `plugins/blocks/` for legacy
/// layout reasons).
///
/// Import this entry point when you need encoding/decoding without the
/// full editor surface:
///
/// ```dart
/// import 'package:appflowy_editor/plugins.dart';
/// ```
library;

export 'src/plugins/plugins.dart';
