/// AppFlowyEditor block components.
///
/// Built-in block component builders, configurations, and helpers:
/// paragraph, heading, todo, bulleted/numbered list, quote, divider,
/// image, table, plus the base-component mixins and selection
/// containers used to build custom blocks.
///
/// Pairs with `core.dart` (document model) and the main editor entry
/// point (`appflowy_editor.dart`). Import this when you're authoring
/// custom block components and want the public block primitives without
/// the rest of the editor surface:
///
/// ```dart
/// import 'package:appflowy_editor/blocks.dart';
/// ```
library;

export 'src/editor/block_component/block_component.dart';
export 'src/editor/block_component/standard_block_components.dart';
export 'src/editor/block_component/table_block_component/table.dart';
export 'src/editor/block_component/rich_text/appflowy_rich_text.dart';
export 'src/editor/block_component/rich_text/appflowy_rich_text_keys.dart';
export 'src/editor/block_component/rich_text/default_selectable_mixin.dart';
