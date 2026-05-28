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
class AppFlowyEditorTranslationsPtPt extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsPtPt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.ptPt,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <pt-PT>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsPtPt _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsPtPt $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsPtPt(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'negrito';
	@override String get bulletedList => 'lista com marcadores';
	@override String get checkbox => 'caixa de seleção';
	@override String get embedCode => 'Código embutido';
	@override String get heading1 => 'Cabeçalho 1';
	@override String get heading2 => 'Cabeçalho 2';
	@override String get heading3 => 'Cabeçalho 3';
	@override String get highlight => 'realçar';
	@override String get image => 'imagem';
	@override String get italic => 'itálico';
	@override String get link => 'link';
	@override String get numberedList => 'lista numerada';
	@override String get quote => 'citar';
	@override String get strikethrough => 'tachado';
	@override String get text => 'texto';
	@override String get underline => 'sublinhado';
	@override String get ltr => 'Esquerda para Direita';
	@override String get rtl => 'Direita para Esquerda';
	@override String get auto => 'Automático';
	@override String get highlightColor => 'Cor de destaque';
	@override String get textColor => 'Cor do texto';
	@override String get textAlignLeft => 'Alinhar à esquerda';
	@override String get textAlignCenter => 'Alinhar ao centro';
	@override String get textAlignRight => 'Alinhar à direita';
}
