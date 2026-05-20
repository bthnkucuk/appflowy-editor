# AppFlowy Editor — Konsolide Durum & Roadmap

> İlerledikçe `- [ ]` → `- [x]` yap (render'da otomatik üstü çizilir).
> Tarih: 2026-05-20 — Branch: `feat/super-sliver-list-and-mobile-keyboard-fix`

## Tek Cümle Özet

Çekirdek motor (transaction/operation modeli, block component registry, shortcut sistemi, sliver virtualization) sağlam; ama paket bir "ürün içi modül" gibi paketlenmiş — public API'de sızıntılar, CI'da yalancı yeşil, `EditorState` god-object'i, mobile/desktop dallanma derinde geç olduğundan selection drag stutter'ın kök nedeni hâlâ açık, README pub.dev'de kırık, upstream bus-factor=1.

## Sağlık Skoru

| Boyut | Skor | Not |
|---|---|---|
| Mimari temeller | 8/10 | Transaction, registry, Selectable interface güçlü |
| Test kapsamı | 7/10 | 210 dosya / ~910 case — sayısal iyi, image block / selection drag / mobile integration boş |
| CI güvenilirliği | 3/10 | 4 kritik adım `continue-on-error: true` |
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

- CI gerçek bir kapı değil — `analyze`/`format`/`custom_lint`/codecov'de `continue-on-error: true`
- README pub.dev'de patlamış — `README.md:146` sonrası ~520 satırlık markdown-it lorem-ipsum fixture
- Tek Flutter sürümü (3.44.0), iOS/Android emulator CI job yok

### P1 — Yapısal risk

- **Selection drag stutter'ın muhtemel kök zinciri (henüz ölçülmedi):**
  - `PropertyValueNotifier.value` setter **her zaman** broadcast (aynı değerde bile) — `lib/src/property_notifier.dart:24-27`
  - Drag başına ~60 selection update → N block × 2 widget (`BlockSelectionArea` + `BlockHighlightArea`) rebuild
  - Her area kendini her frame `addPostFrameCallback` ile **yeniden zamanlıyor** — `lib/src/editor/block_component/base_component/widget/block_selection_area.dart:230-232` + `block_highlight_area.dart:267-269`
  - `mobile_selection_service._updateSelectionDuringDrag` zaten 2-3 post-frame derinliğinde — `mobile_selection_service.dart:415-428, 518-537`
  - **Coalesce neden yetmedi:** darboğaz event sıklığı değil, tek update'in N rebuild + per-block self-rescheduling üretmesi
- `EditorState` god-object (~915 satır): selection + highlight + tap + toggledStyle + remote + autoScroller + scrollableState + documentRules + debouncedSeal + transactionStream + asyncObserver + autoCompleteText + selectionExtraInfo Map + showHeader/showFooter
- `lib/src/service/` (eski) ve `lib/src/editor/editor_component/service/` (yeni) çakışıyor — hangisi canonical belirsiz
- `package:appflowy_editor/src/...` 157 yerde içeriden — refactor'da sessizce kırılır
- `MobileSelectionService` 985 satır + global mutable flag'ler (`disableMagnifier`, `disableIOSSelectWordEdgeOnTap`, `appFlowyEditorOnTapSelectionArea`, `keepEditorFocusNotifier`)
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

- [ ] **H1.1** CI'da `continue-on-error: true` flag'lerini düşür (analyze/format/custom_lint) — `.github/workflows/test.yml:50,54,58,65` — Etki: Yüksek / Çaba: XS
- [ ] **H1.2** `README.md:146` sonrasını sil; gerçek "Getting Started" + "Examples" bölümü yaz — Etki: Yüksek / Çaba: XS
- [ ] **H1.3** `CONTRIBUTING.md` ve `.github/PULL_REQUEST_TEMPLATE.md` yaz — Etki: Orta / Çaba: XS
- [ ] **H1.4** `example/` uygulamasını CI'da `flutter build apk --debug` + `flutter build ios --no-codesign` ile derle — Etki: Orta / Çaba: S
- [x] ~~**H1.5** `awesome_lints`'i `ref: <commit-sha>`'ya pinle~~ → Tamamen kaldırıldı (awesome_lints + custom_lint pubspec'ten, custom_lint adımı CI'dan, custom_lint bloğu analysis_options'tan)
- [ ] **H1.10** `very_good_analysis`'e aşamalı geçiş (denendi: 6589 issue + 100+ error patlıyor, strict-casts/inference/raw-types yüzünden). Plan:
  1. `dart fix --apply` ile auto-fix (prefer_single_quotes ~1582, prefer_final_locals ~149, omit_local_variable_types ~327)
  2. `strict-raw-types: true` aç + gelen warning'leri düzelt
  3. `strict-inference: true` aç + düzelt
  4. `strict-casts: true` aç + düzelt (en zoru — `Node.attributes` dynamic döner, çoğu yerde cast eklemek gerek)
  5. `public_member_api_docs` aç (dokümantasyon sprint'i, 2079 yer)
  6. flutter_lints'i kaldırıp very_good_analysis'i tek `include` olarak koy
- [ ] **H1.6** iOS/Android emulator CI job'larını geri ekle (yorum satırı duruyor) — Etki: Yüksek / Çaba: M / Risk: Orta (flaky)
- [ ] **H1.7** `test/legacy/`'i `new/` ile birleştir ya da sil — Etki: Düşük / Çaba: S
- [ ] **H1.8** **Selection-cascade benchmark testi**: 200 paragraph dokümanda bir selection set'inin kaç `notifyListeners` + `build` tetiklediğini sayan widget testi (H2'nin regresyon kapısı, ölçüm) — Etki: Yüksek / Çaba: S
- [ ] **H1.9** 31 branch'ten eski release/feature dallarını arşivle (tag bırak, sil)

### Horizon 2 — Selection stutter kök neden (2–6 hafta)

Hedef: auto-memory'deki "yavaşla-hızlan" pattern'ini *ölçerek* kapat.

- [ ] **H2.0** Profil al — Android profile build, 200+ paragraph doc, `flutter run --profile --trace-skia` + DevTools Timeline. PostFrameCallback yoğunluğu + ValueListenableBuilder rebuild sayısı (baseline)
- [ ] **H2.1** `PropertyValueNotifier`'ı opt-in `alwaysNotify`'a çevir; `selectionNotifier` için eşitlik kontrolü ekle — `lib/src/property_notifier.dart` — Etki: Yüksek / Çaba: S / Risk: Orta (bazı listener'lar layout-dirty broadcast'ine bel bağlamış olabilir)
- [ ] **H2.2** `BlockSelectionArea._updateSelectionIfNeeded` self-reschedule chain'ini kır; layout-dirty sinyaline bağla — `block_selection_area.dart:230-232` + `block_highlight_area.dart:267-269` — Etki: Yüksek / Çaba: M
- [ ] **H2.3** `mobile_selection_service._updateSelectionDuringDrag` içindeki nested post-frame'leri tek frame'e indir — Çaba: S
- [ ] **H2.4** iOS Magnifier'ı `BackdropFilter`'sız variant ile A/B test et; ölçüm darboğazsa default'u değiştir — Çaba: S
- [ ] **H2.5** `_AndroidDragHandle.onPanUpdate`'teki `HapticFeedback.selectionClick` yalnız selection karakter değiştiğinde tetiklensin — `mobile_basic_handle.dart:344` — Çaba: XS
- [ ] **H2.6** Her PR sonrası H1.8 benchmark'ı koş ve sonuçları PR'a yapıştır
- [ ] **H2.7** H1.8 benchmark'ına drag-simulation senaryosu ekle (regresyon koruması)

### Horizon 3 — Mimari refactor (2–4 ay)

#### H3.1 — `EditorState`'i dağıt (Etki: Yüksek / Çaba: L / Risk: Orta)

- [ ] `SelectionController` çıkar (selectionNotifier + highlightNotifier + tapNotifier + remoteSelections + dragMode + extraInfo type-safe)
- [ ] `HistoryController` çıkar (undoManager + debouncedSeal + disableSealTimer)
- [ ] `EditorChrome` çıkar (showHeader/showFooter/scrollableState/autoScroller)
- [ ] `StyleController` çıkar (toggledStyle)
- [ ] `EditorState` cephesini koru, deprecated forward'lar ver

#### H3.2 — `service/` çift katmanını birleştir (Etki: Yüksek / Çaba: M / Risk: Düşük)

- [ ] `lib/src/service/copy_paste_handler.dart` → modern `copy_paste_extension.dart` ile birleştir
- [ ] `lib/src/service/internal_key_event_handlers/` → modern `keyboard_service/` altına taşı
- [ ] `lib/src/service/selection/` → modern `selection_service`'e birleştir
- [ ] `lib/src/service/context_menu/` taşı
- [ ] Eski katmanlardan deprecated forward bırak, bir major sonra sil

#### H3.3 — Mobile/desktop composition (Etki: Yüksek / Çaba: L / Risk: Orta)

- [ ] `SelectionServiceWidget` build içi `if (isDesktop)` branch'ini ayrı widget'a böl
- [ ] `MobileSelectionService` 985 satırını böl: `MobileSelectionGestureLayer`, `MobileSelectionHandles`, `MobileSelectionAutoScroller`, `MobileSelectionMagnifier`
- [ ] `mobile_toolbar_v1`'i kaldır, `_v2` resmi olsun
- [ ] Global mutable flag'leri (`disableMagnifier`, `disableIOSSelectWordEdgeOnTap`, `appFlowyEditorOnTapSelectionArea`, `keepEditorFocusNotifier`) instance-scoped configa taşı
- [ ] `selectionExtraInfo` Map'ini type-safe field'lara çevir

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
