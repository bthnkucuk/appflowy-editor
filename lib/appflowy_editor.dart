/// AppFlowyEditor library — full editor surface.
///
/// This is the "everything" entry point and is backwards-compatible with
/// pre-H3.4 imports. For tighter dependencies, prefer one of:
///
///  * `package:appflowy_editor/core.dart`     — document/selection model only
///  * `package:appflowy_editor/blocks.dart`   — block component primitives
///  * `package:appflowy_editor/plugins.dart`  — encoders/decoders (md, html, …)
///  * `package:appflowy_editor/mobile.dart`   — mobile-only UI helpers
library;

// ---------------------------------------------------------------------------
// Sub-libraries (re-exported wholesale for backwards compat).
// ---------------------------------------------------------------------------
export 'blocks.dart';
export 'core.dart';
export 'mobile.dart';
export 'plugins.dart';

// ---------------------------------------------------------------------------
// Editor surface
// ---------------------------------------------------------------------------
export 'src/editor/editor.dart';
export 'src/editor/export/export_sheet.dart';
export 'src/editor/find_replace_menu/find_and_replace.dart';
export 'src/editor/selection_menu/selection_menu.dart';

// EditorState and friends
export 'src/editor_state.dart';
export 'src/editor_state/undo_manager.dart' show TransactionSource;

// ---------------------------------------------------------------------------
// Extensions, infra, l10n
// ---------------------------------------------------------------------------
export 'src/extensions/extensions.dart';
export 'src/infra/clipboard.dart';
export 'src/infra/log.dart';
// Slang-generated translations. Consumer apps that use slang themselves will
// hide these by importing this barrel with `hide LocaleSettings,
// TranslationProvider, AppLocaleUtils` to avoid name clashes.
export 'src/localizations/strings.g.dart';

// ---------------------------------------------------------------------------
// Render layer
// ---------------------------------------------------------------------------
export 'src/render/selection/selectable.dart';
export 'src/render/toolbar/toolbar_item.dart';

// ---------------------------------------------------------------------------
// Services (context menu, shortcut handlers, default text ops)
// ---------------------------------------------------------------------------
export 'src/service/context_menu/built_in_context_menu_item.dart';
export 'src/service/context_menu/context_menu.dart';
export 'src/service/default_text_operations/format_rich_text_style.dart';
export 'src/service/internal_key_event_handlers/copy_paste_handler.dart';
export 'src/service/shortcut_event/key_mapping.dart';
export 'src/service/shortcut_event/keybinding.dart';
