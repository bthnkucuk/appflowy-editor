import 'package:flutter/material.dart';
import 'package:iconifyx_ph/iconifyx_ph.dart';

enum AFMobileIcons {
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

const Map<AFMobileIcons, IconifyIconData> _phMap = {
  AFMobileIcons.textDecorationBold: PhIcons.textAa,
  AFMobileIcons.bold: PhIcons.textB,
  AFMobileIcons.italic: PhIcons.textItalicBold,
  AFMobileIcons.underline: PhIcons.textUnderline,
  AFMobileIcons.strikethrough: PhIcons.textStrikethrough,
  AFMobileIcons.code: PhIcons.code,
  AFMobileIcons.color: PhIcons.palette,
  AFMobileIcons.link: PhIcons.link,
  AFMobileIcons.heading: PhIcons.textH,
  AFMobileIcons.h1: PhIcons.textHOne,
  AFMobileIcons.h2: PhIcons.textHTwo,
  AFMobileIcons.h3: PhIcons.textHThree,
  AFMobileIcons.list: PhIcons.list,
  AFMobileIcons.bulletedList: PhIcons.listBullets,
  AFMobileIcons.numberedList: PhIcons.listNumbers,
  AFMobileIcons.checkbox: PhIcons.checkSquare,
  AFMobileIcons.quote: PhIcons.quotes,
  AFMobileIcons.divider: PhIcons.minus,
  AFMobileIcons.close: PhIcons.x,
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
class AFMobileIcon extends StatelessWidget {
  const AFMobileIcon({
    super.key,
    required this.afMobileIcons,
    this.size = 24,
    this.color,
  });

  final AFMobileIcons afMobileIcons;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconifyIcon(_phMap[afMobileIcons]!, size: size, color: color);
  }
}
