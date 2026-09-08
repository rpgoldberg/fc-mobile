# fc-mobile Design Brief — Mobile-Native Overhaul

**Status:** Proposal for review. No code has been written against this brief.
**Inputs:** Four discovery reports — desktop fc-frontend capability audit, current fc-mobile audit, MFC responsive-behavior study (15 screenshots, 3 JSON reports), Preact-compatible library survey (versions verified 2026-07-03).
**Scope guard:** The 11 protected desktop screens + MFC sync subsystem. No Collection DNA, no price/discover surfaces beyond what already exists in fc-mobile — the IA reserves expansion slots instead of designing speculative screens.

---

## 1. The Core Problem

**Condense, don't scale.** Three artifacts demonstrate three different failures of the same catalog UI across form factors:

- **fc-frontend (desktop)** is a capable 16:9 layout — 8-facet filter sidebar, grid-preset pagination, hover affordances everywhere — that explicitly refuses to run below 768px (the `MobileWarning` interstitial).
- **fc-mobile (current)** is a scaled desktop wearing phone chrome. The "fonts too big" complaint is measurably a *chrome + type-ramp* problem, not a glyph problem: a 22px-bold title inside a 56px sticky header, a ~130px always-on releases strip, and a 64px fixed bottom nav consume ~250 of 844px before the first figure image. Card text is already 14/12px. On top of that: the collection is hard-capped at 20 figures (no infinite scroll), 3 of 5 filter dimensions are dead ends, portrait figure photos are center-cropped square, and the entire app contains 5 media queries — the Fold-5 open gets a stretched phone.
- **MFC (the reference)** proves the opposite failure: it *scales without condensing*. Identical DOM at every viewport, 64px thumbs with zero captions (unidentifiable without tapping), a 9,562px linearized single-column item page, and a Fold-open layout that is phone chrome around desktop grid density.

The design target is a genuinely different composition per width, with three constraints:

1. **Image panels + their data get maximum space.** Chrome is the enemy: every persistent bar, title, and strip is charged against a vertical budget on a ~3:1 phone (390×844) where the user's goal is scanning figure photographs.
2. **Markedly smaller type**, sized to the *card*, not the viewport — density rises with width instead of text ballooning.
3. **Two mobile form factors, not one.** A tall-narrow slab (360–430dp wide, 19.5–21:9) and the Fold-5 open (~674dp, near-square 4:5) need different compositions. Both current codebases misclassify the Fold: desktop shows it the mobile warning; fc-mobile gives it the 3-col phone grid and a bottom bar. The fix is **width classes + container queries**, not more `isMobile` booleans.

**Width-class vocabulary used throughout this brief:**

| Class | Width | Devices | Composition |
|---|---|---|---|
| **compact** | <600dp | phones, Fold closed (~320–360dp cover) | single pane, bottom tabs, sheets |
| **medium** | 600–840dp | Fold-5 open (~674dp), small tablets portrait | nav rail, dual-pane, persistent filter panel |
| **expanded** | >840dp | desktop | out of scope (fc-frontend owns it) |

---

## 2. Information Architecture & Navigation

### Recommendation: 4-slot bottom tab bar + docked Add action + contextual collapsing headers

```
compact (<600dp)                       medium (600–840dp, Fold open)
┌──────────────────────────┐           ┌───┬──────────────┬───────────┐
│ slim contextual header   │  ←collapses│ C │              │           │
│ (collapses on scroll)    │   on scroll│ S │  collection  │  detail / │
│                          │           │ + │  grid        │  filter   │
│      content             │           │ St│              │  panel    │
│                          │           │ P │              │           │
├──────────────────────────┤           └───┴──────────────┴───────────┘
│ Coll │ Srch │ (+) │ Stats│ Prof │      leading nav rail replaces the
└──────────────────────────┘            bottom bar; (+) rides the rail
   auto-hides on scroll-down
```

**Tabs:** **Collection · Search · [+ Add] · Stats · Profile**

- **Collection** — the home screen. Absorbs the desktop Dashboard: the 4 stat cards become a horizontally scrollable chip rail in the (collapsible) header zone; Recent Figures is redundant with the grid itself under the default "Collection Order" sort. Status pivot (Owned / Ordered / Wished) stays as a segmented control at the top — it is already the right mobile pattern and is the primary way collectors slice their data. Lists appear as a second pivot here (see below).
- **Search** — a dedicated full-screen surface: input pinned top, suggestion list below (recent / manufacturer / collection groups already exist in fc-mobile's `useSearch`), results rendered as the *same* virtualized grid component as Collection, with the same filter sheet. This fixes two desktop gaps at once: the Portal/`getBoundingClientRect` dropdown that breaks under soft keyboards, and desktop Search's missing facets/sort/pagination.
- **[+ Add]** — a visually distinct center action (raised circle docked into the bar), not a full tab. It opens the add flow directly: **MFC-link-first** — paste or share-target an MFC URL → auto-scrape → confirm pre-filled sections → save. Manual field entry is the fallback, presented as an accordion of the desktop form's sections (Core → Collection → Catalog/Purchase → Roles/Releases), one screen each. Dynamic rows (roles, releases) are added via small bottom sheets rather than inline multi-input rows. The lg-only sticky image preview from desktop returns as an inline thumbnail pinned near the top so mobile users don't enter data blind. This closes the largest capability gap: fc-mobile currently has *no* manual Add at all.
- **Stats** — vertically stacked accordion of top-N lists ("Manufacturers — top 5 · See all"), each row a name + count + a proportional bar behind the row replacing the % column. Row tap deep-links into the filtered Collection grid — this is the killer interaction from desktop and must survive. "See all" opens a full-screen sorted list. CSV export demotes to a share-sheet action.
- **Profile** — account (profile, security/2FA/passkeys), **MFC account surface** (cookie status, sync trigger, sync history — replacing the 1s-polling lock icon in permanent chrome), and the long-tail utility cluster that currently lives as five cryptic 48px header icons: Notifications, Release Calendar, Analytics, Import/Export, Settings/theme. Also the **expansion slot**: Prices/Discover/DNA slot in here as they mature rather than claiming tab space prematurely.

**Where Lists live:** as a pivot inside Collection (`Figures | Lists` segmented control or chip), not a tab. Reasoning: lists are a *view over the collection*, used far less often than the grid, and desktop's own nav bug (Lists is unreachable below md) shows it was never a top-level destination in practice. The Lists table condenses to a card list (name + privacy dot + item count, teaser as a secondary line, swipe-to-delete); ListDetail keeps its 2-up image grid, and items that exist locally open in-app FigureDetail instead of linking out to MFC.

**Contextual headers, not page titles:** the tab bar already says where you are. Screen headers are a slim (~48px) zone holding only contextual controls (status segments, search field, filter/sort entry), and they collapse on scroll. The 22px-bold repeated page title dies. The bottom bar auto-hides on scroll-down, returns on scroll-up or at rest. Sync progress becomes a compact pill under the header (tap → detail bottom sheet with per-status counts, failed items, Abort/Resume) instead of a persistent 3-band banner stack — the SSE plumbing is unchanged.

**Medium width class (Fold open):** the bottom bar becomes a **leading nav rail** (~64px), reclaiming the bottom edge entirely, and Collection becomes **dual-pane**: grid left, FigureDetail (or the filter panel) right. wouter routes drive the right pane, so deep links and back gestures keep working.

### Why this over the alternatives

| Alternative | Why not |
|---|---|
| **Hamburger / drawer (MFC's answer)** | Hides all destinations behind one tap, kills discoverability and one-thumb reach; MFC's own drawer is a full-screen detour. Acceptable only for the long tail, which we place in Profile instead. |
| **Header icon cluster (current fc-mobile)** | 5 × 48px icons + a view toggle consume ~290 of 390px; the title truncates and secondary features masquerade as primary ones. This is the specific "nav eats image space" defect being removed. |
| **5 full tabs (Add as a tab)** | Add is an *action*, not a *place*; giving it a full tab means a mostly-dead destination. The docked center action keeps it one tap away without costing a navigable slot. |
| **Merge Stats into Profile (3 tabs)** | Stats→filtered-grid deep-linking is a browsing entry point, not a settings page; burying it breaks the loop. |

**Difference from desktop:** no persistent 250px sidebar, no navbar dropdowns, no footer; Dashboard merges into Collection; breadcrumbs collapse to a single back affordance. **Difference from MFC:** primary destinations always visible in the thumb zone; the bottom edge is reserved for navigation, never passive content (MFC spends it on a 100px sticky ad).

---

## 3. Filter / Facet Paradigm

### Recommendation: detented bottom sheet with live result counts + a persistent applied-chips row

This is the canonical mobile e-commerce pattern (ASOS/Zalando class) and the single biggest capability win over MFC, which has *no* filter UI on result grids at any viewport — filtering is exiled to a separate Search-form page.

**Entry point:** a slim sticky `Filter | Sort` bar (or one combined control with an active-count badge) directly under the header on Collection and Search results. One row, ~40px, and it scrolls away with the header.

**The sheet:** a bottom sheet with 2–3 snap detents (half ≈ 50% and full ≈ 90%dvh):

- **Half detent** shows the high-traffic controls: Status (multi-select), Sort (4 fields × asc/desc as chips), and the top facets. The grid stays visible above the sheet — you filter *in context*, watching results change.
- **Full detent** exposes the complete facet accordion.
- **Facet tiering** condenses the desktop sidebar's 8 facets: primary — **Category, Manufacturer, Scale** — always visible; secondary — Distributor, Origin, Sculptor, Illustrator, Classification — behind a "More filters" tier. Tiering should be validated against Ross's real usage (open question #3).
- Each facet keeps the desktop mechanics that earn their space: value + count rows, multi-select, in-facet search box when >5 values, "Not Specified" synthetic values, per-facet clear. The 3-state sort-cycle button per facet is desktop-grade fiddliness — drop it; default to count-desc.
- **Live count on the apply button** ("Show 143 results") — turns filtering from a leap of faith into a conversation.

**Applied state is always visible:** a horizontally scrollable chip row pinned above the grid — one removable chip per active facet value + "Clear all". On a phone this row *is* the filter-state indicator; it costs ~36px only when filters are active.

**State model — adopt desktop's URL persistence.** Desktop's `useFigureListState` (querystring for page/sort/status + 8 facet params, pipe-delimited values) is a free asset: back-gesture correctness, shareable filtered views, and Stats→Collection deep links all fall out of it. fc-mobile should write filter state to the URL with the *same parameter names* as fc-frontend so links are portable between the two apps.

**Precondition — fix the dead filters before styling them.** Today: `manufacturer` is collected but has no UI, `scale` is collected but never sent to the API, multi-status is silently dropped unless exactly one status is selected, and the "active filters" dot lights up for filters that do nothing. A beautiful sheet over dead wiring is worse than the current state. This is Phase 2's first task and may need small backend/API confirmation (multi-status query support, or client-side fallback against the IndexedDB cache).

**Medium width class:** the same sheet component re-presents as a **persistent side panel** next to the grid via a container query — at ~674dp the desktop's 280px sidebar genuinely fits beside a 2–3 column grid. One component, two presentations, no device sniffing.

### Why this over the alternatives

- **Command palette (cmdk):** desktop idiom (keyboard-first), and cmdk sits on Radix — an unsupported preact/compat surface. Rejected on both interaction and dependency grounds.
- **Cog-triggered full-screen drawer:** loses grid context while filtering; full-screen is only right at the sheet's full detent, which the user chooses by dragging.
- **Inline chip row only:** cannot hold 8 facets × dozens of values; chips are the right *applied-state* display, not the right *editing* surface.
- **Desktop-style persistent sidebar on compact:** 280px of a 390px screen. Non-starter; correct only at medium width, which the container query handles.

---

## 4. Image Grid & Layout System

### Card geometry: portrait 3:4, not square

Figure photography is predominantly tall portrait; the current `aspect-ratio: 1` + `object-fit: cover` decapitates figures. Cards go **3:4** with `object-fit: cover` (contain-fit as a per-user option later). MFC's genuinely good trick — fixed-ish cell size, fluid column count — is adopted at touch-legible scale instead of MFC's unidentifiable 64px.

### Columns derive from width, not breakpoints

One rule: `grid-template-columns: repeat(auto-fill, minmax(var(--card-min), 1fr))` inside a size container. `--card-min` is set by the density mode; column count is *emergent*:

| Density | `--card-min` | ~360dp phone | ~430dp phone | Fold open ~674dp | Card shows |
|---|---|---|---|---|---|
| **Comfortable** | ~164px | 2-up | 2-up | 4-up | image + name (2-line clamp) + 1 metadata line (company or scale badge) + status tick |
| **Compact (default)** | ~110px | 3-up | 3–4-up | 5–6-up | image + 1-line name overlay on a bottom gradient |
| **Gallery** | ~90px | 4-up | 4-up | 7-up | image only; name via tap-to-peek (never hover) |

The desktop rows×cols page-size picker (5(1×5)…96(8×12)) is meaningless on a phone and is replaced by this 3-state density toggle. Desktop's three card layouts re-map: `text-left` → the alternate **list view** (thumb + metadata rows, kept from current fc-mobile); `image-only` → Gallery; `text-bottom` → Comfortable.

**Everything that was hover becomes touch:** name reveal → always-on gradient caption or tap-to-peek; edit/delete `xs` icons + `window.confirm` → long-press context menu (or list-view swipe actions) with a proper `<dialog>` confirm; every target ≥44px. Metadata beyond one line (version, origin, MFC id) demotes to the detail view — that is the condensation contract: the grid identifies, the detail informs.

### Data flow: virtualized infinite scroll

The 20-item cap is fatal and grid work is moot until it's gone. `useInfiniteQuery` (react-query 5 already in deps) + windowed rendering keeps ~20–30 cells in the DOM regardless of collection size, preserving 60fps momentum scroll on mid-range Android. Numbered pagination and the page slider do not port; the API's existing page/limit params serve the infinite query as-is. Scroll position restores on back-navigation (the virtualizer owns this).

Every cell paints a correctly proportioned **ThumbHash placeholder** in the first frame (`aspect-ratio` box + ~25-byte hash decoded to a data-URI) — zero layout shift, instant perceived paint on cellular. Keep the existing 2-step MFC image fallback (full → medium → placeholder). Pinch (or a tap affordance) on a cell opens a **PhotoSwipe lightbox** — full image fidelity on demand instead of large always-visible images.

### Detail view: first-viewport hierarchy, not linearization

MFC's 9.5k-px single-column item page is the anti-pattern. FigureDetail restructures semantically:

- **First viewport:** hero image (tap → lightbox / swipeable gallery when multiple images exist), name + company, status + rating chips, scale badge, 3–4 key specs.
- **Below / behind accordions:** full spec grid, community stats as a chip row, releases, lists membership, MFC link.
- **Sticky bottom action bar:** Edit · Status · Lists · Delete (fc-mobile already has this pattern — keep it).
- **Horizontal swipe = prev/next within the current result set** — the mobile condensation of MFC's serial-browsing pager and of desktop's implicit grid order. The Related Items horizontal rail stays as-is; it is already the app's one mobile-native pattern and the template for every other rail.

### Responsive strategy: container queries as the architecture

Components adapt to their **container**, not the viewport. Cards, stat chips, and the filter surface are all `@container`-queried; the page level only decides pane composition per width class (bottom bar vs rail, single vs dual pane). This is what makes the Fold a first-class citizen instead of a breakpoint hand-me-down: the same card component renders 2-up rich on a slab and 5-up dense in the Fold's grid pane, and the filter sheet becomes a side panel, with no `isFold` flag anywhere. Device Posture / viewport-segments APIs are Chrome-only — progressive enhancement at most; nothing is built on them.

---

## 5. Typography & Space System

### Type scale — markedly smaller, fluid, card-relative where it counts

MFC validates the strategy: fixed 14px body at *every* viewport, condensing via density and layout rather than glyph scaling. Proposed token replacement for `src/styles/tokens.css:23-28` (fluid range tuned to the 360→674px viewport span):

| Token | Now | Proposed | Used for |
|---|---|---|---|
| `--font-2xs` | — (10px hardcoded ×10 sites) | `0.625rem` (10px, static) | badges, thumb captions — formalizes the existing hardcode |
| `--font-xs` | 12px | `0.6875rem` (11px, static) | metadata lines, chip labels |
| `--font-sm` | 14px | `clamp(0.75rem, 0.7rem + 0.25vw, 0.8125rem)` (12→13px) | card names, secondary text |
| `--font-base` | 16px | `clamp(0.8125rem, 0.76rem + 0.3vw, 0.875rem)` (13→14px) | body, list rows |
| `--font-lg` | 18px | `clamp(0.9375rem, 0.88rem + 0.3vw, 1rem)` (15→16px) | section headings, detail name |
| `--font-xl` | 22px | `clamp(1.0625rem, 1rem + 0.4vw, 1.125rem)` (17→18px) | screen-level headings (rare — titles mostly deleted) |
| `--font-2xl` | 28px | `clamp(1.25rem, 1.15rem + 0.5vw, 1.375rem)` (20→22px) | stat numerals |

Two carve-outs: **form inputs stay ≥16px** on iOS (Safari zooms focused inputs below 16px — a worse experience than slightly large inputs), and **in-card text uses `cqi` units** (e.g. card name `clamp(0.6875rem, 5cqi, 0.8125rem)`) so labels track *card* size — the Fold gets more, individually smaller cards without a separate type tier, and 2-up phone cards keep tap-friendly text. Line-height tightens from 1.5 to 1.35 for UI text (1.5 stays for paragraph content like list descriptions). Utopia (`utopia-core` as a dev-time calculator only) generates the clamp pairs; zero runtime cost.

### Space system — where the image pixels come back

| Chrome element | Now | Proposed | Reclaimed |
|---|---|---|---|
| Header | 56px sticky, always | 48px, collapses on scroll | 48–56px |
| Page title | 22px bold in every header | deleted (tab bar names the place) | — (inside header) |
| UpcomingReleases strip | ~130px always above grid | one-line pill (~32px) → Calendar page owns the full strip | ~98px |
| Bottom nav | 64px fixed | 56px, auto-hide on scroll-down | 56px while scrolling |
| Page padding | 16px | 12px | 8px/row |
| Grid gaps | 12px | 8px | ~4px/gap |
| Safe-area insets | handled | keep (`env()` tokens exist) | — |

Net effect on a 390×844 phone: ~250px of standing chrome drops to ~100px at rest and ~0–48px mid-scroll. Combined with 3:4 compact cells, visible figures per screenful go from ~5 to **~9–12** — the headline user-visible outcome of the whole overhaul, and the metric each phase is judged against.

Spacing tokens stay on the existing 4px-base scale; the change is *defaults* (page padding `--space-3`, gaps `--space-2`), not the scale itself. `--touch-min: 48px` is untouched — targets stay big while text and gutters shrink.

---

## 6. Recommended Lean Tech Stack

Total addition: **~15kb gz interactive JS + ~12kb lazy lightbox chunk**. Everything else is native platform. All versions verified current as of 2026-07-03.

| Add | Version | Role | Why this one |
|---|---|---|---|
| `@tanstack/virtual-core` | 3.17.3 | grid virtualization engine | Headless, framework-agnostic; a ~50-line hand-rolled Preact hook adapter gives dynamic measurement, scroll restoration, lane math — with zero React compat surface. Fallback if shipping speed wins: `virtua` 0.49.2 (~3kb, zero-config, mobile-tuned, but its grid is still `experimental_VGrid` and it rides the compat alias). |
| `@use-gesture/vanilla` | 10.3.1 | one gesture grammar | Framework-agnostic Drag/Pinch classes attach to Preact refs directly; powers swipe-between-items, sheet drag assist, pull-to-refresh (~60-line hand-roll — required anyway, standalone PWAs have no reload UI). |
| `photoswipe` | 5.4.4 (lazy chunk) | pinch-zoom lightbox | Vanilla ESM; pinch, spread-to-close, swipe-dismiss built in. Loaded only when a lightbox opens. |
| `thumbhash` | 0.1.1 | blur-up placeholders | ~25-byte hash per image, ~1kb client decode, better gradients/alpha than BlurHash. **Cross-service dependency:** hashes generated at scrape/ingest time and stored on the figure record (scraper/backend change to schedule). |

| Native (0kb) | Replaces |
|---|---|
| CSS size container queries + `cqi` | the entire breakpoint/`isMobile` regime |
| `clamp()` fluid tokens | runtime type logic |
| `aspect-ratio` boxes | layout-shift hacks |
| `loading=lazy` / `srcset` / `sizes` / `fetchpriority` | JS lazy-load libs (redundant inside a virtualized grid anyway) |
| `dvh`/`svh` | browser-chrome height bugs |
| `<dialog>` + Popover API | modal/popover libraries (confirms, menus) |
| `scroll-snap`, `overscroll-behavior` | carousel/PTR plumbing |

**Keep-but-slim:** `framer-motion` (already a dep; heaviest library in the app) → `LazyMotion` + `m` components with `domAnimation` (~15kb vs ~34kb), or `motion/mini` WAAPI `animate()` (~2.6kb) for simple cases; evaluate the View Transitions API (Chrome, Safari 18+, Firefox 139+) to retire `AnimatePresence` route transitions. Keep: preact 10.29, wouter, react-query 5, zustand, signals, idb, socket.io — the hooks/storage/auth/PWA/test layers survive the rebuild untouched.

**Avoid (React-first, unsupported under preact/compat):** Radix, vaul, cmdk, Headless UI, Ark UI, react-virtuoso, react-window, @unlazy/react. Every one avoided is compat risk removed from the `vite.config.ts` aliasing; the hand-roll-on-`<dialog>`/Popover strategy keeps the compat surface limited to already-proven deps.

**Hygiene fix while in the files:** hoist the per-instance `<style>` blocks (20 cards = 20 duplicate style tags today) to module-level constants rendered once, or a single stylesheet.

**Architectural summary:** the rebuild is **view-layer only** — `src/pages`, `src/components/{layout,collection,ui}`, `tokens.css`. API client, auth store, react-query hooks, IndexedDB cache, pendingOps queue, websocket live-sync, PWA/service-worker, and the 40-file test harness are keepers.

---

## 7. Phased Build Plan

Each phase ends at a **visual checkpoint**: screenshots (or a running build) on three widths — 360dp slab, 430dp slab, ~674dp Fold-open — for Ross to judge before the next phase starts. Phases 0–2 are deliberately re-orderable feedback loops, not a waterfall.

**Phase 0 — Chrome diet + type tokens** *(cheapest, most visible)*
Replace the type ramp in `tokens.css` with the §5 clamp scale; collapse-on-scroll header (drop page titles); auto-hide bottom nav; UpcomingReleases → one-line pill; tighten padding/gaps; dedupe `<style>` blocks. No new deps, no IA change — pure reclamation on the existing screens.
**Checkpoint 1:** before/after of Collection on all three widths. *Question for Ross: is this type scale "markedly smaller" enough, or push further?*

**Phase 1 — The grid proof-of-concept** *(the heart of the overhaul)*
Virtualized infinite Collection grid: `useInfiniteQuery` (kills the 20-cap), virtual-core + Preact hook adapter, container-query `auto-fill/minmax` columns, 3:4 cards, 3-state density toggle, gradient-caption compact cards, placeholder blur-up (dominant-color stub until ThumbHash ingest lands). Kill list view changes for now — grid only.
**Checkpoint 2:** on-device scroll feel + density judgment; Fold column counts. *This is the make-or-break visual review.*

**Phase 2 — Filter sheet + state**
First fix the dead wiring (manufacturer UI, scale actually applied, multi-status server support or client fallback). Then: Filter|Sort bar, detented sheet with facet accordion + live "Show N results" count, applied-chips row, URL-persisted state using desktop's param names.
**Checkpoint 3:** filter a real collection end-to-end; verify deep links round-trip with fc-frontend.

**Phase 3 — Detail + gestures**
FigureDetail first-viewport hierarchy + accordions + sticky action bar; swipe prev/next through the result set; PhotoSwipe lightbox; long-press context menus replacing hover/`window.confirm` patterns.
**Checkpoint 4:** browse→detail→swipe→back loop on device.

**Phase 4 — IA completion**
Tab bar rework (Collection/Search/+Add/Stats/Profile); full-screen Search surface reusing the Phase-1 grid + Phase-2 sheet; MFC-link-first Add flow (closes the biggest capability gap); Lists pivot + card list + ListDetail; Stats accordion with deep links; Profile consolidation (MFC surface, utility cluster); missing auth routes (reset-password, verify-email). Medium width class: nav rail + dual-pane + filter-as-side-panel.
**Checkpoint 5:** full IA walkthrough, slab + Fold.

**Phase 5 — Sync surface + polish**
Sync progress pill + detail sheet (SSE/socket plumbing unchanged); ThumbHash ingest integration once the scraper/backend change ships; LazyMotion slimming / View Transitions evaluation; OLED/reduced-effects theme variants; perf pass (time-to-first-grid on throttled network as the number to beat).

**Explicitly out of scope:** Bulk CSV import stays desktop-gated (paste-CSV + wide preview is desktop-shaped by nature); the devtools cookie-extraction flow is not ported — the mobile story is desktop-pairing handoff (cookies are server-validated, so "capture on desktop, sync from phone" already works) unless Ross wants a guided-webview investigation (open question #7).

---

## 8. Open Questions for Ross

1. **Add placement:** docked center action on the tab bar (proposed) vs a FAB on Collection only? The center slot makes Add feel first-class; the FAB keeps the bar to four pure destinations.
2. **Fold dual-pane timing:** ship the medium width class (nav rail + grid/detail panes) in Phase 4 as proposed, or defer it and let fluid columns alone carry the Fold initially? Dual-pane is the biggest Phase-4 line item.
3. **Facet tiering:** proposed primary = Category / Manufacturer / Scale, rest behind "More filters". Does that match how you actually slice your collection?
4. **Default density:** is Compact (name-overlay 3-up) right as the default, or should Comfortable (2-up with metadata line) be the out-of-box view? MFC's captionless failure argues against defaulting to Gallery.
5. **Type floor:** the scale bottoms at 10px badges / 12–13px card names. Comfortable with that floor, or is 11px the minimum you want anywhere?
6. **Virtualizer purity vs speed:** hand-rolled Preact hook over `@tanstack/virtual-core` (proposed — zero compat surface, we own the adapter) vs `virtua` (faster to ship, experimental grid, rides preact/compat)?
7. **MFC cookies on mobile:** accept desktop-pairing as the story ("set cookies on desktop, sync from anywhere"), or invest in a guided-webview capture spike? The devtools-console flow cannot work on mobile browsers.
8. **ThumbHash ingest scheduling:** OK to slot the scraper/backend hash-generation change (only cross-service dependency in the plan), with dominant-color placeholders as the interim?
9. **URL param compatibility:** adopt fc-frontend's exact `useFigureListState` parameter names so filtered links are portable between web and mobile apps — any reason not to?
10. **Existing extra screens:** Prices, Analytics, Calendar, DNA already exist in fc-mobile at varying quality. During the overhaul, keep them reachable under Profile as-is, or gate them off until each gets its own condensation pass?
11. **Route transitions:** move to the View Transitions API (native, but Safari 18+ only) or stay on slimmed framer-motion for iOS reach?
