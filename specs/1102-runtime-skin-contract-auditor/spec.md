# Spec 1102 — runtime skin-contract auditor: the live tree checks itself every frame

GitHub issue: arrrrny/zuraffa#1102

## Problem

The skin contract has two enforcement tiers today: static source guards
check the recipe (`zfa tdd run-skin`'s conformance mode — spec 1005 —
reads the SkinEvent stream the tests emit, and the `_XRaySkinHandEdit`
annotation cross-check), and widget tests check the cake once in CI
(the paired per-behavior test files). Nothing checks the cake **in the
oven**: after CI is green, a chaos edit (or a bad merge, or a stale
conditional) can break the skin contract at RUNTIME and nothing on the
screen says so. The 006-login-skin pilot (zik_zak sandbox) proved the
third tier live:

1. Chaos edit `'Continue with Google'` → `'Continue with Goggle'` → a
   red violation banner appeared (`[google-text] Continue with Google
   renders`) on the first audited frame — no test run, no rebuild.
2. Revert + hot reload → the banner cleared on the next frame.
3. Guest sign-in driven through the real engine flow → the route
   observer validated the `deal_list` push against the contract route
   table.

The pilot kit lives in a sandbox (`lib/tdd/006-login-skin/
skin_contract_auditor.dart`). This spec productizes it into the
framework: a debug-only kit that makes every hand-written skin view
aware of its own contract — auditing the live widget tree on the
audited frames and the route stack on every push, with violations
surfacing as an impossible-to-miss on-screen banner.

### What does NOT exist today (the gap)

- No `SkinContractKit` in the framework: no `TreeFacts`, no
  `SkinContractRow`, no route contract table, no audit bus, no
  scheduler — nothing an emitted view or app shell can mount.
- No generated auditor wrap: `ViewClassBuilder` emits the `Widget get
  view` seam with no auditor around it.
- No route observer in the generated app shell: `AppShellBuilder`
  emits `MaterialApp.router` + a bare `GoRouter` with no
  `NavigatorObserver` and no violation banner chrome.
- The generated DI is not idempotent: calling
  `setupDependencies(getIt)` twice throws (get_it double
  registration), so the test lane cannot re-enter setup. No
  `resetDependencies()` test hook exists.
- Anchor identity is stringly-typed conventions only: no typed anchor
  protocol (`ZfaButton.contractId/contractEnabled`, issue #1099's
  preview) and no `debugTapAnchor` VM-service driver seam — driver
  harnesses must synthesize clicks that never reach the Flutter view
  on macOS.
- No `zfa skin` command surface: nothing emits the kit, and nothing
  statically verifies the emitted route-contract table against the
  routing barrel.

## Pilot design lessons carried into this spec

1. **The contract caught a real bug tests never saw** — macOS layout
   had NO loading scrim; mobile-only testing had pumped only the
   mobile slot. Rows must be able to encode platform gating.
2. **The overridable skin seam is `Widget get view`, not `build`.**
   `CleanViewState.build` is `@nonVirtual`; generated views must
   expose the auditor wrap at the view getter.
3. **WidgetsApp always pushes `/` on cold start** — the route
   contract must treat the navigator root as conforming by
   construction, or every app flags a phantom violation at launch.
4. **Generated DI is not idempotent** — unregister-first
   registrations + a `resetDependencies()` test hook.
5. **A self-rescheduling post-frame auditor never lets
   `pumpAndSettle` settle** — the productized kit must SUBSCRIBE
   (dependency change, route events), never poll.
6. **Anchor identity needs to be typed** — `ZfaButton` with
   `contractId`/`contractEnabled` turns the `zfa:` key protocol into
   types (see #1099).
7. **Drive skins through the Dart VM service** — a
   `debugTapAnchor(String zfaKey)` seam + registry gives a
   deterministic driver on every platform.
8. **The contract table is engine/skin glue** — rows encode platform
   gating read from `Theme.of(context).platform` (the same
   override-aware source the layout gates on), so auditor and skin
   can never disagree about platform.

## Deliverables

1. **`SkinContractKit` core (pure Dart, in the framework)** —
   `lib/src/skin/` + the public barrel `lib/skin.dart`, importable by
   generated Flutter apps (they already depend on
   `package:zuraffa`):
   - `TreeFacts` — an immutable snapshot of the live tree: rendered
     texts, `zfa:` anchors, progress-indicator flag, platform (from
     `Theme.of(context).platform` — lesson 8). Value equality so the
     scheduler can skip no-op audits.
   - `SkinContractRow` — `id` + `requirement` +
     `bool Function(TreeFacts)` check, with named helpers
     (`textRenders`, `anchorExists`, `progressIndicator`) that accept
     platform gating.
   - `SkinViolation` + kind (`widget`/`route`) — stable display line
     (`[google-text] Continue with Google renders`), JSON shape.
   - `RouteContractTable` — allowed route names; the navigator root
     `'/'` conforms by construction (lesson 3); `validatePush` →
     violation or null.
   - `SkinAuditController` — the pure bus core: publish/clear with
     change detection (the chrome only rebuilds on real change),
     listener protocol, bounded history.
   - `SkinAuditScheduler` — subscribe-don't-poll (lesson 5):
     `markDirty(reason)` + `consumeDirty()`; audits run only when
     dirty, never self-reschedule.
   - `ZfaAnchors` + `ZfaAnchorRegistry` — the typed anchor protocol:
     `zfa:` key mapping, registry of anchor → tap handler,
     `tap(anchorId)` (the `debugTapAnchor` core).
2. **Flutter glue emission** — `SkinContractKitBuilder` emits
   `<outputDir>/skin/skin_contract_auditor.dart` into the target
   project (template-string emission, the XRay-bridge/app-shell
   precedent — the framework stays pure-Dart, Constitution VII):
   - `inspectTree(Element root)` → `TreeFacts` (texts, `zfa:` keys,
     progress indicators, platform from Theme).
   - `SkinContractAuditor` widget — wraps a view at the view getter;
     subscribes (dependency changes mark dirty), audits on the post
     frame ONLY when dirty.
   - `SkinRouteContractObserver` — `NavigatorObserver` validating
     every push against the `RouteContractTable`; inert in release.
   - `SkinAuditBus` + `SkinAuditChrome` + `SkinViolationBanner` —
     the debug chrome: an impossible-to-miss red banner listing live
     violations, mounted through `MaterialApp.router`'s `builder`.
   - `ZfaButton` — typed anchor: `contractId`, `contractEnabled`,
     `onPressed`; carries `ValueKey('zfa:<contractId>')` and
     registers its tap handler in the anchor registry.
   - `debugTapAnchor(String zfaKey)` — the VM-service driver seam
     (lesson 7): registry lookup + real onPressed invocation.
   - Everything behind `kDebugMode` — zero release cost.
3. **Auditor wrap generation** — `--skin` on view generation:
   `ViewClassBuilder` wraps the view getter's widget in
   `SkinContractAuditor(rows: k<View>SkinRows, child: ...)` and
   emits the starter row list (the hand-edit seam: users extend the
   list, generation never clobbers it).
4. **App shell mount** — `--skin-audit` on `zfa app shell`: emits
   the kit (skip-if-exists, the xray-decks precedent), mounts the
   route observer on the `GoRouter` (`observers:`) with a table
   built from `getAllRoutes()` + root, and wraps the router in
   `SkinAuditChrome` via `MaterialApp.router(builder:)`.
5. **Idempotent DI** — generated registrations become
   unregister-first (`if (getIt.isRegistered<T>()) getIt
   .unregister<T>();` before every register), and
   `resetDependencies(GetIt getIt)` is generated alongside
   `setupDependencies` (full regeneration, the AST-merge update
   path, and the day-zero bootstrap barrel).
6. **Route contract table + static verify** — `zfa skin kit
   [--route <name>]...` emits the kit with a `kSkinRouteContract`
   table (explicit routes, or the routing barrel's declared routes
   when no `--route` is given); `zfa skin verify` statically
   reconciles the kit's table against the routing barrel — honest
   verdicts `match` / `drift` / `insufficient-input`, pinned exit
   codes 0/1/2, `--> fix:` lines, `--json` envelope (the
   route-verify precedent).
7. **`zfa skin` command group** registered on the CLI
   (`skin kit`, `skin verify`).

## Design

### Purity split

zuraffa's `lib/` never imports Flutter (Constitution VII — issue
#512 guards it). The kit therefore ships as two layers:

- the **contract logic** (facts, rows, tables, violations, bus,
  scheduler, anchor registry) is pure Dart and lives IN the
  framework — importable at runtime by generated Flutter apps via
  `package:zuraffa/skin.dart` (apps already depend on zuraffa for
  their DI tree);
- the **Flutter glue** (the element walk, the auditor widget, the
  route observer, the banner, the typed button) is EMITTED into the
  target project as one self-contained file — the same emission
  strategy as the app shell and the XRay bridge launcher.

### Subscribe-don't-poll (lesson 5)

The pilot's auditor rescheduled a post-frame callback on every post
frame — `pumpAndSettle` could never settle. The productized auditor
keeps a `SkinAuditScheduler`: build/dependency changes mark it
dirty; the post-frame callback runs only when dirty was consumed and
returns without rescheduling when the tree is quiet.

### Route table conformance (lesson 3)

`RouteContractTable.validatePush` treats `'/'` and unnamed/null
routes as conforming by construction: WidgetsApp always pushes `/`
on cold start, and shell bookkeeping pushes unnamed helper routes.
The shell's table is built from `getAllRoutes()` (every route the
generated router declares) so declared = conforming; a hand-coded
`context.go('/undeclared')` is the violation.

### Idempotency (lesson 4)

Every generated registration site emits the unregister-first guard
for the type it registers, so `setupDependencies` is callable twice
in one process (hot restart under test, re-entered test lanes).
`resetDependencies(getIt)` (which resets the container) is generated
alongside it and in the day-zero bootstrap barrel.

## Acceptance criteria

- `zfa skin kit` emits a kit file that contains every mount-point
  symbol, imports `package:zuraffa/skin.dart`, formats clean, and is
  idempotent (same input → same bytes).
- `zfa skin verify` reports `match` (exit 0) when the kit table
  agrees with the routing barrel, `drift` (exit 1) with per-route
  findings + `--> fix:` lines, `insufficient-input` (exit 2) when
  the kit or the barrel is missing — and `--json` emits the verdict
  envelope.
- `--skin` view generation wraps the view getter in
  `SkinContractAuditor` with a starter row list; the wrap survives
  regeneration (flag-gated: without `--skin` the output is
  byte-identical to today's).
- `--skin-audit` app shell generation mounts the observer + chrome;
  without the flag the output is byte-identical to today's.
- Generated DI carries unregister-first guards +
  `resetDependencies`; calling `setupDependencies` twice is legal by
  construction.
- The pure core's tests prove: root-route conformance, platform
  gating read from facts, change-detecting bus, one-shot dirty
  consumption, typed-anchor round trip + unknown-anchor refusal,
  `debugTapAnchor` resolving through the registry.
- `dart analyze` shows zero NEW issues vs the master baseline;
  `tools/run_tests_chunked.sh` green (modulo the recorded master
  pre-existing failures, re-verified identical on pristine master);
  `dart format .` leaves zero diffs.

## Out of scope

- zuraffa_ui / #1099's full identified-component family (this spec
  ships only `ZfaButton` as the typed-anchor protocol proof).
- #1098's typed `FeatureContract` (the route table's eventual home);
  this spec's table is derived from the routing barrel + `--route`
  flags.
- The example app's own skin rewrite (the pilot receipts live in
  the zik_zak sandbox; the framework productization is this spec's
  deliverable).
