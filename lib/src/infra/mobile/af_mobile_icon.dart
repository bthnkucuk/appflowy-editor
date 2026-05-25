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
  list,
  bulletedList,
  numberedList,
  checkbox,
  quote,
  divider,
  close,
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
  ToolbarIcons.list: PhIcons.list,
  ToolbarIcons.bulletedList: PhIcons.listBullets,
  ToolbarIcons.numberedList: PhIcons.listNumbers,
  ToolbarIcons.checkbox: PhIcons.checkSquare,
  ToolbarIcons.quote: PhIcons.quotes,
  ToolbarIcons.divider: PhIcons.minus,
  ToolbarIcons.close: PhIcons.x,
};

/// {@tool snippet}
/// All the icons are from AFMobileIcons enum.
///
/// ```dart
/// AFMobileIcon(
///       afMobileIcons: AFMobileIcons.bold,
///       size: 24,
///       color: Colors.black,
///)
/// ```
/// {@end-tool}
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
