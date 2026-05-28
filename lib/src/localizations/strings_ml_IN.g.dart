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
class AppFlowyEditorTranslationsMlIn extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsMlIn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.mlIn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <ml-IN>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsMlIn _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsMlIn $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsMlIn(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'ബോൾഡ്';
	@override String get bulletedList => 'ബുള്ളറ്റഡ് പട്ടിക';
	@override String get checkbox => 'ചെക്ക്ബോക്സ്';
	@override String get embedCode => 'എംബെഡഡ് കോഡ്';
	@override String get heading1 => 'തലക്കെട്ട് 1';
	@override String get heading2 => 'തലക്കെട്ട് 2';
	@override String get heading3 => 'തലക്കെട്ട് 3';
	@override String get highlight => 'പ്രമുഖമാക്കിക്കാട്ടുക';
	@override String get image => 'ചിത്രം';
	@override String get italic => 'ഇറ്റാലിക്';
	@override String get link => 'ലിങ്ക്';
	@override String get numberedList => 'അക്കമിട്ട പട്ടിക';
	@override String get quote => 'ഉദ്ധരണി';
	@override String get strikethrough => 'സ്ട്രൈക്ക്ത്രൂ';
	@override String get text => 'വചനം';
	@override String get underline => 'അടിവരയിടുക';
}
