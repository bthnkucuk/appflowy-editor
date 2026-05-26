# super_editor perf patterns — research notes

Source: github.com/superlistapp/super_editor (FBH fork, `main`, 0.3.0-dev.48).
Pub: pub.dev/packages/super_editor — score 60/160, 779 likes, latest stable 0.2.7.
README has zero perf claims; CHANGELOG mentions perf only in `0.2.3` ("Typing lag in large documents"). The real perf design lives in source.

## 1. TL;DR

super_editor's perf rests on four pillars we don't have:
(1) **A presenter pipeline with phase-cached view models** plus a per-node diff (`changedComponents`) so a selection change re-runs only the selection phase and re-builds only nodes whose VM actually changed.
(2) **A `ContentLayers` `RenderObjectWidget`** that hijacks `BuildOwner.onBuildScheduled` to **decouple layer (selection/caret) builds from content (text) builds** — a layer-only notify never dirties content; a content build forgets layers and rebuilds them inside `performLayout`.
(3) **Cached `SuperText` subtree** (`_RebuildOptimizedSuperTextWithSelection`) with selection routed through a `ValueNotifier` to a `CustomPainter` sibling — RichText stays identity-equal across selection changes.
(4) **Explicit `Timer`-vs-`Ticker` choice** for caret blink because tickers force Flutter to 60 fps even when idle.

## 2. Architectural patterns worth borrowing

### 2a. Presenter pipeline + per-node diff
**What.** `SingleColumnLayoutPresenter` (`super_editor/lib/src/default_editor/layout_single_column/_presenter.dart`) runs ordered `SingleColumnLayoutStylePhase`s (stylesheet → per-component → composing → selection). Each phase output cached in `_phaseViewModels[i]` (line 71/192). When a phase calls `markDirty()`, only phases ≥ `_earliestDirtyPhase` re-run. The result is diffed per node into `changedComponents` / `added` / `moved` / `removed` (lines 206–304). `_PresenterComponentBuilder` (`_layout.dart` 920–928) **only setStates if its own `watchNode` is in `changedComponents`**. FBH issue #1780 ("Updating single document node rebuilds entire document") is the motivating ticket.

**Why faster.** Selection change → only selection-phase reruns; only nodes that gained/lost selection rebuild. Our H2.3.x derived-paint notifier solves the paint half; this solves the build half too.

**Adoption.** Add a styling pipeline between `EditorState` and block widgets that emits per-node decoration VMs. Blocks subscribe to a node-keyed change set, not the global `Selection`. Effort **L**, risk **high** (touches selection/format/attribute styler).

### 2b. ContentLayers: build layers after content layout
**What.** `ContentLayers` (`infrastructure/content_layers.dart`, 729 lines) holds `underlays`/`content`/`overlays` as separate render-object slots. Its element intercepts `BuildOwner.onBuildScheduled` (line 132–137); when both content and any layer are dirty it calls `_temporarilyForgetLayers()` (line 319) so layers don't build in the normal phase; then `performLayout` re-inflates them via `buildLayers()` (line 275). Sliver variant: `SliverContentLayers` (`content_layers_for_slivers.dart`). Wired into `SuperEditor` at `super_editor.dart` 736–765 (selection-leader, caret, magnifier, drag handles are all overlays).

**Why faster.** Selection notify → only the layer rebuilds; text never marks dirty. Layers can read content layout safely since they build inside the layout pass.

**Adoption.** Hoist `HighlightAreaPaint`, cursor painter, drag-handle leaders out of each block into one viewport-wide overlay reading block rects from a `DocumentLayout`-style API. Kills the "BSA+BHA = 5 siblings per block × N blocks" overhead and the doubly-nested `BlockSelectionContainer`. Effort **L**, risk **medium-high** (requires a `super_sliver_list`-friendly variant — see §4 caveat).

### 2c. Cached SuperText subtree
**What.** `_RebuildOptimizedSuperTextWithSelection` (`super_text_layout/lib/src/super_text_layout_with_selection.dart` 115–204) caches its built `SuperText` widget in `_cachedSubtree`; invalidated only when `richText`, `textAlign`, or `textScaler` change (147–172). Selection flows through `ValueNotifier<List<UserSelection>>` consumed by `ValueListenableBuilder` inside `layerBeneathBuilder` (206–230). The painter `TextSelectionPainter` (`text_selection_layer.dart` 140–201) is a `CustomPainter` with proper equality `shouldRepaint` (196–200).

**Why faster.** Selection change → identity-equal `SuperText` widget, Flutter skips reconciliation; only the `CustomPainter` repaints.

**Adoption.** Direct fix for `AppFlowyRichText.confirmContextEnabled` postFrame `setState(() {})` and for `_buildPlaceholderText` rebuilding the RichText. Cache the inner RichText; route selection deltas through a `ValueNotifier` to a sibling painter. Effort **M**, risk low-medium.

### 2d. LayoutAwareRichText
**What.** `LayoutAwareRichText` (`super_text.dart` 294–393) extends `RichText`; `RenderLayoutAwareParagraph.onMarkNeedsLayout` (386) lets `SuperTextState` invalidate its `_paragraph` cache on layout dirty (77). Background/foreground layers gate on `_paragraph != null` (100, 116). CHANGELOG 0.3.0-dev.23: *"Prevent Flutter's invalidation of widget span layout just because the widget changes — delegate to standard render object layout invalidation."*

**Why faster.** Selection painter can't fire against stale layout; no second-pass relayout from paint. Effort **S**, risk low.

### 2e. BlinkController Timer mode
**What.** `BlinkController` (`super_text_layout/lib/src/infrastructure/blink_controller.dart` 137–149) supports `BlinkTimingMode.ticker | timer`. Doc comment: *"Running Tickers forces Flutter into full FPS rendering, even when nothing needs to be rebuilt or painted."* FBH issue #1253 is the public record.

**Why faster.** Our `_HighlightAreaPaintState.initState` creates an `AnimationController` + `Ticker` even when the rect set is empty. A live `Ticker` pulls Flutter to 60 fps; on mobile during idle scroll this is real watt cost.

**Adoption.** Drop the `Ticker` when no auto-snap pulse is in flight; use a one-shot `Future.delayed` or `Timer` only while pulsing. Effort **XS-S**, risk low.

## 3. Specific code patterns worth borrowing

- **Static closure for dirty-tree traversal** — `ContentLayersElement._isSubtreeDirtyVisitor` (content_layers.dart 241–262) is a top-level static deliberately not capturing `this`: *"intentionally static to prevent closure allocation during the traversal of the element tree."* Apply to our selection rect collection and attribute scans.
- **`assert(() { … log … return true; }())` for log strings** (same file 245–250) — elided in release, no `kDebugMode` branch overhead.
- **`onMarkNeedsLayout` callback** from a custom `RenderParagraph` (super_text.dart 369) — clean way to invalidate a paragraph cache without polling layout.
- **Strict `shouldRepaint` equality** in selection painter (text_selection_layer.dart 196–200): compares `textLayout`, `textSelection`, `selectionColor`. Mirror this in `HighlightAreaPaint`: gate `shouldRepaint` on `pulsePhase != old.pulsePhase || !listEquals(rects, old.rects)`.
- **Structure vs content split**: `SingleColumnDocumentLayout._onViewModelChange` only `setState`s for add/move/remove (_layout.dart 129–134); changed-content rebuilds flow through child `_PresenterComponentBuilder`s. Parent rebuilds for structure, children rebuild for content — clean rule we can adopt.

## 4. Things super_editor does that we shouldn't copy

- **No virtualization.** `SingleColumnDocumentLayout` builds a `Column` inside one `SliverToBoxAdapter` (_layout.dart 718–732). For long docs they pay everything up front. **Do not regress to a monolithic sliver for the sake of `SliverContentLayers`** — build a `super_sliver_list`-friendly content-layers variant where layers paint over the *viewport* and query a `DocumentLayout` for rects on demand.
- **Global `BuildOwner.onBuildScheduled` interception** (content_layers.dart 87, 92) uses static state across all instances. Powerful but fragile across hot reload and multi-window. Limit to a single root `ContentLayers` if we adopt 2b.
- **Per-component `GlobalKey` cache** (_layout.dart 805). They lean on this for position queries; we already do too — don't expand the surface, `GlobalKey` reparenting is costly.
- **`MutableDocument`/`DocumentComposer` model.** API direction, not perf. Lift 2a (the pipeline), leave the document model.
- **`follow_the_leader` for popovers/handles.** FBH issue #1576 (still open) — unresolved iOS keyboard/popover perf tied to it. Not a model to copy.

## 5. Open questions

1. Does the presenter pipeline (2a) scale to N≈1000 blocks, or does the per-node diff walk dominate? Their `example_perf/long_doc_demo.dart` (Frankenstein) is the benchmark to port.
2. Can a `super_sliver_list`-flavored `ContentLayers` exist? Sliver builds children lazily; ContentLayers assumes a stable child set during layout. Likely needs viewport-extent painting + lazy rect lookup.
3. Is `RenderLayoutAwareParagraph.onMarkNeedsLayout` Flutter-version-stable? CHANGELOG 0.3.0-dev.23 implies they had to work around Flutter inline-widget span layout. Pin-check before adopting.
4. Cached-subtree pattern looks trivially mergeable into `AppFlowyRichText` — but past empty-delta-placeholder revert (device-noisy) suggests we need a `debugTrackTextBuilds`-style counter, not just frame time, to validate.
5. Trace the commit behind CHANGELOG 0.2.3 *"SuperEditor rebuilds layers when document layout or component layout changes, e.g., rebuilds caret when a list item animates its size"* — animated list/task heights are exactly our scenario.

## Key file refs (super_editor source, `main`)

- `super_editor/lib/src/infrastructure/content_layers.dart` — layer-decoupling render object
- `super_editor/lib/src/infrastructure/content_layers_for_slivers.dart` — sliver variant
- `super_editor/lib/src/default_editor/layout_single_column/_presenter.dart` — pipeline + diff (lines 71, 188–304)
- `super_editor/lib/src/default_editor/layout_single_column/_layout.dart` lines 758–774, 920–942 — per-node setState gate
- `super_text_layout/lib/src/super_text_layout_with_selection.dart` lines 115–263 — cached subtree
- `super_text_layout/lib/src/super_text.dart` lines 76–130, 294–393 — `LayoutAwareRichText`
- `super_text_layout/lib/src/text_selection_layer.dart` lines 140–201 — `TextSelectionPainter`
- `super_text_layout/lib/src/infrastructure/blink_controller.dart` lines 137–149 — `BlinkTimingMode`
- `super_editor/lib/src/default_editor/super_editor.dart` lines 736–765 — wiring of underlays/overlays
- FBH issue #1780 (closed) — motivated per-node setState gate
- FBH issue #1253 (open, blocked-by-Flutter) — motivated `Timer`-mode caret
