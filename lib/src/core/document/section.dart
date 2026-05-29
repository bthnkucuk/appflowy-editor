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
