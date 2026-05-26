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

- **Selection drag stutter'ın muhtemel kök zinciri (henüz ölçülmedi):**
  - `PropertyValueNotifier.value` setter **her zaman** broadcast (aynı değerde bile) — `lib/src/property_notifier.dart:24-27`
  - Drag başına ~60 selection update → N block × 2 widget (`BlockSelectionArea` + `BlockHighlightArea`) rebuild
  - Her area kendini her frame `addPostFrameCallback` ile **yeniden zamanlıyor** — `lib/src/editor/block_component/base_component/widget/block_selection_area.dart:230-232` + `block_highlight_area.dart:267-269`
  - `mobile_selection_service._updateSelectionDuringDrag` zaten 2-3 post-frame derinliğinde — `mobile_selection_service.dart:415-428, 518-537`
  - **Coalesce neden yetmedi:** darboğaz event sıklığı değil, tek update'in N rebuild + per-block self-rescheduling üretmesi
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

- [ ] **H2.0** Profil al — Android profile build, 200+ paragraph doc, `flutter run --profile --trace-skia` + DevTools Timeline. PostFrameCallback yoğunluğu + ValueListenableBuilder rebuild sayısı (baseline)
- [x] **H2.1** `PropertyValueNotifier`'ı opt-in `alwaysNotify`'a çevir; `selectionNotifier` için eşitlik kontrolü ekle — `lib/src/property_notifier.dart` — Etki: Yüksek / Çaba: S / Risk: Orta (bazı listener'lar layout-dirty broadcast'ine bel bağlamış olabilir) → `dc84c0bb`
- [x] **H2.2** `BlockSelectionArea._updateSelectionIfNeeded` self-reschedule chain'ini kır; layout-dirty sinyaline bağla — `block_selection_area.dart:230-232` + `block_highlight_area.dart:267-269` — Etki: Yüksek / Çaba: M → `cae7d87b`
- [ ] **H2.3** `mobile_selection_service._updateSelectionDuringDrag` içindeki nested post-frame'leri tek frame'e indir — Çaba: S
- [ ] **H2.4** iOS Magnifier'ı `BackdropFilter`'sız variant ile A/B test et; ölçüm darboğazsa default'u değiştir — Çaba: S
- [ ] **H2.5** `_AndroidDragHandle.onPanUpdate`'teki `HapticFeedback.selectionClick` yalnız selection karakter değiştiğinde tetiklensin — `mobile_basic_handle.dart:344` — Çaba: XS
- [ ] **H2.6** Her PR sonrası H1.8 benchmark'ı koş ve sonuçları PR'a yapıştır
- [ ] **H2.7** H1.8 benchmark'ına drag-simulation senaryosu ekle (regresyon koruması)

### Horizon 3 — Mimari refactor (2–4 ay)

#### H3.1 — `EditorState`'i dağıt (Etki: Yüksek / Çaba: L / Risk: Orta)

**Durum (2026-05-26):** `editor_state.dart` 915 → **425 satır**. Library-private mixin'lere bölündü (`_EditorChromeMixin`, `_HistoryMixin`, `_SelectionStyleMixin`, `_TransactionPipelineMixin`, `_ScrollCoordinatorMixin`, `_EditorServiceMixin`, `_TableOfContentsMixin`). Facade `abstract class _EditorStateBase` üzerinden composed.

- [x] `HistoryController` çıkar → `_HistoryMixin`
- [x] `EditorChrome` çıkar → `_EditorChromeMixin`
- [x] `StyleController` çıkar → `_SelectionStyleMixin` (selection + highlight + toggledStyle)
- [x] `TransactionPipelineMixin` (broadcast + content-based dirty hash + `isDirtyNotifier`/`markClean()`)
- [x] `TableOfContentsMixin` — reactive outline (`TocEntry`, `tableOfContents` ValueListenable, microtask-coalesced recompute) + `jumpToTocEntry`
- [x] `EditorState` cephesini koru — mixin'ler `_` prefix'li, downstream API kırılmadı

**Kalan iş** — facade'i ~150-200 satıra indirmek için:

- [ ] `apply()` + `_applyTransactionInLocal` + `_applyTransactionFromRemote` (~150 satır) → `_TransactionApplyMixin` (veya pipeline mixin'in altına). Etki: Yüksek / Çaba: M / Risk: Orta (apply hot path, transaction record/undo'yla iç içe)
- [ ] `documentRules` + `_subscription` zincirini `mixin _DocumentRulesMixin on _EditorStateBase`'e taşı (`on _EditorStateBase` `this`-cast gymnastic'ini ortadan kaldırır). Etki: Orta / Çaba: S
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

- [ ] `lib/appflowy_editor.dart` barrel'ını elle küratörle (iç-detay dosyaları çıkar: `appflowy_rich_text.dart`, `export_sheet.dart`, `infra/log.dart`)
- [ ] Sub-library'lere böl: `core.dart`, `blocks.dart`, `plugins.dart`, `mobile.dart`
- [ ] İç `package:appflowy_editor/src/...` import'larını relative'e çevir (codemod, 157 yer)
- [ ] 14+ deprecated API'yi kaldır (next major `7.0.0`)
- [ ] `UPGRADING.md`'yi gerçekten doldur

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
