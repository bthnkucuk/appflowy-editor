import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:equatable/equatable.dart';

final class Section extends Equatable {
  const Section({
    required this.index,
    required this.text,
    required this.selection,
    required this.parent,
  });

  final int index;
  final String text;
  final Selection selection;
  final Node parent;

  int get characterCount => text.length;

  @override
  List<Object?> get props => [index, text, selection];
}

extension type const Sections(List<Section> sections) implements List<Section> {
  const Sections.empty() : sections = const [];
}

extension SectionCharacterOffsetStamping on Iterable<Section> {
  /// Pairs each section with the running prefix-sum of `characterCount`s
  /// preceding it, threaded through [builder]. Use this when a downstream
  /// consumer needs to know "how many characters precede this section in
  /// the flattened document" — typically audio playlist builders that
  /// project section position onto a time axis.
  ///
  /// Lazy: walks the input once. `builder` is called in document order.
  Iterable<T> mapWithCharacterOffsets<T>(
    T Function(Section section, int characterOffset) builder,
  ) sync* {
    var offset = 0;
    for (final section in this) {
      yield builder(section, offset);
      offset += section.characterCount;
    }
  }
}
