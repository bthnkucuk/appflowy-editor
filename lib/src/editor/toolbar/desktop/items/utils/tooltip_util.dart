import 'package:appflowy_editor/appflowy_editor.dart';
import '../../../../util/platform_extension.dart';
import 'package:flutter/foundation.dart';

String shortcutTooltips(
  String? macOSString,
  String? windowsString,
  String? linuxString,
) {
  if (kIsWeb) return '';
  if (PlatformExtension.isMacOS && macOSString != null) {
    return '\n$macOSString';
  } else if (PlatformExtension.isWindows && windowsString != null) {
    return '\n$windowsString';
  } else if (PlatformExtension.isLinux && linuxString != null) {
    return '\n$linuxString';
  }

  return '';
}

String getTooltipText(String id) {
  switch (id) {
    case 'underline':
      return '${aft.underline}${shortcutTooltips('⌘ + U', 'CTRL + U', 'CTRL + U')}';

    case 'bold':
      return '${aft.bold}${shortcutTooltips('⌘ + B', 'CTRL + B', 'CTRL + B')}';

    case 'italic':
      return '${aft.italic}${shortcutTooltips('⌘ + I', 'CTRL + I', 'CTRL + I')}';

    case 'strikethrough':
      return '${aft.strikethrough}${shortcutTooltips('⌘ + SHIFT + S', 'CTRL + SHIFT + S', 'CTRL + SHIFT + S')}';

    case 'code':
      return '${aft.embedCode}${shortcutTooltips('⌘ + E', 'CTRL + E', 'CTRL + E')}';

    case 'align_left':
      return aft.textAlignLeft;

    case 'align_center':
      return aft.textAlignCenter;

    case 'align_right':
      return aft.textAlignRight;

    case 'text_direction_auto':
      return aft.auto;

    case 'text_direction_ltr':
      return aft.ltr;

    case 'text_direction_rtl':
      return aft.rtl;

    default:
      return '';
  }
}
