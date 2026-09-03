# zfa tdd realize — Command Docs

`zfa tdd realize <entity|behavior> --adapter <RealAdapter>` swaps a mock
datasource for the real adapter behind the SAME generated interface, gated
by the contract suite and the real-vs-mock differential (spec 913; parent
#908 Mock-First Realization).

## The five-phase contract

1. **DI rebind** — the mock datasource class symbol is swapped for the
   adapter class at the generated binding sites (GetIt registrations,
   repository wiring, slice injection). Imports are fixed, `domain/`
   interface files are proven byte-identical, and the mock implementation
   itself is unbound, never rewritten. The adapter class must already
   exist in `lib/` — realize NEVER generates real implementations.
2. **CONTRACT GATE** — the MOCK-era suite (the feature's registered test
   files) runs UNCHANGED, first against the mock binding (baseline,
   pre-rebind), then against the real binding. A red baseline blames the
   mock era (`mock-broke-contract`); a green baseline + red real run
   blames the real impl (`real-broke-contract`) and rolls the rebind
   back, restoring the exact mock-era bytes.
3. **DIFFERENTIAL GATE** — real vs mock run the same committed fixtures
   under `specs/<feature>/tdd/fixtures/` (each `{"id", "input",
   "mockOutput"?}`). The output diff is a per-field drift report at
   `tdd/differential-report.json`. The threshold comes from `.zfa.json`:
   ```json
   {"tdd": {"realizeDifferentialThreshold": 0.0}}
   ```
   Default `0.0` is strict — any drift blocks until the threshold is
   consciously raised. A missing fixtures directory is reported
   `skipped`, never silently passed.
4. **NUANCE RECEIPTS** — hand-written deltas on the realization surface
   (binding files + the mock implementation) are detected against their
   last provenance baseline (`.zfa/receipts/` digests or the ledger's own
   diff-hash). Hand-deltas are legal; UNGATED hand-deltas are not:
   ```bash
   zfa tdd realize User --adapter UserRealAdapter \
     --hand-delta lib/src/di/... --reason "why the delta is legal"
   ```
   Each gated delta is recorded as (file, reason, diff-hash) in
   `specs/<feature>/tdd/provenance-ledger.json`.
5. **ERA-TAGGED EVIDENCE** — a successful transition persists
   `tdd/realize-state.json` (`realize.v1`: era `MOCKED -> REAL`, adapter,
   gate evidence) and appends a hash-chained, era-tagged entry
   (`- era: REAL`) to `tdd/cycle-log.md`.

## The fixture driver protocol

The differential gate executes fixtures through BOTH bindings via a
project-owned driver, because only the project knows its generated
interface's method names. Create `tool/realize_driver.dart`:

```dart
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final binding = _arg(args, '--binding'); // 'mock' | 'real'
  final entity = _arg(args, '--entity');
  final input = jsonDecode(await stdin.readAsString()) as Map<String, dynamic>;

  // Construct the datasource through the SAME generated interface.
  final ds = binding == 'mock'
      ? UserMockDataSource()      // your generated mock
      : UserRealAdapter();        // your real adapter

  // Map the fixture input to interface calls, e.g.:
  final out = switch (input['op']) {
    'getById' => await ds.getById(input['id'] as String),
    _ => throw StateError('unscripted op ${input['op']}'),
  };

  stdout.write(jsonEncode(out ?? const <String, dynamic>{}));
}

String _arg(List<String> args, String name) =>
    args[args.indexOf(name) + 1];
```

The driver reads the fixture input JSON on stdin and prints the output
JSON object on stdout. Fixtures without a committed `mockOutput` execute
the mock binding through the driver to capture the reference (mocks are
deterministic — bug #832).

## Machine summary

The last stdout line is machine-readable:

```
realize: entity=<E> adapter=<A> feature=<F> contract=<green|real-broke-contract|mock-broke-contract>
         differential=<pass|drift|skipped|runner-error> drift=<r> threshold=<t>
         handDeltas=<n> era=<MOCKED|REAL|MOCKED->REAL>
         result=<realized|already-real|blocked|runner-error>
```

Exit codes: `0` realized (or already-real, idempotent), `1` blocked by a
gate or refused input, with the side-attributing verdict on stdout.
