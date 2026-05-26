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
class AppFlowyEditorTranslationsIdId extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsIdId({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.idId,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <id-ID>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsIdId _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsIdId $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsIdId(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'berani';
	@override String get bulletedList => 'daftar berpoin';
	@override String get checkbox => 'kotak centang';
	@override String get embedCode => 'menyematkan Kode';
	@override String get heading1 => 'pos1';
	@override String get heading2 => 'pos2';
	@override String get heading3 => 'pos3';
	@override String get highlight => 'menyorot';
	@override String get image => 'gambar';
	@override String get italic => 'miring';
	@override String get link => 'tautan';
	@override String get numberedList => 'daftar bernomor';
	@override String get quote => 'mengutip';
	@override String get strikethrough => 'coret';
	@override String get text => 'teks';
	@override String get underline => 'menggarisbawahi';
}
