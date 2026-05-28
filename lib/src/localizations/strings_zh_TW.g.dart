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
class AppFlowyEditorTranslationsZhTw extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsZhTw({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.zhTw,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <zh-TW>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsZhTw _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsZhTw $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsZhTw(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => '粗體';
	@override String get bulletedList => '無序列表';
	@override String get checkbox => '核取方塊';
	@override String get embedCode => '代碼塊';
	@override String get heading1 => '一級標題';
	@override String get heading2 => '二級標題';
	@override String get heading3 => '三級標題';
	@override String get highlight => '高亮';
	@override String get color => '顏色';
	@override String get image => '圖片';
	@override String get italic => '斜體';
	@override String get link => '連結';
	@override String get numberedList => '有序列表';
	@override String get quote => '引文';
	@override String get strikethrough => '刪除線';
	@override String get text => '文本';
	@override String get underline => '下劃線';
	@override String get fontColorDefault => '預設';
	@override String get fontColorGray => '灰色';
	@override String get fontColorBrown => '棕色';
	@override String get fontColorOrange => '橙色';
	@override String get fontColorYellow => '黃色';
	@override String get fontColorGreen => '綠色';
	@override String get fontColorBlue => '藍色';
	@override String get fontColorPurple => '紫色';
	@override String get fontColorPink => '粉紅色';
	@override String get fontColorRed => '紅色';
	@override String get backgroundColorDefault => '預設背景色';
	@override String get backgroundColorGray => '灰色背景';
	@override String get backgroundColorBrown => '棕色背景';
	@override String get backgroundColorOrange => '橙色背景';
	@override String get backgroundColorYellow => '黃色背景';
	@override String get backgroundColorGreen => '綠色背景';
	@override String get backgroundColorBlue => '藍色背景';
	@override String get backgroundColorPurple => '紫色背景';
	@override String get backgroundColorPink => '粉色背景';
	@override String get backgroundColorRed => '紅色背景';
	@override String get done => '完成';
	@override String get cancel => '取消';
	@override String get tint1 => '色調1';
	@override String get tint2 => '色調2';
	@override String get tint3 => '色調3';
	@override String get tint4 => '色調4';
	@override String get tint5 => '色調5';
	@override String get tint6 => '色調6';
	@override String get tint7 => '色調7';
	@override String get tint8 => '色調8';
	@override String get tint9 => '色調9';
	@override String get lightLightTint1 => '紫色';
	@override String get lightLightTint2 => '粉紅色';
	@override String get lightLightTint3 => '淺粉紅色';
	@override String get lightLightTint4 => '橙色';
	@override String get lightLightTint5 => '黃色';
	@override String get lightLightTint6 => '草綠色';
	@override String get lightLightTint7 => '綠色';
	@override String get lightLightTint8 => '水藍色';
	@override String get lightLightTint9 => '藍色';
	@override String get urlHint => 'URL';
	@override String get mobileHeading1 => '一級標題';
	@override String get mobileHeading2 => '二級標題';
	@override String get mobileHeading3 => '三級標題';
	@override String get textColor => '文字顏色';
	@override String get backgroundColor => '背景顏色';
	@override String get addYourLink => '添加連結';
	@override String get openLink => '打開連結';
	@override String get copyLink => '複製連結';
	@override String get removeLink => '移除連結';
	@override String get editLink => '修改連結';
	@override String get linkText => '文字';
	@override String get linkTextHint => '請輸入文字';
	@override String get linkAddressHint => '請輸入URL';
	@override String get highlightColor => '高亮顏色';
	@override String get clearHighlightColor => '清除高亮顏色';
	@override String get customColor => '自定義顏色';
	@override String get hexValue => '十六進位值';
	@override String get opacity => '透明度';
	@override String get resetToDefaultColor => '重設為預設顏色';
	@override String get ltr => '自左至右';
	@override String get rtl => '自右至左';
	@override String get auto => '自動';
	@override String get cut => '剪下';
	@override String get copy => '複製';
	@override String get paste => '貼上';
	@override String get find => '尋找';
	@override String get previousMatch => '上一相符項';
	@override String get nextMatch => '下一相符項';
	@override String get closeFind => '關閉';
	@override String get replace => '取代';
	@override String get replaceAll => '取代全部';
	@override String get regex => '正規表示式';
	@override String get caseSensitive => '區分大小寫';
	@override String get regexError => '正規錯誤';
	@override String get noFindResult => '無相符項';
	@override String get emptySearchBoxHint => '鍵入尋找内容';
	@override String get uploadImage => '上載圖片';
	@override String get urlImage => '網路圖片';
	@override String get incorrectLink => '連結錯誤';
	@override String get upload => '上載';
	@override String get chooseImage => '選取圖像檔案';
	@override String get loading => '正在載入';
	@override String get imageLoadFailed => '無法載入圖像';
	@override String get divider => '分割線';
	@override String get table => '表格';
	@override String get colAddBefore => '左側插入行';
	@override String get rowAddBefore => '上方插入列';
	@override String get colAddAfter => '右側插入行';
	@override String get rowAddAfter => '下方插入列';
	@override String get colRemove => '刪除整行';
	@override String get rowRemove => '刪除整列';
	@override String get colDuplicate => '複製整行';
	@override String get rowDuplicate => '複製整列';
	@override String get colClear => '清空整行';
	@override String get rowClear => '清空整列';
	@override String get slashPlaceHolder => '輸入 / 以插入内容，或開始鍵入';
	@override String get textAlignLeft => '靠左對齊';
	@override String get textAlignCenter => '置中對齊';
	@override String get textAlignRight => '靠右對齊';
}
