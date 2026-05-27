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
  // misc utility entries (extras sheet, statistics, etc.)
  more,
  stats,
  export,
  outline,
  appearance,
  font,
}

/// Phosphor's "regular" weight — the default look for toolbar buttons in
/// their idle state.
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
  ToolbarIcons.text: PhIcons.textT,
  ToolbarIcons.textColor: PhIcons.textAa,
  ToolbarIcons.highlightColor: PhIcons.paintBrush,
  ToolbarIcons.alignLeft: PhIcons.textAlignLeft,
  ToolbarIcons.alignCenter: PhIcons.textAlignCenter,
  ToolbarIcons.alignRight: PhIcons.textAlignRight,

  /// No phosphor "auto" direction icon — using magicWand as a best-guess fit.
  // TODO(icons): better match
  ToolbarIcons.textDirectionAuto: PhIcons.magicWand,
  ToolbarIcons.textDirectionLtr: PhIcons.arrowLineRight,
  ToolbarIcons.textDirectionRtl: PhIcons.arrowLineLeft,
  ToolbarIcons.copy: PhIcons.copy,
  ToolbarIcons.delete: PhIcons.trash,
  ToolbarIcons.clear: PhIcons.xCircle,
  ToolbarIcons.checkmark: PhIcons.check,
  ToolbarIcons.check: PhIcons.checkSquare,
  ToolbarIcons.uncheck: PhIcons.square,
  ToolbarIcons.upload: PhIcons.uploadSimple,
  ToolbarIcons.undo: PhIcons.arrowCounterClockwise,
  ToolbarIcons.redo: PhIcons.arrowClockwise,

  /// No exact "regex" icon — `code` is the closest semantic.
  // TODO(icons): better match
  ToolbarIcons.regex: PhIcons.code,

  /// No exact "case sensitive" icon — using textAa as a best-guess fit.
  // TODO(icons): better match
  ToolbarIcons.caseSensitive: PhIcons.textAa,
  ToolbarIcons.selectionMenuImage: PhIcons.image,
  ToolbarIcons.resetTextColor: PhIcons.arrowCounterClockwise,
  ToolbarIcons.clearHighlightColor: PhIcons.xCircle,
  ToolbarIcons.more: PhIcons.dotsThree,
  ToolbarIcons.stats: PhIcons.chartBar,
  ToolbarIcons.export: PhIcons.export_,
  ToolbarIcons.outline: PhIcons.treeStructure,
  ToolbarIcons.appearance: PhIcons.gear,
  ToolbarIcons.font: PhIcons.textAUnderline,
};

/// Phosphor's "Fill" (solid) variants — used by [ToolbarIcon] when
/// `selected: true`. Only entries that *toggle* (the user can be in or
/// out of the state) get filled variants: text decorations, headings,
/// list types, alignment, link, color, quote. Action icons (copy,
/// delete, undo, redo, close, divider, upload, etc.) have no
/// "selected" meaning and stay on the regular map.
const Map<ToolbarIcons, IconifyIconData> _phMapFilled = {
  ToolbarIcons.bold: PhIcons.textBFill,
  ToolbarIcons.italic: PhIcons.textItalicFill,
  ToolbarIcons.underline: PhIcons.textUnderlineFill,
  ToolbarIcons.strikethrough: PhIcons.textStrikethroughFill,
  ToolbarIcons.code: PhIcons.codeFill,
  ToolbarIcons.color: PhIcons.paletteFill,
  ToolbarIcons.link: PhIcons.linkFill,
  ToolbarIcons.heading: PhIcons.textHFill,
  ToolbarIcons.h1: PhIcons.textHOneFill,
  ToolbarIcons.h2: PhIcons.textHTwoFill,
  ToolbarIcons.h3: PhIcons.textHThreeFill,
  ToolbarIcons.h4: PhIcons.textHFourFill,
  ToolbarIcons.h5: PhIcons.textHFiveFill,
  ToolbarIcons.h6: PhIcons.textHSixFill,
  ToolbarIcons.list: PhIcons.listFill,
  ToolbarIcons.bulletedList: PhIcons.listBulletsFill,
  ToolbarIcons.numberedList: PhIcons.listNumbersFill,
  ToolbarIcons.checkbox: PhIcons.checkSquareFill,
  ToolbarIcons.quote: PhIcons.quotesFill,
  ToolbarIcons.text: PhIcons.textTFill,
  ToolbarIcons.textColor: PhIcons.textAaFill,
  ToolbarIcons.highlightColor: PhIcons.paintBrushFill,
  ToolbarIcons.alignLeft: PhIcons.textAlignLeftFill,
  ToolbarIcons.alignCenter: PhIcons.textAlignCenterFill,
  ToolbarIcons.alignRight: PhIcons.textAlignRightFill,
  ToolbarIcons.textDecorationBold: PhIcons.textAaFill,
  ToolbarIcons.more: PhIcons.dotsThreeFill,
  ToolbarIcons.stats: PhIcons.chartBarFill,
  ToolbarIcons.export: PhIcons.exportFill,
  ToolbarIcons.outline: PhIcons.treeStructureFill,
  ToolbarIcons.appearance: PhIcons.gearFill,
  ToolbarIcons.font: PhIcons.textAUnderlineFill,
};

class ToolbarIcon extends StatelessWidget {
  const ToolbarIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.selected = false,
  });

  final ToolbarIcons icon;
  final double? size;
  final Color? color;

  /// When true and a Fill variant exists for [icon], renders
  /// the filled (solid) Phosphor glyph instead of the regular outline.
  /// Useful for toggle buttons (bold/italic/heading level/alignment/…)
  /// that should "light up" when the surrounding text already has the
  /// corresponding attribute applied.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final data = selected
        ? (_phMapFilled[icon] ?? _phMap[icon]!)
        : _phMap[icon]!;
    return IconifyIcon(data, size: size, color: color);
  }
}
