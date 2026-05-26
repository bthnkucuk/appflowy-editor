/// AppFlowyEditor core data model.
///
/// Pure document/selection types: `Document`, `Node`, `Path`, `Position`,
/// `Selection`, `Attributes`, `Transaction`, `Operation`, document rules,
/// and node iteration. No Flutter widgets or platform imports.
///
/// Import this entry point when you only need to read/write document state
/// without pulling the editor UI surface:
///
/// ```dart
/// import 'package:appflowy_editor/core.dart';
/// ```
library;

export 'src/core/core.dart';
