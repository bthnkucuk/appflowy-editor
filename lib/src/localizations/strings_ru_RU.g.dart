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
class AppFlowyEditorTranslationsRuRu extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsRuRu({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.ruRu,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <ru-RU>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsRuRu _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsRuRu $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsRuRu(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'смелый';
	@override String get bulletedList => 'маркированный список';
	@override String get checkbox => 'флажок';
	@override String get embedCode => 'код для вставки';
	@override String get heading1 => 'заголовок1';
	@override String get heading2 => 'заголовок2';
	@override String get heading3 => 'заголовок3';
	@override String get highlight => 'выделять';
	@override String get image => 'изображение';
	@override String get italic => 'курсив';
	@override String get link => 'ссылка на сайт';
	@override String get numberedList => 'нумерованный список';
	@override String get quote => 'цитировать';
	@override String get strikethrough => 'зачеркнутый';
	@override String get text => 'текст';
	@override String get underline => 'подчеркнуть';
}
