# AppFlowy Editor — Konsolide Durum & Roadmap

> İlerledikçe `- [ ]` → `- [x]` yap (render'da otomatik üstü çizilir).
> Tarih: 2026-05-26 — Branch: `feat/super-sliver-list-and-mobile-keyboard-fix`

## Tek Cümle Özet

Çekirdek motor (transaction/operation modeli, block component registry, shortcut sistemi, sliver virtualization) sağlam; ama paket bir "ürün içi modül" gibi paketlenmiş — public API'de sızıntılar, CI'da yalancı yeşil, `EditorState` god-object'i, mobile/desktop dallanma derinde geç olduğundan selection drag stutter'ın kök nedeni hâlâ açık, README pub.dev'de kırık, upstream bus-factor=1.

## Sağlık Skoru

| Boyut | Skor | Not |
|---|---|---|
| Mimari temeller | 8/10 | Transaction, registry, Selectable interface güçlü |
| Test kapsamı | 7/10 | 210 dosya / ~910 case — sayısal iyi, image block / selection drag / mobile integration boş |
| CI güvenilirliği | 6/10 | analyze/format gerçek gate (H1.1), example APK build gate (H1.4), leak gate notDisposed-only; iOS build + emulator integration test hâlâ yok, codecov upload informational |
| Public API kalitesi | 4/10 | `src/...` 157 yerde sızıntı, 14+ deprecated, barrel'da iç dosyalar |
| Mobile UX | 5/10 | Bilinen drag stutter, 985-satır tek dosya, global mutable flag'ler |
| Performans | 6/10 | Sliver var, table'da yok, selection notify cascade baseline'ı yükseltiyor |
| Dokümantasyon | 4/10 | README lorem-ipsum'la kırık, dartdoc seyrek, UPGRADING.md 8 satır |
| Maintenance | 4/10 | Upstream bus-factor=1, 2025'te 2 ay commit yok, 31 branch (çoğu çöp) |

---

## Güçlü Yanlar (özet)

- Operation/Transaction disiplini — JSON-serileştirilebilir mutasyonlar (`lib/src/editor_state.dart:453`, `lib/src/core/transform/transaction.dart`)
- Block component plug-in modeli (`BlockComponentBuilder` + `BlockComponentConfiguration`)
- Shortcut çift katmanı — `CharacterShortcutEvent` (IME-aware) vs `CommandShortcutEvent` (platforma duyarlı)
- Sliver virtualization root listede (`super_sliver_list`, `page_block_component.dart:158`)
- Codec mimarisi `dart:convert`-idiomatic (markdown/HTML/Quill Delta/PDF)
- Test piramidi sayısal iyi: 210 dosya, ~910 case, lib/test oranı 0.57, lib'de TODO sayısı sadece 7
- Analyzer agresif — `awesome_lints` + 4 custom_lint + trailing comma
- i18n: 22 ARB dil dosyası
- Selection/highlight/remote ayrı notifier'larda

---

## Kritik Zayıflıklar (önem sırasına göre)

### P0 — Hemen düzeltilmeli

- ~~CI gerçek bir kapı değil — `analyze`/`format`/`custom_lint`/codecov'de `continue-on-error: true`~~ → çözüldü: `26dc3bde` (analyze/format gerçek gate), `339c2997` (custom_lint/awesome_lints kaldırıldı), codecov upload bilerek informational
- ~~README pub.dev'de patlamış — `README.md:146` sonrası ~520 satırlık markdown-it lorem-ipsum fixture~~ → çözüldü: `052934b5`
- Tek Flutter sürümü (3.44.0), iOS/Android emulator CI job yok (H1.6 defer — integration_test stub'a bağlı), iOS APK example_build da disabled (`65d1e6db` — device_info_plus iOS 17 selector sorunu, Podfile deployment target bump'ı gerek)

### P1 — Yapısal risk

- **Selection drag stutter — 2026-05-26 iki ajanlı incelemesi sonrası revize:**

  Önceki zincir 5 maddeydi; doğrulamada **3'ü stale, 1'i non-issue, 1'i verified-and-amplified** çıktı. Yeni framework:

  - ~~PVN setter always-broadcast~~ → **Non-issue for drag.** PVN sınıfı evet hâlâ unconditional notify ediyor (`lib/src/editor/util/property_notifier.dart:24-27`, path roadmap'te yanlıştı), AMA H2.1 guard `selection_style_mixin.dart`'da call-site'da çalışıyor. Drag'de her tick unique selection üretiyor → guard zaten by-pass. Sınıfa equality guard koymak başka path'leri (paragraph_block_component, word_counter) korur ama drag'i çözmez.
  - ~~N block × 2 widget rebuild~~ → **Yanlış sayı: 3N + 1N.** `BlockSelectionContainer` her text node için **3× `BlockSelectionArea` (selection + cursor + selection-with-cursor) + 1× `BlockHighlightArea`** mount ediyor. Per-block 12 callback + 4 widget rebuild per notify.
  - ~~Per-frame self-reschedule~~ → **STALE — H2.2 fixledi.** `block_selection_area.dart` ve `block_highlight_area.dart` `_scheduleUpdate`'i `_updatePending` flag ile coalesce ediyor; self-reschedule yok. Roadmap satır numaraları H2.2 öncesinden.
  - ~~`_updateSelectionDuringDrag` 2-3 post-frame deep~~ → **STALE.** Method `mobile/mobile_selection_auto_scroller.dart:58-107`'e taşınmış, sadece autoscroll tick'inde fire. Pan-tick hot path **post-frame-flat** (1 deep), 2-3 değil.
  - **VERIFIED ve daha kötü — gerçek kök neden:** Her selection notify, dokümandaki **her** bloğu uyandırıyor (root sliver virtualization sadece görünür range'i çiziyor ama element tree tam mount). 200-bloklu doc'ta:
    - **3N = ~600 `ValueListenableBuilder` invocation per notify**
    - Builder içinde `selection.normalized` **iki kez** çağrılıyor (her seferinde allocation), `path.inSelection(selection)` çalışıyor
    - 60 fps drag → **~36k builder invocation + ~72k Selection allocation/sec** → GC pressure → "fast then stutter" pattern tam olarak bu

  **İkincil burner'lar:**
  - `HighlightAreaPaint`, rect değiştiğinde 150ms easing animasyonunu `_controller.reset() + _forward()` ile yeniden başlatıyor → drag boyunca sürekli CPU/GPU burn (`block_highlight_area.dart:370-379`).
  - `updateSelectionWithReason` her uiEvent çağrısında `Completer<void>` + `addPostFrameCallback` allocate ediyor; mobile drag path'i await etmiyor → pure waste (`selection_style_mixin.dart:118-124`).
  - Her area iki ayrı listener kaydediyor (`_scheduleUpdate` + `_clearCursorRect`); `_clearCursorRect` her notify'da `prevCursorRect = null` yapıp kendi short-circuit'ini defeat ediyor (correctness bug + 2× listener call).
  - `mobile_selection_service.updateSelection` per drag-tick iki kez notify ediyor (`currentSelection.value =` + `selectionNotifier`).
  - Android `onLongPressMoveUpdate` her tick `HapticFeedback.lightImpact()` çağırıyor (platform-channel hop).

  **Fix sırası (azalan etki — H2.3 olarak konuşlanıyor):**
  1. **Derived listenable per area** — state'te `(bool inSelection, List<Rect>? rects, Rect? cursor)` cache; builder local notifier'ı dinlesin. Out-of-selection bloklar transition-out frame'i hariç hiç rebuild olmasın. Hedef: **3N → ~9 builder/notify (~%95 düşüş)**, allocation pressure aynı oranda azalır.
  2. **`HighlightAreaPaint` drag-gate** — `selectionExtraInfo[selectionDragModeKey] != none` ise 150ms easing'i skip et, snap'le.
  3. **`updateSelectionWithReason` completer skip** — `awaitLayout: false` parametresi ekle, mobile gesture strategy'ler drag tick'inde set etsin.
  4. **`_clearCursorRect` fold** — separate listener'ı sil, `_updateSelectionIfNeeded` içine fold et (sadece path değiştiğinde clear). Hem perf hem correctness fix.

  Önce H1.8 cascade test'ini extend et (3N → 9 ölçümünü regression gate olarak yakala), sonra fix #1 → #2 → ölçüm, fix #3 + #4 ayrı session.
- ~~`EditorState` god-object (~915 satır)~~ → 425 satıra indi (H3.1 mixin split büyük ölçüde tamam). Kalan: apply pipeline + documentRules + query helpers facade'de duruyor — H3.1 backlog'una bak.
- `lib/src/service/` (eski) ve `lib/src/editor/editor_component/service/` (yeni) çakışıyor — hangisi canonical belirsiz
- `package:appflowy_editor/src/...` 157 yerde içeriden — refactor'da sessizce kırılır
- ~~`MobileSelectionService` 985 satır~~ → 462 satır (H3.3 split tamam). Kalan 2 global mutable flag: `disableMagnifier`, `disableIOSSelectWordEdgeOnTap` — H3.3 backlog.
- `selectionExtraInfo` tipsiz `Map?` + `dragMode.toString() != 'MobileSelectionDragMode.none'` string karşılaştırması
- Toolbar/Selection v1+v2 koexistansı — `mobile_toolbar` + `_v2` ikisi export'ta

### P2 — Performans hot spot'ları

- Table'da virtualization yok — `TableCol._buildCells` tüm hücreleri build, cell başına `addListener` + `addPostFrameCallback` ile `updateRowHeight` transaction storm — `lib/src/editor/block_component/table_block_component/table_col.dart:97-137`
- `TableDefaults.colWidth` static mutable — multi-instance kirleniyor
- `Node.notifyListeners` parent'a cascade — root'a kadar yayılıyor — `lib/src/core/document/node.dart:194,202,239,263,290,303,321`
- `AppFlowyEditor` root `Overlay` — keyboard show/hide'da viewInsets relayout
- iOS magnifier `BackdropFilter` — pan-update başına GPU blur cost

### P3 — Feature parity / DX boşlukları

- Markdown encode'da `column`/`columns` yok, decode'da code block yok
- HTML encoder farklı feature matrix
- Quill Delta yalnız encoder — README "create from Quill Delta" diyor, yanlış (decoder yok)
- `ToolbarItem` API'sinde `builder` + `iconBuilder` + `handler` + `itemBuilder` + deprecated `type`
- Theming ThemeData-aware değil — dark mode için 209 satır manuel kod
- Schema/mark/decoration API'leri yok — `Map<String, dynamic>` typo-prone
- Slash menu tek katmanlı, kategorisiz
- CONTRIBUTING.md / PR template yok, UPGRADING.md 8 satır
- `editor.dart` 25+ parametre / 130 satır dartdoc, `block_component.dart` 0 dartdoc
- `test/legacy/` ve `test/new/` paralel duruyor

### Stratejik

- Upstream bus-factor=1: 6 ayda 14 commit, %85'i Lucas'tan, 2025-08 + 2025-09 commit yok

---

## ROADMAP

### Horizon 1 — Quick wins (1–2 hafta)

Hedef: yalancı sinyalleri kapat, ilk izlenimi düzelt, ölçüm altyapısını kur.

- [x] **H1.1** CI'da `continue-on-error: true` flag'lerini düşür (analyze/format/custom_lint) — `.github/workflows/test.yml:50,54,58,65` — Etki: Yüksek / Çaba: XS → `26dc3bde` (codecov upload'unda flag korundu — upload hatası gate değil)
- [x] **H1.2** `README.md:146` sonrasını sil; gerçek "Getting Started" + "Examples" bölümü yaz — Etki: Yüksek / Çaba: XS → `052934b5` (minimum müdahale: mevcut Getting Started/Customizing/Migration satırları korundu, sadece 520 satırlık markdown-it fixture silindi)
- [x] **H1.3** `CONTRIBUTING.md` ve `.github/PULL_REQUEST_TEMPLATE.md` yaz — Etki: Orta / Çaba: XS → `89cb3337`
- [x] **H1.4** `example/` uygulamasını CI'da `flutter build apk --debug` ile derle — Etki: Orta / Çaba: S → `89cb3337` (APK gate aktif). iOS build matrix'ten düşürüldü → `65d1e6db` — device_info_plus 12.4.0 iOS 17+ selector'ları (`isiOSAppOnVision`) `@available` guard'sız kullanıyor, `example/ios` deployment target 13.0. Çözüm: `IPHONEOS_DEPLOYMENT_TARGET` bump'ı + Podfile/Runner.xcodeproj güncellemesi sonrası geri ekle.
- [x] ~~**H1.5** `awesome_lints`'i `ref: <commit-sha>`'ya pinle~~ → Tamamen kaldırıldı (awesome_lints + custom_lint pubspec'ten, custom_lint adımı CI'dan, custom_lint bloğu analysis_options'tan)
- [ ] **H1.10** `very_good_analysis`'e aşamalı geçiş (denendi: 6589 issue + 100+ error patlıyor, strict-casts/inference/raw-types yüzünden). Plan:
  1. `dart fix --apply` ile auto-fix (prefer_single_quotes ~1582, prefer_final_locals ~149, omit_local_variable_types ~327)
  2. `strict-raw-types: true` aç + gelen warning'leri düzelt
  3. `strict-inference: true` aç + düzelt
  4. `strict-casts: true` aç + düzelt (en zoru — `Node.attributes` dynamic döner, çoğu yerde cast eklemek gerek)
  5. `public_member_api_docs` aç (dokümantasyon sprint'i, 2079 yer)
  6. flutter_lints'i kaldırıp very_good_analysis'i tek `include` olarak koy
- [ ] **H1.6** iOS/Android emulator CI job'larını geri ekle (yorum satırı duruyor) — Etki: Yüksek / Çaba: M / Risk: Orta (flaky)
  - **Defer (2026-05-25)**: Historical commented-out job'lar emulator'ı gerçekten kullanmıyordu; sadece `flutter test test/mobile` koşuyorlardı. Bu zaten yeni `desktop` matrix'inde (ubuntu+macos) tam test suite ile koşuyor. Gerçek emulator gate için `integration_test/` setup'ı gerekiyor — şu an yok. H4 backlog'unda "integration_test stub" eklenince anlamlı, ondan önce sadece redundant CI minutes.
- [ ] **H1.7** `test/legacy/`'i `new/` ile birleştir ya da sil — Etki: Düşük / Çaba: S
- [x] **H1.8** **Selection-cascade benchmark testi**: 200 paragraph dokümanda bir selection set'inin kaç `notifyListeners` + `build` tetiklediğini sayan widget testi (H2'nin regresyon kapısı, ölçüm) — Etki: Yüksek / Çaba: S → `5f667148`
- [ ] **H1.9** 31 branch'ten eski release/feature dallarını arşivle (tag bırak, sil)

#### Bonus CI işleri (roadmap dışı, yapıldı)

- [x] CI tetikleyicileri genişletildi: `feat/**` push + `workflow_dispatch` → `d4161fa8`
- [x] `actions/checkout@v4` (Node 20 deprecation fix) → `50328a6c`
- [x] Commitlint sadece HEAD commit + informational (history rewrite gerektirmesin diye) → `0d4dad06`
- [x] Leak test gate stabilizasyonu: `gcedLate` timing-noise düşürüldü, untrackable upstream/singleton leak'leri ignore'a alındı → `d7c43bf9`, `550e2099` (sonraki adım: gerçek leak'leri tek tek kapat, ignore list'i daralt)

### Horizon 2 — Selection stutter kök neden (2–6 hafta)

Hedef: auto-memory'deki "yavaşla-hızlan" pattern'ini *ölçerek* kapat.

- [x] **H2.0** Profil al — gerçek-cihaz log'u toplandı (`example/lib/util/stutter_logger.dart`'tan adb logcat çıktısı). Android Pixel-class, 200-paragraf doc. Baseline ve fix-sonrası karşılaştırma H2.3 zincirinde kayıt altında. → `851b5a58` (stutter logger), iterative drag testleri.
- [x] **H2.1** `PropertyValueNotifier`'ı opt-in `alwaysNotify`'a çevir; `selectionNotifier` için eşitlik kontrolü ekle — `lib/src/property_notifier.dart` — Etki: Yüksek / Çaba: S / Risk: Orta (bazı listener'lar layout-dirty broadcast'ine bel bağlamış olabilir) → `dc84c0bb`
- [x] **H2.2** `BlockSelectionArea._updateSelectionIfNeeded` self-reschedule chain'ini kır; layout-dirty sinyaline bağla — `block_selection_area.dart:230-232` + `block_highlight_area.dart:267-269` — Etki: Yüksek / Çaba: M → `cae7d87b`
- [ ] ~~**H2.3** `mobile_selection_service._updateSelectionDuringDrag` içindeki nested post-frame'leri tek frame'e indir~~ → **STALE.** Method auto-scroller'a taşınmış, pan-tick hot path zaten post-frame-flat. Yerine aşağıdaki H2.3.0-f kalemleri (P1 stutter notlarındaki ajan bulguları). 2026-05-26.
- [x] **H2.3.0** H1.8 cascade test'i 200-block doc'a extend edildi: BSA/BHA debug counter + baseline ölçüm. Pre-H2.3.a synthetic: BSA=108, BHA=2/notify (viewport-bounded, doküman değil). → `3f38c269`
- [x] **H2.3.a** **Derived listenable per BlockSelectionArea/BlockHighlightArea.** State'te `_BlockSelectionPaint`/`_BlockHighlightPaint` cache; builder local notifier'ı dinliyor. Synthetic: BSA 108 → **3 builder/notify (~%97 düşüş)**. → `7316c175` (BSA), `5714b18e` (BHA)
- [x] **H2.3.b** **`HighlightAreaPaint` auto-snap** — `_controller.isAnimating` ise 150ms easeOut skip, snap'le. Drag/TTS gibi continuous update'ler tween reset yığmıyor. → `d6145d66`
- [x] **H2.3.c** **`updateSelectionWithReason` Future return drop** — `Future<void>` → `void`, 33 caller'ın hiçbiri await etmiyordu, her uiEvent call'da `Completer` + `addPostFrameCallback` allocation pure waste. → `bbf401bf`
- [x] **H2.3.d** **`_clearCursorRect` fold** — separate listener silindi, H2.3.a refactor'una gömüldü (yeni paint notifier zaten short-circuit ediyor). → H2.3.a commit'leri içinde.
- [x] **H2.3.e** **AutoScroller cursor-mode selection ping-pong fix** — `_updateSelectionDuringDrag` cursor mode'da `Selection.collapsed(end)` yazıyor, Strategy ise word-boundary extended; iki path her tick'te birbirini eziyordu. AutoScroller cursor mode'da `return` (sadece scroll, selection'a karışmaz). **Gerçek-cihaz**: per-tick notify 2 → 1, dt ping-pong (30↔1ms) kayboldu. → `edc73051`
- [x] **H2.3.f** **Android cursor-drag IME spam suppression** — Android stratejisi `onLongPressMoveUpdate`'te `selectionExtraInfoDoNotAttachTextService: dragMode == cursor` flag'i set etmiyordu (iOS pattern'i atlamıştı). Her drag tick'i `showSoftInput` + `requestFocus` platform-channel hop'u → ~20-30ms frame. **Gerçek-cihaz fix sonrası**: frame >16ms tick oranı 6/13 → 2/16, ortalama frame ~17ms → ~9ms. → `9b96c8a0`
- [x] **H2.3.g** Auto-scroll new-block mount spike kovalandı → H2.8 olarak detaylandırılıp shipped (aşağıya bak).
- [ ] **H2.4** iOS Magnifier'ı `BackdropFilter`'sız variant ile A/B test et; ölçüm darboğazsa default'u değiştir — Çaba: S
- [x] ~~**H2.5** `_AndroidDragHandle.onPanUpdate`'teki `HapticFeedback.selectionClick` yalnız selection karakter değiştiğinde tetiklensin~~ → **ALREADY DONE**. Guard 2024-01-05'te `7d2b456e` ile eklenmiş (`mobile_basic_handle.dart:343` `if (this.selection != selection)`). `Selection.==` deep comparison ile çalışıyor. iOS handle'da haptic hiç yok (iOS convention). ROADMAP item stale'di. 2026-05-26 verified.
- [ ] **H2.6** Her PR sonrası H1.8 benchmark'ı koş ve sonuçları PR'a yapıştır
- [ ] **H2.7** H1.8 benchmark'ına drag-simulation senaryosu ekle (regresyon koruması)

#### H2.9 — Mobile gesture / handle hygiene (2026-05-26 ajan bulguları)

EditorRobot test-infra genişlemesi sırasında (`d7cfb070`) iki ajan paralel inceleme yaptı, mobile gesture path'inde 3 pre-existing risk surface'i tespit etti. Hiçbiri shipped fix bug değil — birikmiş hijyen.

- [ ] **H2.9.a** `mobile_basic_handle.dart:10-12` — `_leftHandleKey` / `_rightHandleKey` / `_collapsedHandleKey` **top-level mutable GlobalKey**. **Defer'd 2026-05-26.** Teorik foot-gun: iki side-by-side editor + ikisinde iOS platform + ikisinde collapsed cursor visible olunca duplicate-GlobalKey atar. Production'da `HandleType.collapsed.key.currentContext` iOS floating-cursor path'inde kullanılıyor (`delta_input_on_floating_cursor_update.dart:27,57`); refactor instance-scoped key + editorState wiring gerektirir. iOS hardware keyboard rig olmadan fix testlenemez. Multi-pane usage gerçekten ortaya çıkana kadar defer.
- [x] ~~**H2.9.b** iOS `onLongPressStart` `dragMode` publish etmiyor~~ → **VERIFIED-NOT-AN-ISSUE**. iOS path `editorState.updateSelectionWithReason`'ı doğrudan değil, wrapper `_MobileSelectionServiceWidgetState.updateSelection` üzerinden çağırıyor (`mobile_gesture_strategy_ios.dart:76`); o da `selectionDragModeKey: _pan.dragMode`'u extraInfo'ya ekliyor (`mobile_selection_service.dart:211`). Cihaz log'u doğruladı: `extraInfo={selection_drag_mode: MobileSelectionDragMode.cursor, selectionExtraInfoDoNotAttachTextService: true}`. Regression gate: `test/performance/mobile_drag_handle_test.dart` iOS long-press testi assertion ile lock'lı (`d7cfb070` sonrası eklenti). Kalan asimetri (Android `disableFloatingToolbar: true` set ederken iOS etmiyor) ayrı bir hijyen kalemi — `H2.9.b'` olarak takip et eğer gerekirse.
- [x] ~~**H2.9.c** iOS `onLongPressMoveUpdate` globalPosition direct, Android'in delta-math'ı yok~~ → **VERIFIED-NOT-AN-ISSUE**. (a) `pan.dragMode = cursor` `onLongPressStart` line 67'de erken-return'den ÖNCE set ediliyor; ajan'ın "unset" iddiası yanlış. (b) iOS'un `globalPosition` direct kullanması Android'in word-boundary extend logic'inden farklı, *by-design* — iOS collapsed-cursor-drag, Android word-extend-drag. Semantic ayrım, bug değil. 2026-05-26 verified by code read.

#### H2.8 — Auto-scroll new-block mount spike (2026-05-26)

**Sorun**: Drag sırasında viewport'a yeni block girince 26-31ms frame spike. İki ajan paralel araştırma + 6 fix denemesi + 2 revert. Test-first methodoloji: synthetic baseline → hipotez doğrula → device test → ship veya revert.

- [x] **H2.8.a** `super_sliver_list` precalc'ını drag boyunca kapat → çift-mount (temp + real) maliyeti iptal. Cihazda marjinal düşüş. → `a53cb343`
- [x] **H2.8.b** Android `onLongPressStart`'a `selectionExtraInfoDoNotAttachTextService: true` ekle → drag-start IME re-attach spike (31ms) kayboldu. → `b73a03fd`
- [x] **H2.8.c** `BlockComponentStatefulWidget.cachedLeft` postFrame `setState` skip when `decoration == null` → N+1 forced relayout cycle bitti. **Ana kazanç**: auto-scroll mount 25-30ms → 5ms. → `db860f06`
- [x] **H2.8.d** `_buildPlaceholderText` empty-delta skip → **REVERTED**. Synthetic %50 düşüş (50→25 RichText) ama cihazda noisy, peak spike azalmadı. Test-first methodoloji devreye girdi.
- [x] **H2.8.e** BSA/BHA `initState` postFrame skip when path-not-in-selection → 180 → 0 closure schedule per editor mount. Cihazda max frame 18ms → 14ms, sıfır budget aşımı. → `da70df70`
- [x] **H2.8.f** `confirmContextEnabled` skip when no `textSpanOverlayBuilder` → **REVERTED**. Synthetic 36 → 0 setState ama cihazda 36ms spike çıktı (yeni hot path açıyor). Methodoloji gereği geri alındı.

**Sonuç**: 4 shipped, 2 reverted. Real-device drag stutter görsel olarak smooth — frame budget aşımları %60 → %5'in altı.

**Test-first methodoloji öğrendikleri**:
- Synthetic-only metrik (widget count, schedule count) cihaz frame time'ına otomatik translate olmuyor.
- Bazı "subtraktif" görünen değişiklikler beklenmeyen hot path açıyor (H2.8.f: confirmContextEnabled kaldırınca 36ms spike).
- Per-fix iki-aşamalı verification (synthetic + device) noisy single-sample karşılaştırmaları kırpıyor.

**super_editor research** (2026-05-26):

İki ajan paralelde inceledi. Raporlar: `docs/super_editor_perf_research.md` + `docs/super_editor_arch_research.md`. → `29fb0cfd`

**Tactical patterns** (H3 backlog için aday):
- **Presenter pipeline + per-node diff** — bizim H2.3.a derived-paint notifier'ın yapısal eşi. Daha geniş scope (sadece selection değil, tüm node attr changes).
- **`ContentLayers` RenderObjectWidget** — selection/caret layer'ları content rebuild'inden ayrıştırıyor. Bizim 5-widget-per-block BlockSelectionContainer'ın yapısal alternatifi.
- **`_RebuildOptimizedSuperTextWithSelection`** — SuperText cache, selection ayrı ValueNotifier→CustomPainter. `confirmContextEnabled` + `_buildPlaceholderText` problemlerinin doğru fix shape'i.
- **`BlinkController.withTimer`** — `Ticker` 60fps force eder (FBH #1253). `_HighlightAreaPaintState` always-on AnimationController için ders.
- **`LayoutAwareRichText.onMarkNeedsLayout`** — paragraph cache invalidate, painter stale layout okumaz.

**Architectural patterns** (H3 sub-aday):
- **Selection as style phase + document-level overlay caret** — bizim 5-widget-per-block container'ın yapısal alternatifi.
- **Editor pipeline (Request → Command → Reaction → Listeners)** — markdown shortcuts, autolink, spellcheck için first-class plug-in point.
- **`DragHandleAutoScroller` reusable class** — iOS+Android paylaşımlı.
- **`SuperEditorRobot` testing extension** — `placeCaretInParagraph`, `pressDownOnCollapsedMobileHandle`. **Steal-verbatim aday**.

**Don't copy notları**:
- super_editor flat node sequence — bizim tree avantajımız (nested toggle/table/callout).
- super_editor virtualize etmiyor; `super_sliver_list` doğru karar.
- `BuildOwner.onBuildScheduled` global hook fragile (hot reload/multi-window).
- `Map<String, dynamic>` metadata — super_editor'da da çözülmemiş; typing kazancı view-model layer'da.

### Horizon 3 — Mimari refactor (2–4 ay)

#### H3.1 — `EditorState`'i dağıt (Etki: Yüksek / Çaba: L / Risk: Orta)

**Durum (2026-05-26):** `editor_state.dart` 915 → **425 satır**. Library-private mixin'lere bölündü (`_EditorChromeMixin`, `_HistoryMixin`, `_SelectionStyleMixin`, `_TransactionPipelineMixin`, `_ScrollCoordinatorMixin`, `_EditorServiceMixin`, `_TableOfContentsMixin`). Facade `abstract class _EditorStateBase` üzerinden composed.

**Durum 2026-05-26 (revize):** `editor_state.dart` 915 → **323 satır**. H3.1 effectively done — facade artık küçük + mantıksal olarak compose layer + apply pipeline'dan ibaret. Hedef "150-200" tamamen ulaşılmadı ama apply pipeline'ın facade'de kalması intentional (transaction record/undo ile iç içe, mixin'e bölmek karmaşıklık katar). Kalan iki kalem (apply pipeline mixin, type-safe extraInfo) **defer'd** — H3.4 breaking change penceresi açıldığında değerlendir.

- [x] `HistoryController` çıkar → `_HistoryMixin`
- [x] `EditorChrome` çıkar → `_EditorChromeMixin`
- [x] `StyleController` çıkar → `_SelectionStyleMixin` (selection + highlight + toggledStyle)
- [x] `TransactionPipelineMixin` (broadcast + content-based dirty hash + `isDirtyNotifier`/`markClean()`)
- [x] `TableOfContentsMixin` — reactive outline (`TocEntry`, `tableOfContents` ValueListenable, microtask-coalesced recompute) + `jumpToTocEntry`
- [x] `_DocumentQueryMixin` — `getNodesInSelection`, `getSelectedNodes`, `getNodeAtPath` (e2851479)
- [x] `_DocumentRulesMixin` — `documentRules` setter + `_asyncObserver` subscription. Note: `on _EditorStateBase` clause döner ki "this-cast gymnastic'ini engeller" — pratikte circular superinterface error verir, abstract-getter pattern kullanıldı (1edf0148).
- [x] `UndoManager` taşı `lib/src/history/` → `lib/src/editor_state/` (0c011fe4)
- [x] `EditorState` cephesini koru — mixin'ler `_` prefix'li, downstream API kırılmadı

**Defer'd (H3.4 breaking penceresi ile birlikte revisit):**

- [ ] `apply()` + `_applyTransactionInLocal` + `_applyTransactionFromRemote` (~150 satır) → `_TransactionApplyMixin`. **Defer**: Apply pipeline transaction record/undo'yla iç içe; mixin'e ayırmak karmaşıklık ekler, ROI düşük. Mevcut konum okunabilir.
- [ ] `selectionExtraInfo` Map → type-safe `SelectionExtraInfo` field. **Defer**: Breaking change, H3.4 ile aynı major'da.
- [ ] Query helpers (`getNodesInSelection`, `getSelectedNodes`, `getNodeAtPath`, ~95 satır) → `_DocumentQueryMixin`. Etki: Düşük / Çaba: S
- [ ] `selectionExtraInfo` Map → type-safe `SelectionExtraInfo` field (setter da). `SelectionExtraInfo.from(Map?)` zaten var; setter Map kalıyor. **Breaking** — H3.4 ile aynı major'a sıkıştır. Etki: Orta / Çaba: S / Risk: Yüksek (breaking)
- [ ] `SelectionController` çıkar (selectionNotifier + highlightNotifier + tapNotifier + remoteSelections + dragMode + extraInfo type-safe) — roadmap'in orijinal niyeti. Kısmen `_SelectionStyleMixin` ve type-safe extra info maddeleriyle örtüşüyor; bu kalemi *birleşik selection refactor* olarak tut.

#### H3.2 — `service/` çift katmanını birleştir (Etki: Yüksek / Çaba: M / Risk: Düşük)

- [ ] `lib/src/service/copy_paste_handler.dart` → modern `copy_paste_extension.dart` ile birleştir
- [ ] `lib/src/service/internal_key_event_handlers/` → modern `keyboard_service/` altına taşı
- [ ] `lib/src/service/selection/` → modern `selection_service`'e birleştir
- [ ] `lib/src/service/context_menu/` taşı
- [ ] Eski katmanlardan deprecated forward bırak, bir major sonra sil

#### H3.3 — Mobile/desktop composition (Etki: Yüksek / Çaba: L / Risk: Orta)

**Durum (2026-05-26):** `mobile_selection_service.dart` 985 → **462 satır**. Split büyük ölçüde tamam — kalan 462 satır esas widget'ın kendisi (state + public SelectionService API + gesture callbacks), daha fazla bölmek diminishing returns.

- [x] `MobileSelectionService` split:
  - `MobileSelectionAutoScroller` ([selection/mobile/mobile_selection_auto_scroller.dart](lib/src/editor/editor_component/service/selection/mobile/mobile_selection_auto_scroller.dart))
  - `MobileGestureStrategy` (iOS + Android implementations)
  - `MobileSelectionOverlays` (handles + cursor overlay)
  - `PanDragState`
  - `MobileMagnifier` ([selection/mobile_magnifier.dart](lib/src/editor/editor_component/service/selection/mobile_magnifier.dart))
  - `MobileHighlightService` (ayrı dosya)
- [x] `mobile_toolbar_v1` kaldırıldı — sadece `mobile_toolbar_v2.dart` kaldı (rename `_v2` suffix'inden kurtulmak cosmetic backlog)
- [x] `appFlowyEditorOnTapSelectionArea` + `keepEditorFocusNotifier` global flag'leri taşındı/kaldırıldı

**Kalan iş:**

- [ ] `SelectionServiceWidget` build içi `if (PlatformExtension.isDesktopOrWeb)` ([selection_service_widget.dart:46](lib/src/editor/editor_component/service/selection_service_widget.dart#L46)) — tek if-branch ama hâlâ açık. Desktop/Mobile ayrı widget olup host PlatformExtension'a göre seçer. Etki: Orta / Çaba: S / Risk: Düşük
- [ ] Kalan 2 global mutable flag → instance-scoped `MobileSelectionConfig`:
  - `bool disableIOSSelectWordEdgeOnTap` ([mobile_selection_service.dart:26](lib/src/editor/editor_component/service/selection/mobile_selection_service.dart#L26))
  - `bool disableMagnifier` ([mobile_selection_service.dart:33](lib/src/editor/editor_component/service/selection/mobile_selection_service.dart#L33))
  Etki: Orta / Çaba: S / Risk: Orta (breaking — downstream tüketiciler global'e bel bağlamış olabilir)
- [ ] `selectionExtraInfo` Map → type-safe (H3.1 ile birleşik kalem, oraya bakın)
- [ ] Cosmetic: `mobile_toolbar_v2.dart` → `mobile_toolbar.dart` rename + `_v2` tip suffix'lerini kaldır. Etki: Düşük / Çaba: XS

#### H3.4 — Public API daralt (Etki: Yüksek / Çaba: M / Risk: Yüksek — breaking)

- [x] **Phase 1** — İç `package:appflowy_editor/src/...` import'larını relative'e çevir. **92 dosya / 182 import** rewrite, analyze + 996/996 test temiz. Commit `959f36bd`.
- [x] **Phase 2-3** — Sub-library'lere böl: `core.dart`, `blocks.dart`, `plugins.dart`, `mobile.dart`. Main barrel artık alt-kütüphanelere delegate ediyor (geriye uyumlu). Bölümlere ayrılmış import sections.
- [ ] **Phase 4** — Deprecated API'leri kaldır (kalan: `databaseIndex` family — constructor param + field + `toJsonIndexed`)
- [ ] **Phase 5** — `UPGRADING.md`'yi gerçekten doldur (sub-library'lere geçiş rehberi, removed deprecated'lar, breaking değişiklikler)
- [ ] (Opsiyonel) `lib/appflowy_editor.dart`'tan iç-detay export'ları gerçekten çıkar: `appflowy_rich_text.dart`, `export_sheet.dart`, `infra/log.dart`. **Defer**: Phase 4/5 ile birlikte yapmaya değer mi karar ver — şu an tutarsız bir API yarı-yarıya breaking olur.

#### H3.5 — Table block yeniden yaz (Etki: Orta / Çaba: L / Risk: Orta)

- [ ] 30×30 fixture ile **standalone benchmark** yaz (table dışında render perf)
- [ ] `TableDefaults` static mutable field'larını instance'a taşı
- [ ] `TableCol._buildCells` listener mantığını transaction-storm'sız yeniden kur
- [ ] `two_dimensional_scrollables` migration'ı kabul kriteri = benchmark eşiği
- [ ] (Önce auto-memory'deki `project_table_view_migration_backlog.md`'yi oku)

### Horizon 4 — Feature parity (backlog, 3–6 ay)

İhtiyaç ortaya çıktıkça çek.

- [ ] **Integration test stub** (kilit açıcı, H1.6'yı anlamlı kılar): `integration_test/editor_mount_test.dart` — `AppFlowyEditor` mount edip basic interaction yapan tek senaryo. Bu varolunca `reactivecircus/android-emulator-runner` ve iOS simulator job'ları gerçek bir gate olur.
- [ ] Markdown encode: column/columns desteği
- [ ] Markdown decode: code block desteği
- [ ] Quill Delta decoder (README'nin sözünü tut)
- [ ] Mark/Decoration extension API (Tiptap/ProseMirror benzeri) — comment range, suggestion mode, collab cursor için decoration layer
- [ ] Schema/validation katmanı — `Node.attributes` typo-safe, `BlockComponentValidate` declarative
- [ ] Input rules sistemi (`(c) → ©`)
- [ ] First-class collab adapter (Yjs/CRDT)
- [ ] Slash menu: kategoriler + arama
- [ ] `EditorStyle.fromTheme(ThemeData)` — dark mode boilerplate sıfırla
- [ ] Out-of-the-box drag handle (BlockNote tarzı)
- [ ] `editorTest` helper public — unit test boilerplate azalt
- [ ] `editor.dart` ve `block_component.dart` dartdoc yaz
- [ ] **Slang / slang_flutter ile lokalizasyon migration** (next major `7.0.0` ile, H3.4 birlikte). Mevcut: `flutter_intl` + `intl_utils`, 22 ARB dosyası, 23 kullanım, düz string mapping (parametre/plural yok). Slang kazanımı: compile-time type safety + nested keys (`t.toolbar.bold`). Riskler:
  - Library package için optimize değil (LocaleSettings/TranslationProvider app-odaklı)
  - `AppFlowyEditorLocalizations.current.X` breaking — downstream consumer'lar etkilenir
  - `dart run slang migrate arb` ile ARB→JSON dönüşüm var (22× döngü)
  - Sadece major bump'ta (H3.4 ile birlikte) anlamlı; standalone yapılırsa migration maliyeti yüksek
  - **Daha ucuz alternatif**: flutter_intl'i tut + üstüne `lib/src/l10n/keys.dart` typed wrapper yaz — migration yok, API breaking yok

---

## Şu hafta için somut başlangıç

- [ ] **H1.1** — CI flag'lerini düşür (tek küçük PR, anında sinyal)
- [ ] **H1.2** — README'yi düzelt (pub.dev'de açık yara)
- [ ] **H1.8** — Selection-cascade benchmark testi (H2'nin zemini, ölçmeden devam etme)

---

## Raporlanmamış riskler / belirsizlikler

- `two_dimensional_scrollables`'in neden başarısız olduğu auto-memory'de detaylı yok; H3.5'e başlamadan önce o memory'yi okumak/güncellemek faydalı
- Upstream stratejisi belirsiz: fork üzerinde mi release edilecek, upstream'e PR mi atılacak? Bus-factor=1 olan upstream'de roadmap aylar alabilir
- Selection-cascade fix'inin collab/remote cursor senaryosunu kırma riski var: H2.1 yapılırken `remoteSelections` ve `selectionNotifierAfterLayout` davranışını ayrı tutmak gerek
