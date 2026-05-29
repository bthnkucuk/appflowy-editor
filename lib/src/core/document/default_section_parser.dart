import 'package:appflowy_editor/appflowy_editor.dart';

/// Unicode-aware sentence boundary. Matches after Western (`.!?…‽`),
/// Spanish (`¡¿`), Arabic (`؟`), Urdu (`۔`), Devanagari (`।॥`), Armenian
/// (`։`), CJK (`。！？`), Latin doubled (`⸘⸮`) terminators followed by
/// optional whitespace and a uppercase / title / opening / digit letter,
/// or any character in common non-cased scripts (CJK, Thai, Hebrew,
/// Arabic, Devanagari, Bengali) where the cased classes don't apply.
final RegExp _sentenceEnd = RegExp(
  r'(?<=[.!?…‽¡¿؟۔।॥։。！？⸘⸮])\s*(?=[\p{Lu}\p{Lt}\p{Pi}\p{Ps}\p{Nd}]|[一-鿿぀-ヿ가-힯฀-๿֐-׿؀-ۿऀ-ॿঀ-৿])',
  unicode: true,
);

/// A drop-in [Node.sectionParser] that splits a node's plain text into
/// sentence-sized [Section]s. Sentence boundaries beyond [soft]
/// characters trigger a split as soon as one is found; if none lands in
/// `[soft, hard]`, the text is hard-cut at [hard].
///
/// [soft] and [hard] are required because reasonable values are
/// document- and consumer-specific (a book reader uses larger windows
/// than a quick-glance TTS demo). Install via:
///
/// ```dart
/// Node.sectionParser = (node) =>
///     defaultSentenceSectionParser(node, soft: 200, hard: 800);
/// ```
///
/// Returns `null` for nodes whose `delta` is `null` or whose plain text
/// is empty.
Sections? defaultSentenceSectionParser(
  Node node, {
  required int soft,
  required int hard,
}) {
  final paragraph = node.delta?.toPlainText();
  if (paragraph == null) return null;

  final parts = _splitSubtexts(paragraph, soft: soft, hard: hard);
  if (parts.isEmpty) return null;

  var startOffset = 0;
  final result = <Section>[];
  for (var index = 0; index < parts.length; index++) {
    final text = parts[index];
    result.add(
      Section(
        index: index,
        text: text,
        selection: Selection(
          start: Position(path: node.path, offset: startOffset),
          end: Position(path: node.path, offset: startOffset + text.length),
        ),
        parent: node,
      ),
    );
    startOffset += text.length;
  }
  return Sections(result);
}

List<String> _splitSubtexts(String text, {required int soft, required int hard}) {
  if (text.isEmpty) return const [];
  final parts = <String>[];
  var cursor = 0;
  while (cursor < text.length) {
    if (cursor + soft >= text.length) {
      parts.add(text.substring(cursor));
      break;
    }
    final searchEnd = (cursor + hard).clamp(0, text.length);
    final window = text.substring(cursor + soft, searchEnd);
    final m = _sentenceEnd.firstMatch(window);
    final cut = m != null ? cursor + soft + m.end : searchEnd;
    parts.add(text.substring(cursor, cut));
    cursor = cut;
  }
  return parts;
}
