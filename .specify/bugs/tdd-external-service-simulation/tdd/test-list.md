# TDD Test List — tdd-external-service-simulation (bug #832)

Branch: `fix/832-tdd-external-service-simulation` · Spec source: `.specify/bugs/tdd-external-service-simulation/issue.md` + `assessment.md`

| # | Behavior | Test files | Tier | Pins |
|---|----------|-----------|------|------|
| B1 | `zfa simulate` is a registered top-level command (VISION §9) | `test/simulation/simulate_command_test.dart` | fast (in-process `CliRunner.runCapturing`) | `zfa --help` lists `simulate`; `zfa simulate --help` documents `scaffold`/`scenario`/`family` |
| B2 | Automated fixture commitment: `--scaffold` materializes the certified world under `<feature>/tdd/fixtures/` and hashes it into the cycle-log evidence | same | fast | fixture files + `manifest.json` exist; cycle log gains `- behavior: <slug>-fixtures`, `- kind: fixtures`, `- hash:` (64 hex), `- command:` line; re-run refuses without `--force`, re-certifies with it |
| B3 | Deterministic golden replay: `--scenario golden` boots the committed world, installs the guard, replays every fixture, prints a machine verdict | same | fast | `SIMULATE golden -> GREEN (n/n plays, guard=active, digest=...)` exit 0; missing/tampered world prints `RED` and exits non-zero |
| B4 | Network-isolation guard self-certification: `--verify-guard` | same | fast | blocked socket probe reports `SIMULATE guard ok` (exit 0) without dialing |
| B5 | Guard soundness + no false positives | `test/simulation/network_isolation_guard_test.dart` | fast | `Socket.connect`/loopback/`HttpClient` all fail with `NetworkIsolationViolation` before any dial; file I/O + pure compute unaffected; install idempotent; uninstall restores a real socket path (loopback connect refused, not violated) |
| B6 | The 5 adapter families are scripted and deterministic under the guard | `test/simulation/simulation_adapters_test.dart` | fast (guard installed for the whole suite) | FirebaseAuthAdapter: signed-in/out, `user-not-found`/`wrong-password`/`user-disabled`, register duplicate `email-already-in-use`, deletion + `requires-recent-login`; VendureAdapter: golden query/mutation verbatim, unknown-op refusal, scripted `STOCK_ERROR`; RestAdapter: fixtures (incl. query-string + PUT/DELETE resource-level fallback), scripted 500, deterministic 404, latency injection; AdMobAdapter: `loaded`/`shown`/`dismissed`, scripted `no-fill`/`ad-not-ready` fail codes; OtelAdapter: real SDK pipeline capture, status + attribute assert, implements the production `SpanExporter` |
| B7 | Fixture infrastructure: SHA-256 manifest, tamper refusal, scaffold determinism | `test/simulation/simulation_world_test.dart` | fast | manifest schema-1 with per-file sha256 + digest; two scaffolds of the same family hash identically; one flipped byte → `FixtureMismatch` on load |
| B8 | DI bootstrap: same production interface, different certified binding | same | fast | `SimulationWorld.bindTo(ZuraffaContainer)` registers `RestContract`/`AuthContract`/`VendureContract`/`AdContract`; `container.resolve<RestContract>()` IS `world.rest`; a generated-style `PriceDataSource` runs GREEN through DI with zero network |

## Success criteria (from issue #832)

- `zfa simulate` adapter per service family (FirebaseAuth, Vendure, Rest, AdMob, Otel) per VISION §9 — PROVED by B1/B3/B6 (all five families scripted, deterministic, guard-active)
- Data sources take the adapter via DI in test bootstrap — same production interface, different certified binding — PROVED by B8
- Fixtures committed under `specs/<feature>/tdd/fixtures/` and hashed into cycle-log evidence, automated — PROVED by B2/B7 + the committed fixture worlds (10 affected specs, per-family digests identical)
- Network-isolation guard: hosted TDD tests fail if they open a real socket, sound (no false positives) — PROVED by B4/B5 + the full fast-tier chunked run (0 new failures)
