/// Generated file. Do not edit.
///
/// Source: assets/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 23
/// Strings: 947 (41 per locale)
///
/// Built on 2026-05-26 at 20:02 UTC

// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

import 'strings_bn_BN.g.dart' deferred as l_bn_BN;
import 'strings_ca.g.dart' deferred as l_ca;
import 'strings_cs_CZ.g.dart' deferred as l_cs_CZ;
import 'strings_da.g.dart' deferred as l_da;
import 'strings_de_DE.g.dart' deferred as l_de_DE;
import 'strings_es_VE.g.dart' deferred as l_es_VE;
import 'strings_fr_CA.g.dart' deferred as l_fr_CA;
import 'strings_fr_FR.g.dart' deferred as l_fr_FR;
import 'strings_hi_IN.g.dart' deferred as l_hi_IN;
import 'strings_hu_HU.g.dart' deferred as l_hu_HU;
import 'strings_id_ID.g.dart' deferred as l_id_ID;
import 'strings_it_IT.g.dart' deferred as l_it_IT;
import 'strings_ja_JP.g.dart' deferred as l_ja_JP;
import 'strings_ml_IN.g.dart' deferred as l_ml_IN;
import 'strings_nl_NL.g.dart' deferred as l_nl_NL;
import 'strings_pl_PL.g.dart' deferred as l_pl_PL;
import 'strings_pt_BR.g.dart' deferred as l_pt_BR;
import 'strings_pt_PT.g.dart' deferred as l_pt_PT;
import 'strings_ru_RU.g.dart' deferred as l_ru_RU;
import 'strings_tr_TR.g.dart' deferred as l_tr_TR;
import 'strings_zh_CN.g.dart' deferred as l_zh_CN;
import 'strings_zh_TW.g.dart' deferred as l_zh_TW;
part 'strings_en.g.dart';

/// Supported locales.
///
/// Usage:
/// - LocaleSettings.setLocale(AppFlowyEditorLocale.en) // set locale
/// - Locale locale = AppFlowyEditorLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppFlowyEditorLocale.en) // locale check
enum AppFlowyEditorLocale with BaseAppLocale<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	en(languageCode: 'en'),
	bnBn(languageCode: 'bn', countryCode: 'BN'),
	ca(languageCode: 'ca'),
	csCz(languageCode: 'cs', countryCode: 'CZ'),
	da(languageCode: 'da'),
	deDe(languageCode: 'de', countryCode: 'DE'),
	esVe(languageCode: 'es', countryCode: 'VE'),
	frCa(languageCode: 'fr', countryCode: 'CA'),
	frFr(languageCode: 'fr', countryCode: 'FR'),
	hiIn(languageCode: 'hi', countryCode: 'IN'),
	huHu(languageCode: 'hu', countryCode: 'HU'),
	idId(languageCode: 'id', countryCode: 'ID'),
	itIt(languageCode: 'it', countryCode: 'IT'),
	jaJp(languageCode: 'ja', countryCode: 'JP'),
	mlIn(languageCode: 'ml', countryCode: 'IN'),
	nlNl(languageCode: 'nl', countryCode: 'NL'),
	plPl(languageCode: 'pl', countryCode: 'PL'),
	ptBr(languageCode: 'pt', countryCode: 'BR'),
	ptPt(languageCode: 'pt', countryCode: 'PT'),
	ruRu(languageCode: 'ru', countryCode: 'RU'),
	trTr(languageCode: 'tr', countryCode: 'TR'),
	zhCn(languageCode: 'zh', countryCode: 'CN'),
	zhTw(languageCode: 'zh', countryCode: 'TW');

	const AppFlowyEditorLocale({
		required this.languageCode,
		this.scriptCode, // ignore: unused_element, unused_element_parameter
		this.countryCode, // ignore: unused_element, unused_element_parameter
	});

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;

	@override
	Future<AppFlowyEditorTranslations> build({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) async {
		switch (this) {
			case AppFlowyEditorLocale.en:
				return AppFlowyEditorTranslationsEn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.bnBn:
				await l_bn_BN.loadLibrary();
				return l_bn_BN.AppFlowyEditorTranslationsBnBn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ca:
				await l_ca.loadLibrary();
				return l_ca.AppFlowyEditorTranslationsCa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.csCz:
				await l_cs_CZ.loadLibrary();
				return l_cs_CZ.AppFlowyEditorTranslationsCsCz(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.da:
				await l_da.loadLibrary();
				return l_da.AppFlowyEditorTranslationsDa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.deDe:
				await l_de_DE.loadLibrary();
				return l_de_DE.AppFlowyEditorTranslationsDeDe(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.esVe:
				await l_es_VE.loadLibrary();
				return l_es_VE.AppFlowyEditorTranslationsEsVe(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.frCa:
				await l_fr_CA.loadLibrary();
				return l_fr_CA.AppFlowyEditorTranslationsFrCa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.frFr:
				await l_fr_FR.loadLibrary();
				return l_fr_FR.AppFlowyEditorTranslationsFrFr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.hiIn:
				await l_hi_IN.loadLibrary();
				return l_hi_IN.AppFlowyEditorTranslationsHiIn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.huHu:
				await l_hu_HU.loadLibrary();
				return l_hu_HU.AppFlowyEditorTranslationsHuHu(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.idId:
				await l_id_ID.loadLibrary();
				return l_id_ID.AppFlowyEditorTranslationsIdId(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.itIt:
				await l_it_IT.loadLibrary();
				return l_it_IT.AppFlowyEditorTranslationsItIt(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.jaJp:
				await l_ja_JP.loadLibrary();
				return l_ja_JP.AppFlowyEditorTranslationsJaJp(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.mlIn:
				await l_ml_IN.loadLibrary();
				return l_ml_IN.AppFlowyEditorTranslationsMlIn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.nlNl:
				await l_nl_NL.loadLibrary();
				return l_nl_NL.AppFlowyEditorTranslationsNlNl(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.plPl:
				await l_pl_PL.loadLibrary();
				return l_pl_PL.AppFlowyEditorTranslationsPlPl(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ptBr:
				await l_pt_BR.loadLibrary();
				return l_pt_BR.AppFlowyEditorTranslationsPtBr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ptPt:
				await l_pt_PT.loadLibrary();
				return l_pt_PT.AppFlowyEditorTranslationsPtPt(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ruRu:
				await l_ru_RU.loadLibrary();
				return l_ru_RU.AppFlowyEditorTranslationsRuRu(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.trTr:
				await l_tr_TR.loadLibrary();
				return l_tr_TR.AppFlowyEditorTranslationsTrTr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.zhCn:
				await l_zh_CN.loadLibrary();
				return l_zh_CN.AppFlowyEditorTranslationsZhCn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.zhTw:
				await l_zh_TW.loadLibrary();
				return l_zh_TW.AppFlowyEditorTranslationsZhTw(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
		}
	}

	@override
	AppFlowyEditorTranslations buildSync({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) {
		switch (this) {
			case AppFlowyEditorLocale.en:
				return AppFlowyEditorTranslationsEn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.bnBn:
				return l_bn_BN.AppFlowyEditorTranslationsBnBn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ca:
				return l_ca.AppFlowyEditorTranslationsCa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.csCz:
				return l_cs_CZ.AppFlowyEditorTranslationsCsCz(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.da:
				return l_da.AppFlowyEditorTranslationsDa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.deDe:
				return l_de_DE.AppFlowyEditorTranslationsDeDe(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.esVe:
				return l_es_VE.AppFlowyEditorTranslationsEsVe(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.frCa:
				return l_fr_CA.AppFlowyEditorTranslationsFrCa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.frFr:
				return l_fr_FR.AppFlowyEditorTranslationsFrFr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.hiIn:
				return l_hi_IN.AppFlowyEditorTranslationsHiIn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.huHu:
				return l_hu_HU.AppFlowyEditorTranslationsHuHu(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.idId:
				return l_id_ID.AppFlowyEditorTranslationsIdId(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.itIt:
				return l_it_IT.AppFlowyEditorTranslationsItIt(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.jaJp:
				return l_ja_JP.AppFlowyEditorTranslationsJaJp(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.mlIn:
				return l_ml_IN.AppFlowyEditorTranslationsMlIn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.nlNl:
				return l_nl_NL.AppFlowyEditorTranslationsNlNl(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.plPl:
				return l_pl_PL.AppFlowyEditorTranslationsPlPl(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ptBr:
				return l_pt_BR.AppFlowyEditorTranslationsPtBr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ptPt:
				return l_pt_PT.AppFlowyEditorTranslationsPtPt(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.ruRu:
				return l_ru_RU.AppFlowyEditorTranslationsRuRu(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.trTr:
				return l_tr_TR.AppFlowyEditorTranslationsTrTr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.zhCn:
				return l_zh_CN.AppFlowyEditorTranslationsZhCn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppFlowyEditorLocale.zhTw:
				return l_zh_TW.AppFlowyEditorTranslationsZhTw(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
		}
	}

	/// Gets current instance managed by [LocaleSettings].
	AppFlowyEditorTranslations get translations => LocaleSettings.instance.getTranslations(this);
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of aft).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = aft.someKey.anotherKey;
AppFlowyEditorTranslations get aft => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final aft = AppFlowyEditorTranslations.of(context); // Get aft variable.
/// String a = aft.someKey.anotherKey; // Use aft variable.
class TranslationProvider extends BaseTranslationProvider<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppFlowyEditorLocale, AppFlowyEditorTranslations> of(BuildContext context) => InheritedLocaleData.of<AppFlowyEditorLocale, AppFlowyEditorTranslations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.aft.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	AppFlowyEditorTranslations get aft => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	LocaleSettings._() : super(
		utils: AppLocaleUtils.instance,
		lazy: true,
	);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppFlowyEditorLocale get currentLocale => instance.currentLocale;
	static Stream<AppFlowyEditorLocale> getLocaleStream() => instance.getLocaleStream();
	static Future<AppFlowyEditorLocale> setLocale(AppFlowyEditorLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static Future<AppFlowyEditorLocale> setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static Future<AppFlowyEditorLocale> useDeviceLocale() => instance.useDeviceLocale();
	static Future<void> setPluralResolver({String? language, AppFlowyEditorLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);

	// synchronous versions
	static AppFlowyEditorLocale setLocaleSync(AppFlowyEditorLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocaleSync(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppFlowyEditorLocale setLocaleRawSync(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRawSync(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppFlowyEditorLocale useDeviceLocaleSync() => instance.useDeviceLocaleSync();
	static void setPluralResolverSync({String? language, AppFlowyEditorLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolverSync(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	AppLocaleUtils._() : super(
		baseLocale: AppFlowyEditorLocale.en,
		locales: AppFlowyEditorLocale.values,
	);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppFlowyEditorLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppFlowyEditorLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppFlowyEditorLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}
