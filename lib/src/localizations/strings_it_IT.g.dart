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
class AppFlowyEditorTranslationsItIt extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsItIt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.itIt,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <it-IT>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsItIt _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsItIt $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsItIt(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'Grassetto';
	@override String get bulletedList => 'Elenco puntato';
	@override String get checkbox => 'Casella di spunta';
	@override String get embedCode => 'Incorpora codice';
	@override String get heading1 => 'H1';
	@override String get heading2 => 'H2';
	@override String get heading3 => 'H3';
	@override String get highlight => 'Evidenzia';
	@override String get image => 'Immagine';
	@override String get italic => 'Corsivo';
	@override String get link => 'Collegamento';
	@override String get numberedList => 'Elenco numerato';
	@override String get quote => 'Cita';
	@override String get strikethrough => 'Barrato';
	@override String get text => 'Testo';
	@override String get underline => 'Sottolineato';
}
