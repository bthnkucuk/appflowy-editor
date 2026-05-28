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
class AppFlowyEditorTranslationsZhCn extends AppFlowyEditorTranslations with BaseTranslations<AppFlowyEditorLocale, AppFlowyEditorTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppFlowyEditorLocale.build] is preferred.
	AppFlowyEditorTranslationsZhCn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppFlowyEditorLocale.zhCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <zh-CN>.
	@override final TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations> $meta;

	late final AppFlowyEditorTranslationsZhCn _root = this; // ignore: unused_field

	@override 
	AppFlowyEditorTranslationsZhCn $copyWith({TranslationMetadata<AppFlowyEditorLocale, AppFlowyEditorTranslations>? meta}) => AppFlowyEditorTranslationsZhCn(meta: meta ?? this.$meta);

	// Translations
	@override String get bold => '粗体';
	@override String get bulletedList => '无序列表';
	@override String get checkbox => '复选框';
	@override String get embedCode => '代码块';
	@override String get heading1 => '一级标题';
	@override String get heading2 => '二级标题';
	@override String get heading3 => '三级标题';
	@override String get highlight => '高亮';
	@override String get color => '颜色';
	@override String get image => '图片';
	@override String get italic => '斜体';
	@override String get link => '链接';
	@override String get numberedList => '有序列表';
	@override String get quote => '引文';
	@override String get strikethrough => '删除线';
	@override String get text => '文本';
	@override String get underline => '下划线';
	@override String get fontColorDefault => '默认';
	@override String get fontColorGray => '灰色';
	@override String get fontColorBrown => '棕色';
	@override String get fontColorOrange => '橙色';
	@override String get fontColorYellow => '黄色';
	@override String get fontColorGreen => '绿色';
	@override String get fontColorBlue => '蓝色';
	@override String get fontColorPurple => '紫色';
	@override String get fontColorPink => '粉红色';
	@override String get fontColorRed => '红色';
	@override String get backgroundColorDefault => '默认背景色';
	@override String get backgroundColorGray => '灰色背景';
	@override String get backgroundColorBrown => '棕色背景';
	@override String get backgroundColorOrange => '橙色背景';
	@override String get backgroundColorYellow => '黄色背景';
	@override String get backgroundColorGreen => '绿色背景';
	@override String get backgroundColorBlue => '蓝色背景';
	@override String get backgroundColorPurple => '紫色背景';
	@override String get backgroundColorPink => '粉色背景';
	@override String get backgroundColorRed => '红色背景';
	@override String get done => '完成';
	@override String get cancel => '取消';
	@override String get tint1 => '色调1';
	@override String get tint2 => '色调2';
	@override String get tint3 => '色调3';
	@override String get tint4 => '色调4';
	@override String get tint5 => '色调5';
	@override String get tint6 => '色调6';
	@override String get tint7 => '色调7';
	@override String get tint8 => '色调8';
	@override String get tint9 => '色调9';
	@override String get lightLightTint1 => '紫色';
	@override String get lightLightTint2 => '粉红色';
	@override String get lightLightTint3 => '浅粉红色';
	@override String get lightLightTint4 => '橙色';
	@override String get lightLightTint5 => '黄色';
	@override String get lightLightTint6 => '草绿色';
	@override String get lightLightTint7 => '绿色';
	@override String get lightLightTint8 => '水蓝色';
	@override String get lightLightTint9 => '蓝色';
	@override String get urlHint => 'URL';
	@override String get mobileHeading1 => '一级标题';
	@override String get mobileHeading2 => '二级标题';
	@override String get mobileHeading3 => '三级标题';
	@override String get textColor => '文字颜色';
	@override String get backgroundColor => '背景颜色';
	@override String get addYourLink => '添加链接';
	@override String get openLink => '打开链接';
	@override String get copyLink => '复制链接';
	@override String get removeLink => '移除链接';
	@override String get editLink => '修改链接';
	@override String get linkText => '文字';
	@override String get linkTextHint => '请输入文字';
	@override String get linkAddressHint => '请输入URL';
	@override String get highlightColor => '高亮颜色';
	@override String get clearHighlightColor => '清除高亮颜色';
	@override String get customColor => '自定义颜色';
	@override String get hexValue => '十六进制值';
	@override String get opacity => '透明度';
	@override String get resetToDefaultColor => '重设为默认颜色';
	@override String get ltr => '自左至右';
	@override String get rtl => '自右至左';
	@override String get auto => '自动';
	@override String get cut => '剪切';
	@override String get copy => '复制';
	@override String get paste => '粘贴';
	@override String get find => '查找';
	@override String get previousMatch => '上一匹配项';
	@override String get nextMatch => '下一匹配项';
	@override String get closeFind => '关闭';
	@override String get replace => '替换';
	@override String get replaceAll => '替换全部';
	@override String get regex => '正则表达式';
	@override String get caseSensitive => '区分大小写';
	@override String get regexError => '正则错误';
	@override String get noFindResult => '无匹配项';
	@override String get emptySearchBoxHint => '输入查找内容';
	@override String get uploadImage => '上传图片';
	@override String get urlImage => '网络图片';
	@override String get incorrectLink => '链接错误';
	@override String get upload => '上传';
	@override String get chooseImage => '选择图片文件';
	@override String get loading => '正在加载';
	@override String get imageLoadFailed => '无法加载图片';
	@override String get divider => '分割线';
	@override String get table => '表格';
	@override String get colAddBefore => '左侧插入列';
	@override String get rowAddBefore => '上方插入行';
	@override String get colAddAfter => '右侧插入列';
	@override String get rowAddAfter => '下方插入行';
	@override String get colRemove => '删除整列';
	@override String get rowRemove => '删除整行';
	@override String get colDuplicate => '复制整列';
	@override String get rowDuplicate => '复制整行';
	@override String get colClear => '清空整列';
	@override String get rowClear => '清空整行';
	@override String get slashPlaceHolder => '单击 / 以插入内容，或开始输入';
	@override String get textAlignLeft => '靠左对齐';
	@override String get textAlignCenter => '居中对齐';
	@override String get textAlignRight => '靠右对齐';
}
