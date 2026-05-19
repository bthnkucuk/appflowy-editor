import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:equatable/equatable.dart' show Equatable;

class TableOfContent extends Equatable {
  final String text;
  final int level;
  final Selection selection;

  const TableOfContent({
    required this.text,
    required this.level,
    required this.selection,
  });

  TableOfContent copyWith({String? text, int? level, Selection? selection}) {
    return TableOfContent(
      text: text ?? this.text,
      level: level ?? this.level,
      selection: selection ?? this.selection,
    );
  }

  @override
  List<Object?> get props => [text, level, selection];
}
