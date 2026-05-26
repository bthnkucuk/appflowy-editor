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
class AppFlowyEditorTranslationsBnBn extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsBnBn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.bnBn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <bn-BN>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsBnBn _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsBnBn $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsBnBn(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'বল্ড ফন্ট';
	@override String get bulletedList => 'বুলেট তালিকা';
	@override String get checkbox => 'চেকবক্স';
	@override String get embedCode => 'এম্বেড কোড';
	@override String get heading1 => 'শিরোনাম 1';
	@override String get heading2 => 'শিরোনাম 2';
	@override String get heading3 => 'শিরোনাম 3';
	@override String get highlight => 'হাইলাইট';
	@override String get image => 'ইমেজ';
	@override String get italic => 'ইটালিক ফন্ট';
	@override String get link => 'লিঙ্ক';
	@override String get numberedList => 'সংখ্যাযুক্ত তালিকা';
	@override String get quote => 'উদ্ধৃতি';
	@override String get strikethrough => 'স্ট্রাইকথ্রু';
	@override String get text => 'পাঠ্য';
	@override String get underline => 'আন্ডারলাইন';
}
