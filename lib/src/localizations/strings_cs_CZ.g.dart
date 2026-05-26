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
class AppFlowyEditorTranslationsCsCz extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsCsCz({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.csCz,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <cs-CZ>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsCsCz _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsCsCz $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsCsCz(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'Tučně';
	@override String get bulletedList => 'Odrážkový seznam';
	@override String get checkbox => 'Zaškrtávací políčko';
	@override String get embedCode => 'Vložit kód';
	@override String get heading1 => 'Nadpis 1';
	@override String get heading2 => 'Nadpis 2';
	@override String get heading3 => 'Nadpis 3';
	@override String get highlight => 'Zvýraznění';
	@override String get image => 'Obrázek';
	@override String get italic => 'Kurzíva';
	@override String get link => 'Odkaz';
	@override String get numberedList => 'Číslovaný seznam';
	@override String get quote => 'Citace';
	@override String get strikethrough => 'Přeškrtnutí';
	@override String get text => 'Text';
	@override String get underline => 'Podtržení';
}
