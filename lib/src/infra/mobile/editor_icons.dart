import 'package:flutter/material.dart';
import 'package:iconifyx_ph/iconifyx_ph.dart';

enum ToolbarIcons {
  textDecorationBold,
  bold,
  italic,
  underline,
  strikethrough,
  code,
  color,
  link,
  heading,
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  list,
  bulletedList,
  numberedList,
  checkbox,
  quote,
  divider,
  close,
  // text/paragraph
  text,
  // colors
  textColor,
  highlightColor,
  // alignment (legacy short names: left/center/right)
  alignLeft,
  alignCenter,
  alignRight,
  // text direction
  textDirectionAuto,
  textDirectionLtr,
  textDirectionRtl,
  // link menu actions
  copy,
  delete,
  // misc
  clear,
  checkmark,
  check,
  uncheck,
  upload,
  regex,
  caseSensitive,
  // history
  undo,
  redo,
  // selection menu items
  selectionMenuImage,
  // color picker reset/clear actions
  resetTextColor,
  clearHighlightColor,
  // padding/quote/text/h1/h2/h3/bulletedList/numberedList/checkbox already covered above
}

const Map<ToolbarIcons, IconifyIconData> _phMap = {
  ToolbarIcons.textDecorationBold: PhIcons.textAa,
  ToolbarIcons.bold: PhIcons.textB,
  ToolbarIcons.italic: PhIcons.textItalicBold,
  ToolbarIcons.underline: PhIcons.textUnderline,
  ToolbarIcons.strikethrough: PhIcons.textStrikethrough,
  ToolbarIcons.code: PhIcons.code,
  ToolbarIcons.color: PhIcons.palette,
  ToolbarIcons.link: PhIcons.link,
  ToolbarIcons.heading: PhIcons.textH,
  ToolbarIcons.h1: PhIcons.textHOne,
  ToolbarIcons.h2: PhIcons.textHTwo,
  ToolbarIcons.h3: PhIcons.textHThree,
  ToolbarIcons.h4: PhIcons.textHFour,
  ToolbarIcons.h5: PhIcons.textHFive,
  ToolbarIcons.h6: PhIcons.textHSix,
  ToolbarIcons.list: PhIcons.list,
  ToolbarIcons.bulletedList: PhIcons.listBullets,
  ToolbarIcons.numberedList: PhIcons.listNumbers,
  ToolbarIcons.checkbox: PhIcons.checkSquare,
  ToolbarIcons.quote: PhIcons.quotes,
  ToolbarIcons.divider: PhIcons.minus,
  ToolbarIcons.close: PhIcons.x,
  // text/paragraph
  ToolbarIcons.text: PhIcons.textT,
  // colors
  ToolbarIcons.textColor: PhIcons.textAa,
  ToolbarIcons.highlightColor: PhIcons.paintBrush,
  // alignment
  ToolbarIcons.alignLeft: PhIcons.textAlignLeft,
  ToolbarIcons.alignCenter: PhIcons.textAlignCenter,
  ToolbarIcons.alignRight: PhIcons.textAlignRight,
  // text direction
  /// No phosphor "auto" direction icon — using magicWand as a best-guess fit.
  // TODO(icons): better match
  ToolbarIcons.textDirectionAuto: PhIcons.magicWand,
  ToolbarIcons.textDirectionLtr: PhIcons.arrowLineRight,
  ToolbarIcons.textDirectionRtl: PhIcons.arrowLineLeft,
  // link menu actions
  ToolbarIcons.copy: PhIcons.copy,
  ToolbarIcons.delete: PhIcons.trash,
  // misc
  ToolbarIcons.clear: PhIcons.xCircle,
  ToolbarIcons.checkmark: PhIcons.check,
  ToolbarIcons.check: PhIcons.checkSquare,
  ToolbarIcons.uncheck: PhIcons.square,
  ToolbarIcons.upload: PhIcons.uploadSimple,
  // history
  ToolbarIcons.undo: PhIcons.arrowCounterClockwise,
  ToolbarIcons.redo: PhIcons.arrowClockwise,

  /// No exact "regex" icon — `code` is the closest semantic.
  // TODO(icons): better match
  ToolbarIcons.regex: PhIcons.code,

  /// No exact "case sensitive" icon — using textAa as a best-guess fit.
  // TODO(icons): better match
  ToolbarIcons.caseSensitive: PhIcons.textAa,
  // selection menu specific
  ToolbarIcons.selectionMenuImage: PhIcons.image,
  // color picker reset/clear actions — closest phosphor equivalents
  ToolbarIcons.resetTextColor: PhIcons.arrowCounterClockwise,
  ToolbarIcons.clearHighlightColor: PhIcons.xCircle,
};

class ToolbarIcon extends StatelessWidget {
  const ToolbarIcon({
    super.key,
    required this.afMobileIcons,
    this.size = 24,
    this.color,
  });

  final ToolbarIcons afMobileIcons;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconifyIcon(_phMap[afMobileIcons]!, size: size, color: color);
  }
}
