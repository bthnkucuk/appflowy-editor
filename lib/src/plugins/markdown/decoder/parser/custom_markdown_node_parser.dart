import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:markdown/markdown.dart' as md;

abstract class CustomMarkdownParser {
  const CustomMarkdownParser();

  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  });

  /// Optional hint of HTML tags this parser can handle. When non-null, the
  /// decoder skips this parser for elements whose tag isn't in the set —
  /// avoiding the per-parser `is md.Element` + tag-equality check. Return
  /// `null` (default) to opt out and be tried against every node.
  Set<String>? get supportedTags => null;
}
