import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fonts_sheet.dart';

/// Bumps every time a sheet mutates `editorState.editorStyle`. The host
/// editor pages (mobile_editor / desktop_editor) wrap their AppFlowyEditor
/// in a `ValueListenableBuilder<int>` against this so the new style
/// actually reaches the heading textStyleBuilder closures and the body
/// text style on the next frame. A plain `setState` on the home page
/// doesn't work because `_widgetBuilder` returns a cached editor widget
/// instance, so its State never rebuilds via the parent.
final ValueNotifier<int> appearanceTick = ValueNotifier<int>(0);

/// Opens the appearance settings sheet. Mutations are written directly to
/// [editorState.editorStyle] and [appearanceTick] is bumped after each one
/// so the editor subtree rebuilds. No persistence — values reset to
/// whatever the host page constructed on next app launch.
Future<void> openAppearanceSheet({
  required BuildContext context,
  required EditorState editorState,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _AppearanceSheet(
      editorState: editorState,
    ),
  );
}

class _AppearanceSheet extends StatefulWidget {
  const _AppearanceSheet({required this.editorState});

  final EditorState editorState;

  @override
  State<_AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<_AppearanceSheet> {
  EditorState get _editorState => widget.editorState;
  TextStyle get _text => _editorState.editorStyle.textStyleConfiguration.text;

  void _updateText({
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    final family = fontFamily ?? _text.fontFamily ?? 'Poppins';
    // Re-resolve through `GoogleFonts.getFont` so the bundled font asset is
    // pulled (instead of relying on a fontFamily string the platform may
    // not recognise). On failure (offline first launch of an unseen family)
    // fall back to a TextStyle that just sets fontFamily — the platform
    // will substitute, but at least the size/weight changes still apply.
    TextStyle next;
    try {
      next = GoogleFonts.getFont(
        // Strip Google Fonts' internal "_regular" / "_bold" suffix the
        // resolver tacks on after a previous getFont call, otherwise it
        // looks up a non-existent family.
        family.split('_').first,
        fontSize: fontSize ?? _text.fontSize,
        fontWeight: fontWeight ?? _text.fontWeight,
        color: _text.color,
      );
    } catch (_) {
      next = _text.copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
    }
    final style = _editorState.editorStyle;
    _editorState.editorStyle = style.copyWith(
      textStyleConfiguration: style.textStyleConfiguration.copyWith(text: next),
    );
    setState(() {});
    appearanceTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = _text.fontSize ?? 16;
    final isBold = (_text.fontWeight ?? FontWeight.normal).value >=
        FontWeight.w600.value;
    final family = _text.fontFamily ?? 'Poppins';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Appearance',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),

            // Font size slider
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Text('Aa', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      min: 10,
                      max: 28,
                      divisions: 18,
                      value: size.clamp(10, 28),
                      label: size.round().toString(),
                      onChanged: (v) => _updateText(fontSize: v),
                    ),
                  ),
                  const Text('Aa', style: TextStyle(fontSize: 22)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Font family row → opens fonts sheet
            ListTile(
              leading: const Icon(Icons.text_format),
              title: const Text('Font'),
              subtitle: Text(family),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await openFontsSheet(
                  context: context,
                  editorState: _editorState,
                );
                if (mounted) setState(() {});
              },
            ),

            // Bold toggle
            SwitchListTile(
              secondary: const Icon(Icons.format_bold),
              title: const Text('Bold'),
              value: isBold,
              onChanged: (v) => _updateText(
                fontWeight: v ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
