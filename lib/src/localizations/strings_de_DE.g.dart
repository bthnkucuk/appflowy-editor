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
class AppFlowyEditorTranslationsDeDe extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsDeDe({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.deDe,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <de-DE>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsDeDe _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsDeDe $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsDeDe(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => 'Fett gedruckt';
	@override String get bulletedList => 'Aufzählungsliste';
	@override String get checkbox => 'Kontrollkästchen';
	@override String get embedCode => 'Code einbetten';
	@override String get heading1 => 'Überschrift 1';
	@override String get heading2 => 'Überschrift 2';
	@override String get heading3 => 'Überschrift 3';
	@override String get highlight => 'Markieren';
	@override String get image => 'Bild';
	@override String get italic => 'kursiv';
	@override String get link => 'Verknüpfung';
	@override String get numberedList => 'NummerierteListe';
	@override String get quote => 'zitieren';
	@override String get strikethrough => 'durchgestrichen';
	@override String get text => 'Text';
	@override String get underline => 'unterstreichen';
}
