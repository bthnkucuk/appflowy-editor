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
class AppFlowyEditorTranslationsFrCa extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsFrCa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.frCa,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <fr-CA>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsFrCa _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsFrCa $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsFrCa(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'gras';
	@override String get bulletedList => 'liste à puces';
	@override String get checkbox => 'case à cocher';
	@override String get embedCode => 'incorporer Code';
	@override String get heading1 => 'en-tête1';
	@override String get heading2 => 'en-tête2';
	@override String get heading3 => 'en-tête3';
	@override String get highlight => 'mettre en évidence';
	@override String get image => 'l’image';
	@override String get italic => 'italique';
	@override String get link => 'lien';
	@override String get numberedList => 'liste numérotée';
	@override String get quote => 'citation';
	@override String get strikethrough => 'barré';
	@override String get text => 'texte';
	@override String get underline => 'souligner';
}
