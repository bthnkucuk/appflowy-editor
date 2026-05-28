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
class AppFlowyEditorTranslationsFrFr extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsFrFr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.frFr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <fr-FR>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsFrFr _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsFrFr $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsFrFr(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'Gras';
	@override String get bulletedList => 'List à puces';
	@override String get checkbox => 'Case à cocher';
	@override String get embedCode => 'Incorporer code';
	@override String get heading1 => 'Titre 1';
	@override String get heading2 => 'Titre 2';
	@override String get heading3 => 'Titre 3';
	@override String get highlight => 'Surligné';
	@override String get image => 'Image';
	@override String get italic => 'Italique';
	@override String get link => 'Lien';
	@override String get numberedList => 'Liste numérotée';
	@override String get quote => 'Citation';
	@override String get strikethrough => 'Barré';
	@override String get text => 'Texte';
	@override String get underline => 'Souligné';
}
