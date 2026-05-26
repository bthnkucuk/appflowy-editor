import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Default text color options when no option is provided
/// - support
///   - desktop
///   - web
///   - mobile
///
List<ColorOption> generateTextColorOptions() {
  return [
    ColorOption(
      colorHex: Colors.grey.toHex(),
      name: aft.fontColorGray,
    ),
    ColorOption(
      colorHex: Colors.brown.toHex(),
      name: aft.fontColorBrown,
    ),
    ColorOption(
      colorHex: Colors.yellow.toHex(),
      name: aft.fontColorYellow,
    ),
    ColorOption(
      colorHex: Colors.green.toHex(),
      name: aft.fontColorGreen,
    ),
    ColorOption(
      colorHex: Colors.blue.toHex(),
      name: aft.fontColorBlue,
    ),
    ColorOption(
      colorHex: Colors.purple.toHex(),
      name: aft.fontColorPurple,
    ),
    ColorOption(
      colorHex: Colors.pink.toHex(),
      name: aft.fontColorPink,
    ),
    ColorOption(
      colorHex: Colors.red.toHex(),
      name: aft.fontColorRed,
    ),
  ];
}

/// Default background color options when no option is provided
/// - support
///   - desktop
///   - web
///   - mobile
///
List<ColorOption> generateHighlightColorOptions() {
  return [
    ColorOption(
      colorHex: Colors.grey.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorGray,
    ),
    ColorOption(
      colorHex: Colors.brown.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorBrown,
    ),
    ColorOption(
      colorHex: Colors.yellow.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorYellow,
    ),
    ColorOption(
      colorHex: Colors.green.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorGreen,
    ),
    ColorOption(
      colorHex: Colors.blue.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorBlue,
    ),
    ColorOption(
      colorHex: Colors.purple.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorPurple,
    ),
    ColorOption(
      colorHex: Colors.pink.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorPink,
    ),
    ColorOption(
      colorHex: Colors.red.withValues(alpha: 0.3).toHex(),
      name: aft.backgroundColorRed,
    ),
  ];
}
