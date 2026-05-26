import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'appearance_sheet.dart' show appearanceTick;

/// Curated Google Fonts subset — same shape as tuSpeech's font picker, kept
/// in alphabetical order. The list is intentionally hand-picked rather than
/// every family on Google Fonts: ~30 reading-friendly serif / sans-serif
/// covering the common preferences without overwhelming the example.
const List<String> _families = <String>[
  'Atkinson Hyperlegible',
  'Crimson Text',
  'DM Sans',
  'Domine',
  'EB Garamond',
  'Fira Sans',
  'IBM Plex Sans',
  'IBM Plex Serif',
  'Inter',
  'Karla',
  'Lexend',
  'Libre Baskerville',
  'Lora',
  'Merriweather',
  'Noto Sans',
  'Noto Serif',
  'Nunito',
  'Nunito Sans',
  'Open Sans',
  'Poppins',
  'PT Sans',
  'PT Serif',
  'Quicksand',
  'Raleway',
  'Roboto',
  'Source Sans 3',
  'Source Serif 4',
  'Spectral',
  'Tinos',
  'Work Sans',
];

/// Opens the fonts picker as a modal bottom sheet. Tapping a row mutates
/// `editorState.editorStyle` in place via `copyWith` and invokes [onChanged]
/// so the hosting page can `setState` and rebuild `AppFlowyEditor` with the
/// new style.
Future<void> openFontsSheet({
  required BuildContext context,
  required EditorState editorState,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _FontsSheet(editorState: editorState),
  );
}

class _FontsSheet extends StatefulWidget {
  const _FontsSheet({required this.editorState});

  final EditorState editorState;

  @override
  State<_FontsSheet> createState() => _FontsSheetState();
}

class _FontsSheetState extends State<_FontsSheet> {
  String? get _currentFamily => widget
      .editorState.editorStyle.textStyleConfiguration.text.fontFamily
      ?.split('_')
      .first;

  void _select(String family) {
    final style = widget.editorState.editorStyle;
    final text = style.textStyleConfiguration.text;
    widget.editorState.editorStyle = style.copyWith(
      textStyleConfiguration: style.textStyleConfiguration.copyWith(
        text: GoogleFonts.getFont(
          family,
          fontSize: text.fontSize,
          fontWeight: text.fontWeight,
          color: text.color,
        ),
      ),
    );
    setState(() {});
    appearanceTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _currentFamily;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Select font',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: _families.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 0.5, indent: 16),
                itemBuilder: (context, index) {
                  final family = _families[index];
                  TextStyle preview;
                  try {
                    preview = GoogleFonts.getFont(family, fontSize: 18);
                  } catch (_) {
                    preview = TextStyle(fontFamily: family, fontSize: 18);
                  }
                  return ListTile(
                    title: Text(family, style: preview),
                    subtitle: const Text('The quick brown fox 0123'),
                    trailing: family == selected
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => _select(family),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
