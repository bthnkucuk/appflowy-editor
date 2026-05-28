/// Typed view over the string keys used inside a rich-text delta's
/// attribute map (`bold` / `italic` / `underline` / …). The
/// representation is still a plain `String` — `implements String` keeps
/// every existing call site that passes the key to `Map<String, …>` or
/// compares against `'bold'` / etc. compiling unchanged — but mistakes
/// like `attributes['italics']` (typo) or `attributes[SomeOtherKeys.x]`
/// (wrong key family) become catchable at compile time when call sites
/// type their keys as [RichTextAttrKey].
///
/// Pre-7.0 these lived as **mutable** static String fields on
/// [AppFlowyRichTextKeys] (`static String bold = 'bold'`), which let
/// anyone reassign them at runtime — a foot-gun that mostly stayed
/// dormant only because nobody happened to do it. The const
/// [RichTextAttrKey] instances below close that hole while keeping the
/// same access shape (`AppFlowyRichTextKeys.bold`).
extension type const RichTextAttrKey(String value) implements String {}

class AppFlowyRichTextKeys {
  const AppFlowyRichTextKeys._();

  static const RichTextAttrKey bold = RichTextAttrKey('bold');
  static const RichTextAttrKey italic = RichTextAttrKey('italic');
  static const RichTextAttrKey underline = RichTextAttrKey('underline');
  static const RichTextAttrKey strikethrough = RichTextAttrKey('strikethrough');
  static const RichTextAttrKey textColor = RichTextAttrKey('font_color');
  static const RichTextAttrKey backgroundColor = RichTextAttrKey('bg_color');
  static const RichTextAttrKey findBackgroundColor =
      RichTextAttrKey('find_bg_color');
  static const RichTextAttrKey code = RichTextAttrKey('code');
  static const RichTextAttrKey href = RichTextAttrKey('href');
  static const RichTextAttrKey fontFamily = RichTextAttrKey('font_family');
  static const RichTextAttrKey fontSize = RichTextAttrKey('font_size');
  static const RichTextAttrKey autoComplete = RichTextAttrKey('auto_complete');
  static const RichTextAttrKey transparent = RichTextAttrKey('transparent');

  /// The attributes supported sliced.
  static const List<RichTextAttrKey> supportSliced = [
    bold,
    italic,
    underline,
    strikethrough,
    textColor,
    backgroundColor,
    code,
  ];

  /// The attributes is partially supported sliced.
  ///
  /// For the code and href attributes, the slice attributes function will
  /// only work if the index is in the range of the code or href.
  static const List<RichTextAttrKey> partialSliced = [code, href];

  /// The values supported toggled even if the selection is collapsed.
  static const List<RichTextAttrKey> supportToggled = [
    bold,
    italic,
    underline,
    strikethrough,
    code,
    fontFamily,
    textColor,
    backgroundColor,
  ];
}
