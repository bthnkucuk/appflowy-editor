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
class AppFlowyEditorTranslationsHiIn extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsHiIn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.hiIn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <hi-IN>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsHiIn _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsHiIn $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsHiIn(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'बोल्ड';
	@override String get bulletedList => 'बुलेटेड सूची';
	@override String get checkbox => 'चेक बॉक्स';
	@override String get embedCode => 'लागु किया गया संहिता';
	@override String get heading1 => 'शीर्षक 1';
	@override String get heading2 => 'शीर्षक 2';
	@override String get heading3 => 'शीर्षक 3';
	@override String get highlight => 'प्रमुखता से दिखाना';
	@override String get image => 'छवि';
	@override String get italic => 'तिरछा';
	@override String get link => 'संपर्क';
	@override String get numberedList => 'क्रमांकित सूची';
	@override String get quote => 'उद्धरण';
	@override String get strikethrough => 'स्ट्राइकथ्रू';
	@override String get text => 'मूलपाठ';
	@override String get underline => 'रेखांकन';
}
