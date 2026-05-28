# super_editor — architectural patterns worth knowing

Research target: `superlistapp/super_editor` (https://github.com/superlistapp/super_editor).
Companion file (perf-focused): `./super_editor_perf_research.md`.

## 1. TL;DR

super_editor splits what we keep on `EditorState` into four cleanly separated, single-purpose objects: a read-only `Document`, a `MutableDocumentComposer` that owns selection + IME + composing region, an `Editor` that runs a `Request -> Command -> Reaction -> Listeners` pipeline, and a `SingleColumnLayoutPresenter` that produces per-component view models through a list of `SingleColumnLayoutStylePhase`s. Selection is not painted per block — it is a **style phase** that mutates view models before render, and the caret is a **single document-level overlay**, not a tree of per-node painters. Mobile vs desktop branch on a `DocumentGestureMode` enum into three sibling `*TouchInteractor` / `MouseInteractor` widgets sitting under a shared `SuperEditorIosControlsScope` / `SuperEditorAndroidControlsScope` `InheritedWidget`. The plugin surface is small and explicit: `componentBuilders`, `keyboardActions`, `plugins`, `documentOverlayBuilders`, `customStylePhases`. The model is still `Map<String, dynamic>` metadata (same typo risk as ours) and the node sequence is a **flat list, not a tree** — that single fact is the most architecturally consequential difference.

## 2. Document / Node model

`super_editor/lib/src/core/document.dart`:

- `abstract class Document implements Iterable<DocumentNode>` — the document **is** an iterable of nodes; navigation is by index, not by walking children.
- `@immutable abstract class DocumentNode` — nodes are immutable. Edits produce new node instances; the `Editor` swaps them in via commands.
- `Map<String, dynamic>? metadata` with `dynamic getMetadataValue(String key)` and constants like `NodeMetadata.blockType`, `NodeMetadata.isDeletable`. Same string-key risk we have, but **scoped to a `metadata` bag** rather than spread across `attributes` on the node itself — typed fields (`text`, `id`) live as first-class properties on each concrete `TextNode`/`ImageNode`/`TaskNode`.
- Navigation API: `getNodeById`, `getNodeAt(int)`, `getNodeBefore`, `getNodeAfter`, `getNodesInside(pos1, pos2)`. There is no concept of a parent/child node — nested structures (toggle lists, callouts with children) would need to be modeled as sibling nodes plus indent metadata.

Mutation goes through `Editor.execute(List<EditRequest> requests)` in `core/editor.dart`. Requests are dispatched by `requestHandlers` into `EditCommand`s which mutate `Editable` resources and log `EditEvent`s. A `reactionPipeline` then runs over the batched events (this is where things like markdown-syntax-to-style happen). `startTransaction()` / `endTransaction()` bundle multiple commands; `CommandTransaction` is the unit of undo/redo. Listeners are notified once per transaction with the full event list.

## 3. Selection + rendering layer

This is the biggest gap with our codebase.

- **Selection is a style phase, not a widget**. `super_editor/lib/src/default_editor/layout_single_column/_styler_user_selection.dart` defines `class SingleColumnLayoutSelectionStyler extends SingleColumnLayoutStylePhase` whose `style(Document, SingleColumnLayoutViewModel)` walks each per-component view model and writes `selection`, `selectionColor`, `highlightWhenEmpty` into it (for `TextComponentViewModel`) before the layout widget rebuilds. No per-block `BlockSelectionContainer` / 5-widget fan-out — the selection rectangle is data that flows into the same widget that draws the text.
- **The presenter pipeline** (`_presenter.dart`) is a list of phases applied in order: `(baseline) -> (text styles) -> (selection styles) -> (composing region) -> (layout)`. Each phase copies the prior `SingleColumnLayoutViewModel` and returns a new one. The presenter caches intermediate results so when only selection changes, only the selection phase reruns.
- **Caret is a single overlay**. `default_editor/document_caret_overlay.dart` is one `CaretDocumentOverlay` `StatefulWidget` wrapping a `Container` keyed `DocumentKeys.caret` inside an `AnimatedBuilder` driven by `BlinkController`, wrapped in a `RepaintBoundary`. Position comes from `computeLayoutDataWithDocumentLayout()` which asks the `DocumentLayout` for the `Rect` of the extent.
- **DocumentLayout is an abstract interface**, not a widget — `core/document_layout.dart` exposes `getOffsetForPosition`, `getRectForPosition`, `getDocumentPositionNearestToOffset`. Concrete implementations are mixed into `State` objects (`DocumentComponent`) so any block's `State` answers position queries against its own `RenderBox`.

## 4. Mobile / desktop split

- Branch point is a `DocumentGestureMode { mouse, android, iOS }` enum in `super_editor.dart`. Three sibling interactors:
  - `DocumentMouseInteractor` (desktop)
  - `AndroidDocumentTouchInteractor`
  - `IosDocumentTouchInteractor` (`default_editor/document_gestures_touch_ios.dart`)
- Shared controls scope per platform is an `InheritedWidget`: `class SuperEditorIosControlsScope extends InheritedWidget` carries a `SuperEditorIosControlsController` that owns `handleBeingDragged = ValueNotifier<HandleType?>` (collapsed/base/extent) — very similar to our `_pan.dragMode` but as a `ValueNotifier` consumed by overlay widgets, not state on the gesture detector.
- **Auto-scroll is a dedicated reusable class**: `DragHandleAutoScroller`, initialized in the interactor's `initState`, with configurable `dragAutoScrollBoundary` (default 54px). Both iOS and Android interactors instantiate it — same class, different glue.
- iOS-specific affordances live as named helper objects: `IosLongPressSelectionStrategy`, `FloatingCursorController`, magnifier widget. They're composed in by `IosDocumentTouchInteractor` rather than baked into a giant build method.

The widget composition is closer to our split than the model layer; the win is **sharing `DragHandleAutoScroller` and pushing handle state into a `ValueNotifier` on an `InheritedWidget` controller** rather than carrying it as `setState` inside the gesture detector.

## 5. Plugin / customization surface

`SuperEditor` constructor exposes the extension API as plain typed parameters (no service registration):

- `componentBuilders: List<ComponentBuilder>` — each builder has `SingleColumnLayoutComponentViewModel? createViewModel(...)` + `Widget? createComponent(...)`. Returning `null` cascades to the next builder; users prepend their builders to `defaultComponentBuilders`.
- `keyboardActions: List<DocumentKeyboardAction>` — top-level functions `ExecutionInstruction Function({required SuperEditorContext editContext, required KeyEvent keyEvent})`. Return values are `continueExecution | haltExecution | blocked`. Adding a shortcut means writing a function and prepending to `defaultKeyboardActions`.
- `plugins: Set<SuperEditorPlugin>` — each plugin can inject component builders, reactions, keyboard actions, overlay builders in one bundle (e.g. `MarkdownInlineUpstreamSyntaxPlugin`).
- `documentUnderlayBuilders` / `documentOverlayBuilders` — stack widgets above/below the document layout. Caret blink, drag handles, magnifier are all built this way.
- `customStylePhases: List<SingleColumnLayoutStylePhase>` — let users inject view-model transforms (e.g. "highlight all TODOs in red").

Three lessons: (1) extension points are plain typed list-shaped constructor params, not a registry; (2) "default" lists are exported as `defaultXxx` constants so users spread+override; (3) the same `plugins:` set can hook into any of the above — one entry point, multiple capabilities.

## 6. State management

- No `Provider`, no `Riverpod`. Selection: `MutableDocumentComposer extends ChangeNotifier`, exposes `ValueListenable<DocumentSelection?> get selectionNotifier` + a `Stream<DocumentSelectionChange> get selectionChanges` carrying a `reason` (so listeners can disambiguate IME vs user vs programmatic).
- `Editor` itself is a `ChangeNotifier`; transactions batch notifications.
- Shared platform controls (handle drag state, toolbar visibility, magnifier focal point) live on `SuperEditor{Ios,Android}ControlsController` exposed via an `InheritedWidget` scope — the only InheritedWidget in the editor's hot path.
- `SuperEditorContext` (a.k.a. `EditContext`, `core/edit_context.dart`) is the **dependency-injection bundle**, not a service locator — it's just a struct of `{editor, document, composer, scroller, commonOps, documentLayout, editorFocusNode}` passed into keyboard actions and reactions. Our `serviceLocator` mixin is fancier; theirs is dumber and easier to follow.

## 7. Testing affordances

`super_editor/lib/src/test/super_editor_test/` has four files, all worth borrowing the shape of:

- **`supereditor_robot.dart`** — `extension SuperEditorRobot on WidgetTester` with methods like `placeCaretInParagraph`, `doubleTapInParagraph`, `tripleTapInParagraph`, `longPressInParagraph`, `dragSelectDocumentFromPositionByOffset`, `pressDownOnCollapsedMobileHandle`, `pressDownOnUpstreamMobileHandle`, `typeImeText`, `typeTextAdaptive`, `startFloatingCursorGesture/update/stop`. Tests read like English: `await tester.placeCaretInParagraph("1", 5); await tester.typeImeText("hi");`.
- **`supereditor_inspector.dart`** — read-only queries on a mounted editor (selection, node rect, text content) — symmetric to the robot.
- **`supereditor_test_tools.dart`** — `pumpEditor` helpers / builders so tests don't have to wire up `Editor + Document + Composer` by hand.
- **`tasks_test_tools.dart`** — block-type-specific helpers; the pattern is "every non-trivial node type ships its own test helpers."

Steal verbatim: the `extension on WidgetTester` shape and the inspector/robot split. We currently lack any equivalent.

## 8. Patterns worth borrowing (prioritized)

1. **Selection-as-style-phase, caret-as-single-overlay** (high impact, medium disruption).
   (a) `SingleColumnLayoutSelectionStyler` writes selection into view models; `CaretDocumentOverlay` is one widget for the whole document.
   (b) Kills our 5-widgets-per-block fan-out; collapses caret blink to a single `RepaintBoundary`.
   (c) Requires the block builders to consume a "view model with selection baked in" instead of reading selection from their own context. Touches every `BlockComponentBuilder`.
   (d) Effort: ~1-2 weeks; risk: medium — affects every block. Probably the single biggest perceived-perf win architecturally.

2. **Request -> Command -> Reaction -> Listeners pipeline** (high impact, high disruption).
   (a) `Editor.execute(List<EditRequest>)` dispatches to handlers producing `EditCommand`s, which produce `EditEvent`s, which feed a `reactionPipeline`.
   (b) Reactions are how super_editor implements markdown-syntax-shortcuts, autolinkification, spell-check trigger — orthogonal to the command that caused them. Our equivalents are scattered through transaction handlers.
   (c) We already have a transaction pipeline (post-H3.1); upgrading it to first-class `Reaction` objects with explicit ordering would help. Don't redo the request/command layer — our `Transaction` is fine.
   (d) Effort: 1 week (just the reaction surface); risk: low if additive.

3. **`extension SuperEditorRobot on WidgetTester` + Inspector split** (medium impact, low disruption).
   (a) See section 7. (b) Tests become readable; lowers cost of writing regression tests for the mobile drag bugs we keep hitting. (c) Add a new `test/` lib export, no production code changes. (d) Effort: 3-5 days; risk: ~zero.

4. **`DragHandleAutoScroller` as a reusable component + handle drag state on a `ValueNotifier` in an `InheritedWidget` controls scope** (medium impact, medium disruption).
   (a) Single auto-scroll class shared by iOS+Android interactors; `handleBeingDragged` lives on an `IosControlsController` consumed by overlay widgets.
   (b) Pulls handle state out of the gesture detector's `setState`, eliminating the rebuild storm during drag. Direct parallel to the "yavaşla-hızlan" symptom in our `MEMORY.md`.
   (c) Extract our `_pan.dragMode` and auto-scroll into sibling classes; have overlays listen via `ValueListenableBuilder`.
   (d) Effort: ~1 week; risk: medium — touches the iOS drag path that already has known bugs.

5. **Typed view models per block (`SingleColumnLayoutComponentViewModel` subclasses) replacing `attributes: Map<String, dynamic>` for render-time props** (medium impact, high disruption).
   (a) `TaskComponentViewModel`, `ImageComponentViewModel`, etc. are concrete classes; the styling pipeline copies + mutates them.
   (b) Removes one whole class of typo bug (`'text_align'` vs `'textAlign'`) at the rendering layer without forcing a model-layer rewrite.
   (c) Each block builder grows a typed `ViewModel` class. The on-disk `Map<String, dynamic>` stays for serialization.
   (d) Effort: 2+ weeks across blocks; risk: medium. Could be done incrementally per block type.

## 9. Patterns we should NOT borrow

- **Flat node list, no tree**. We have nested toggle lists, callouts, columns, and tables-with-row-children. super_editor would model these as sibling nodes with indent metadata, which is strictly worse for our use cases. Don't flatten.
- **`SingleColumnDocumentLayout` rendering everything in one big `Column`**. We use `super_sliver_list`; their layout doesn't virtualize and they pay for it on long docs. Keep our sliver root.
- **Backend-agnostic posture / no document persistence**. Their "plug yours in and go" means users wire their own save layer; we have an opinionated `Document` lifecycle tied to AppFlowy collab. Don't strip that.
- **Per-platform "Controls" `InheritedWidget` proliferation** at full scale (separate iOS/Android/Mac scopes). Borrow the pattern for handle drag state only; don't fragment unrelated state across N scopes.
- **`SuperEditorContext` as the universal arg to every action**. We have a god-object split (H3.1); re-bundling everything into one ctx undoes that win. Keep mixin composition; pass only what each action needs.
- **License**: super_editor is MIT, compatible — no issue, but their bug surface is theirs to debug; transplanting code wholesale means inheriting it.

## 10. Open questions

1. Does `SingleColumnLayoutPresenter`'s phase cache invalidate by `nodeId` granularity or by document-version? (Determines whether the "selection-as-style-phase" pattern actually buys us per-block render skipping at our scale.) — Need to read `_presenter.dart` invalidation logic line-by-line.
2. How does super_editor handle nested editable regions (e.g. a code block with its own selection)? They have `super_textfield` separately; do they ever nest editors? Our tables embed editors inside cells.
3. What does the `reactionPipeline` cost per transaction in practice — is there a "skip reactions for IME composing-only changes" path? (Relevant to our mobile-keyboard-fix work on this branch.)
4. Drag-handle auto-scroll: does `DragHandleAutoScroller` interact with `super_sliver_list`-style sliver virtualization, or only with their non-virtualized column? If only the latter, the pattern needs adaptation, not transplant.
5. The robot tests — do they work under `golden_toolkit`/`alchemist`? Or are they pure `flutter_test`? Determines reuse cost for us.

---

References (all paths under `superlistapp/super_editor`):
- `super_editor/lib/src/core/{editor,document,document_composer,document_layout,edit_context}.dart`
- `super_editor/lib/src/default_editor/{super_editor,document_caret_overlay,document_gestures_touch_ios,document_gestures_touch_android,document_hardware_keyboard/document_keyboard_actions}.dart`
- `super_editor/lib/src/default_editor/layout_single_column/{_presenter,_styler_user_selection,_styler_per_component,_styler_composing_region,layout_single_column}.dart`
- `super_editor/lib/src/test/super_editor_test/{supereditor_robot,supereditor_inspector,supereditor_test_tools}.dart`
