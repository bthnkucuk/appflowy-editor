/// The drag-mode state for mobile selection / cursor manipulation. Lives
/// at the editor_state layer so the core (editor_state, scroll service)
/// can compare against it directly without the `.toString()` hack that
/// previously stringified the enum to break a layering dependency.
///
/// Name is intentionally kept as `MobileSelectionDragMode` (and not the
/// shorter `SelectionDragMode`) to avoid a 50+ callsite rename. The enum
/// has been mobile-coded historically; if desktop drag-to-select ever
/// reuses these states a typedef alias is the migration path.
enum MobileSelectionDragMode {
  none,
  leftSelectionHandle,
  rightSelectionHandle,
  cursor,
}

/// Key under which the active [MobileSelectionDragMode] is published in
/// `EditorState.selectionExtraInfo`. Consumers can read it directly, but
/// `SelectionExtraInfo.dragMode` is the typed access path you actually
/// want.
const String selectionDragModeKey = 'selection_drag_mode';
