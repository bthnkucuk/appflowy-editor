import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Bumps every time the appearance sheet (or its sibling fonts sheet)
/// mutates `editorState.editorStyle`. Hosts that cache the editor widget
/// instance can wrap their `AppFlowyEditor` in a
/// `ValueListenableBuilder<int>` against this so style changes
/// propagate as a new widget prop. Apps that already rebuild on every
/// `setState` don't need to listen.
final ValueNotifier<int> editorAppearanceTick = ValueNotifier<int>(0);

/// Mobile appearance sheet — entry point for body text styling. Surfaces
/// the most common knobs (font size, font family, weight, slant, line
/// height) with room to grow. Mutations are written directly to
/// `editorState.editorStyle.textStyleConfiguration.text` via
/// `copyWith`, then [editorAppearanceTick] is bumped so the editor
/// subtree rebuilds with the new style. No persistence — values reset
/// on next mount.
class AppearanceMobileSheet extends StatefulWidget {
  const AppearanceMobileSheet({super.key, required this.editorState});

  final EditorState editorState;

  @override
  State<AppearanceMobileSheet> createState() => _AppearanceMobileSheetState();
}

class _AppearanceMobileSheetState extends State<AppearanceMobileSheet> {
  EditorState get _editorState => widget.editorState;
  TextStyle get _text => _editorState.editorStyle.textStyleConfiguration.text;

  /// Single update path for every appearance knob — resolves the new
  /// style through GoogleFonts so the chosen family/weight/slant
  /// actually load, and falls back to a plain `copyWith` when the
  /// family isn't in the GoogleFonts catalog (e.g. system fonts).
  void _updateText({
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? height,
  }) {
    final currentFamily = _text.fontFamily?.split('_').first ?? 'Poppins';
    final family = fontFamily ?? currentFamily;
    TextStyle next;
    try {
      next = GoogleFonts.getFont(
        family,
        fontSize: fontSize ?? _text.fontSize,
        fontWeight: fontWeight ?? _text.fontWeight,
        fontStyle: fontStyle ?? _text.fontStyle,
        color: _text.color,
        height: height ?? _text.height,
      );
    } catch (_) {
      next = _text.copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        height: height,
      );
    }
    final style = _editorState.editorStyle;
    _editorState.editorStyle = style.copyWith(
      textStyleConfiguration:
          style.textStyleConfiguration.copyWith(text: next),
    );
    setState(() {});
    editorAppearanceTick.value++;
  }

  Future<void> _openFonts() async {
    await Navigator.of(context).push(
      StupidSimpleSheetRoute<void>(
        barrierColor: Colors.transparent,
        originateAboveBottomViewInset: true,
        child: MobileToolbarTheme(
          child: EditorToolbarSheetScaffold(
            child: FontsMobileSheet(editorState: _editorState),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = _text.fontSize ?? 16;
    final isBold = (_text.fontWeight ?? FontWeight.normal).value >=
        FontWeight.w600.value;
    final isItalic = _text.fontStyle == FontStyle.italic;
    final family = _text.fontFamily?.split('_').first ?? 'Poppins';
    final lineHeight = _text.height ?? 1.4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Appearance', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 16, thickness: 0.5),

          // Font size — small Aa / slider / large Aa, current value as
          // the slider thumb label.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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

          // Font family — opens the curated fonts list. Subtitle shows
          // the currently active family.
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.text_format),
            title: const Text('Font'),
            subtitle: Text(family),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openFonts,
          ),

          // Body weight — bold vs regular.
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.format_bold),
            title: const Text('Bold'),
            value: isBold,
            onChanged: (v) => _updateText(
              fontWeight: v ? FontWeight.bold : FontWeight.normal,
            ),
          ),

          // Body slant — italic vs upright.
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.format_italic),
            title: const Text('Italic'),
            value: isItalic,
            onChanged: (v) => _updateText(
              fontStyle: v ? FontStyle.italic : FontStyle.normal,
            ),
          ),

          // Line height — TextStyle.height multiplier. Useful range for
          // body copy is roughly 1.2–1.8; allow a bit beyond for the
          // user that wants very tight or very airy text.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.format_line_spacing),
                const SizedBox(width: 12),
                const Text('Line height'),
                Expanded(
                  child: Slider(
                    min: 1.0,
                    max: 2.0,
                    divisions: 10,
                    value: lineHeight.clamp(1.0, 2.0),
                    label: lineHeight.toStringAsFixed(1),
                    onChanged: (v) => _updateText(height: v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
