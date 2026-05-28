///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class AppFlowyEditorTranslationsPtBr extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsPtBr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.ptBr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <pt-BR>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsPtBr _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsPtBr $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsPtBr(meta: meta ?? this.$meta);

	// Translations
	@override String get addYourLink => 'Adicionar seu link';
	@override String get auto => 'Automático';
	@override String get backgroundColor => 'Cor de fundo';
	@override String get backgroundColorBlue => 'Fundo azul';
	@override String get backgroundColorBrown => 'Fundo marrom';
	@override String get backgroundColorDefault => 'Fundo padrão';
	@override String get backgroundColorGray => 'Fundo cinza';
	@override String get backgroundColorGreen => 'Fundo verde';
	@override String get backgroundColorOrange => 'Fundo laranja';
	@override String get backgroundColorPink => 'Fundo rosa';
	@override String get backgroundColorPurple => 'Fundo roxo';
	@override String get backgroundColorRed => 'Fundo vermelho\n';
	@override String get backgroundColorYellow => 'Fundo amarelo';
	@override String get bold => 'Negrito';
	@override String get bulletedList => 'Lista de marcadores';
	@override String get cancel => 'Cancelar';
	@override String get caseSensitive => 'Diferenciar maiúsculas';
	@override String get checkbox => 'Caixa de seleção';
	@override String get chooseImage => 'Selecionar imagem';
	@override String get clearHighlightColor => 'Limpar cor de destaque';
	@override String get closeFind => 'Fechar';
	@override String get cmdConvertToLink => 'Converter para link';
	@override String get cmdConvertToParagraph => 'converter para parágrafo';
	@override String get cmdCopySelection => 'Copiar seleção';
	@override String get cmdCutSelection => 'Cortar seleção';
	@override String get cmdDeleteLeft => 'Deletar caractere à esquerda';
	@override String get cmdDeleteLineLeft => 'Deletar até o início da linha';
	@override String get cmdDeleteRight => 'Deletar caractere à direita';
	@override String get cmdDeleteWordLeft => 'Deletar palavra à esquerda';
	@override String get cmdDeleteWordRight => 'Deletar palavra à direita';
	@override String get cmdExitEditing => 'sair do modo de edição';
	@override String get cmdIndent => 'indentar';
	@override String get cmdMoveCursorBottom => 'mover cursor para o final do arquivo';
	@override String get cmdMoveCursorBottomSelect => 'Selecionar tudo até o final do arquivo';
	@override String get cmdMoveCursorDown => 'mover cursor para baixo';
	@override String get cmdMoveCursorDownSelect => 'Selecionar para baixo';
	@override String get cmdMoveCursorLeft => 'mover cursor para a esquerda';
	@override String get cmdMoveCursorLeftSelect => 'Selecionar à esquerda';
	@override String get cmdMoveCursorLineEnd => 'mover cursor para o final da linha';
	@override String get cmdMoveCursorLineEndSelect => 'Selecionar até o final da linha';
	@override String get cmdMoveCursorLineStart => 'mover cursor para o início da linha';
	@override String get cmdMoveCursorLineStartSelect => 'Selecionar até o início da linha';
	@override String get cmdMoveCursorRight => 'mover cursor para a direita';
	@override String get cmdMoveCursorRightSelect => 'Selecionar à direita';
	@override String get cmdMoveCursorTop => 'mover cursor para o topo';
	@override String get cmdMoveCursorTopSelect => 'Selecionar tudo até o início do arquivo';
	@override String get cmdMoveCursorUp => 'mover cursor para cima';
	@override String get cmdMoveCursorUpSelect => 'Selecionar para cima';
	@override String get cmdMoveCursorWordLeft => 'mover cursor para a palavra à esquerda';
	@override String get cmdMoveCursorWordLeftSelect => 'Selecionar palavra à esquerda';
	@override String get cmdMoveCursorWordRight => 'mover cursor para a palavra à direita';
	@override String get cmdMoveCursorWordRightSelect => 'Selecionar palavra à direita';
	@override String get cmdOpenFind => 'Abrir Localizar';
	@override String get cmdOpenFindAndReplace => 'Abrir Localizar e Substituir';
	@override String get cmdOpenLink => 'abrir link';
	@override String get cmdOpenLinks => 'abrir links';
	@override String get cmdOutdent => 'desindentar';
	@override String get cmdPasteContent => 'colar conteúdo';
	@override String get cmdPasteContentAsPlainText => 'colar conteúdo como texto simples';
	@override String get cmdRedo => 'refazer';
	@override String get cmdScrollPageDown => 'rolar página para baixo';
	@override String get cmdScrollPageUp => 'rolar página para cima';
	@override String get cmdScrollToBottom => 'rolar para o fim';
	@override String get cmdScrollToTop => 'rolar para o topo';
	@override String get cmdSelectAll => 'selecionar tudo';
	@override String get cmdTableLineBreak => 'Não adicionar nova linha na célula';
	@override String get cmdTableMoveToDownCellAtSameOffset => 'Mover para a célula abaixo na mesma posição';
	@override String get cmdTableMoveToLeftCellIfItsAtStartOfCurrentCell => 'Mover para a célula à esquerda se estiver no início da célula atual';
	@override String get cmdTableMoveToRightCellIfItsAtTheEndOfCurrentCell => 'Mover para a célula à direita se estiver no final da célula atual';
	@override String get cmdTableMoveToUpCellAtSameOffset => 'Mover para a célula acima na mesma posição';
	@override String get cmdTableNavigateCells => 'Navegar pelas células na mesma posição';
	@override String get cmdTableNavigateCellsReverse => 'Navegar pelas células na mesma posição (reverso)';
	@override String get cmdTableStopAtTheBeginningOfTheCell => 'Parar no início da célula';
	@override String get cmdToggleBold => 'alternar negrito';
	@override String get cmdToggleCode => 'alternar código';
	@override String get cmdToggleHighlight => 'alternar destaque';
	@override String get cmdToggleItalic => 'alternar itálico';
	@override String get cmdToggleStrikethrough => 'alternar tachado';
	@override String get cmdToggleTodoList => 'alternar lista de tarefas';
	@override String get cmdToggleUnderline => 'alternar sublinhado';
	@override String get cmdUndo => 'desfazer';
	@override String get colAddAfter => 'Inserir à direita';
	@override String get colAddBefore => 'Inserir à esquerda';
	@override String get colClear => 'Limpar coluna';
	@override String get colDuplicate => 'Duplicar coluna';
	@override String get color => 'Cor';
	@override String get colRemove => 'Deletar coluna';
	@override String get copy => 'Copiar';
	@override String get copyLink => 'Copiar link';
	@override String get customColor => 'Cor personalizada';
	@override String get cut => 'Cortar';
	@override String get divider => 'Separador';
	@override String get done => 'Concluir';
	@override String get editLink => 'Editar link';
	@override String get embedCode => 'Código incorporado';
	@override String get emptySearchBoxHint => 'Localizar...';
	@override String get find => 'Procurar';
	@override String get fontColorBlue => 'Azul';
	@override String get fontColorBrown => 'Marrom';
	@override String get fontColorDefault => 'Padrão';
	@override String get fontColorGray => 'Cinza';
	@override String get fontColorGreen => 'Verde';
	@override String get fontColorOrange => 'Laranja';
	@override String get fontColorPink => 'Rosa';
	@override String get fontColorPurple => 'Roxo';
	@override String get fontColorRed => 'Vermelho';
	@override String get fontColorYellow => 'Amarelo';
	@override String get heading1 => 'Cabeçalho 1';
	@override String get heading2 => 'Cabeçalho 2';
	@override String get heading3 => 'Cabeçalho 3';
	@override String get hexValue => 'HEX';
	@override String get highlight => 'Destacar';
	@override String get highlightColor => 'Cor de destaque';
	@override String get image => 'Imagem';
	@override String get imageLoadFailed => 'Não foi possível carregar a imagem';
	@override String get incorrectLink => 'Link incorreto';
	@override String get italic => 'Itálico';
	@override String get lightLightTint1 => 'Roxo';
	@override String get lightLightTint2 => 'Rosa';
	@override String get lightLightTint3 => 'Rosa claro';
	@override String get lightLightTint4 => 'Laranja';
	@override String get lightLightTint5 => 'Amarelo';
	@override String get lightLightTint6 => 'Lima';
	@override String get lightLightTint7 => 'Verde';
	@override String get lightLightTint8 => 'Aqua';
	@override String get lightLightTint9 => 'Azul';
	@override String get link => 'Link';
	@override String get linkAddressHint => 'Insira a URL';
	@override String get linkText => 'Texto';
	@override String get linkTextHint => 'Insira o rótulo';
	@override String get listItemPlaceholder => 'Item de lista';
	@override String get loading => 'Carregando';
	@override String get ltr => 'Esquerda para Direita';
	@override String get mobileHeading1 => 'Cabeçalho 1';
	@override String get mobileHeading2 => 'Cabeçalho 2';
	@override String get mobileHeading3 => 'Cabeçalho 3';
	@override String get nextMatch => 'Próximo';
	@override String get noFindResult => 'Nenhum resultado encontrado';
	@override String get numberedList => 'Lista numerada';
	@override String get opacity => 'Opacidade';
	@override String get openLink => 'Abrir link';
	@override String get paste => 'Colar';
	@override String get previousMatch => 'Anterior';
	@override String get quote => 'Citação';
	@override String get regex => 'Regex';
	@override String get regexError => 'Erro de Regex';
	@override String get removeLink => 'Remover link';
	@override String get replace => 'Substituir';
	@override String get replaceAll => 'Substituir tudo';
	@override String get resetToDefaultColor => 'Redefinir para cor padrão';
	@override String get rowAddAfter => 'Inserir abaixo';
	@override String get rowAddBefore => 'Inserir acima';
	@override String get rowClear => 'Limpar linha';
	@override String get rowDuplicate => 'Duplicar linha';
	@override String get rowRemove => 'Deletar linha';
	@override String get rtl => 'Direita para Esquerda';
	@override String get slashPlaceHolder => 'Insira / para adicionar um bloco ou comece a escrever';
	@override String get strikethrough => 'Rasurar';
	@override String get table => 'Tabela';
	@override String get text => 'Texto';
	@override String get textAlignCenter => 'Alinhar ao centro';
	@override String get textAlignLeft => 'Alinhar à esquerda';
	@override String get textAlignRight => 'Alinhar à direita';
	@override String get textColor => 'Cor do texto';
	@override String get tint1 => 'Matiz 1';
	@override String get tint2 => 'Matiz 2';
	@override String get tint3 => 'Matiz 3';
	@override String get tint4 => 'Matiz 4';
	@override String get tint5 => 'Matiz 5';
	@override String get tint6 => 'Matiz 6';
	@override String get tint7 => 'Matiz 7';
	@override String get tint8 => 'Matiz 8';
	@override String get tint9 => 'Matiz 9';
	@override String get toDoPlaceholder => 'Tarefa a fazer';
	@override String get underline => 'Sublinhar';
	@override String get upload => 'Enviar';
	@override String get uploadImage => 'Enviar';
	@override String get urlHint => 'URL';
	@override String get urlImage => 'URL';
}
