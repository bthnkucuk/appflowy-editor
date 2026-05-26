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
class AppFlowyEditorTranslationsHuHu extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsHuHu({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.huHu,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <hu-HU>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsHuHu _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsHuHu $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsHuHu(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'bátor';
	@override String get bulletedList => 'pontozott lista';
	@override String get checkbox => 'jelölőnégyzetet';
	@override String get embedCode => 'Beágyazás';
	@override String get heading1 => 'címsor1';
	@override String get heading2 => 'címsor2';
	@override String get heading3 => 'címsor3';
	@override String get highlight => 'Kiemel';
	@override String get image => 'kép';
	@override String get italic => 'dőlt';
	@override String get link => 'link';
	@override String get numberedList => 'számozottLista';
	@override String get quote => 'idézet';
	@override String get strikethrough => 'áthúzott';
	@override String get text => 'szöveg';
	@override String get underline => 'aláhúzás';
}
