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
class AppFlowyEditorTranslationsNlNl extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsNlNl({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.nlNl,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <nl-NL>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsNlNl _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsNlNl $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsNlNl(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'Vet';
	@override String get bulletedList => 'Opsommingstekens';
	@override String get checkbox => 'Selectievakje';
	@override String get embedCode => 'Invoegcode';
	@override String get heading1 => 'H1';
	@override String get heading2 => 'H2';
	@override String get heading3 => 'H3';
	@override String get highlight => 'Highlight';
	@override String get image => 'Afbeelding';
	@override String get italic => 'Cursief';
	@override String get link => '';
	@override String get numberedList => 'Nummering';
	@override String get quote => 'Quote';
	@override String get strikethrough => 'Doorhalen';
	@override String get text => 'Tekst';
	@override String get underline => 'Onderstrepen';
}
