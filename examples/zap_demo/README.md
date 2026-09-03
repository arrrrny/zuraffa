# ZAP Demo — a non-MCP client driving a full TDD loop (spec 071, issue #809)

This directory is the "one external demo" of the Zuraffa Agent Protocol:
an INDEPENDENT client, built only against the published contract
(`specs/071-zuraffa-agent-protocol/contracts/zap.md` + `schemas/` +
`golden/`), drives a real `zfa zap serve` host through a complete
red → green → verify loop with a checkpoint save + restore in the middle —
no MCP anywhere.

## The files

| File | Role |
|------|------|
| `foreign_client.dart` | The independent ZAP client. Pure `dart:io` + `dart:convert` + a local `sha256.dart` — ZERO zuraffa imports, no pubspec. Spawns the host itself. |
| `sha256.dart` | A self-contained FIPS 180-4 SHA-256 (verified against the standard test vectors) so the client can recompute the evidence chain without any package dependency. |
| `tdd_loop.dart` | The mission's steps: `red` (a real failing check, exit 1), `green` (the fixed check, exit 0), `verify` (the suite, exit 0). |

## Run it

From the repo root (after `dart pub get --no-example`):

```bash
dart examples/zap_demo/foreign_client.dart
```

What you will see (stderr carries the session log, stdout the verdict):

```
client: submitting mission 1 (red + green)
client: mission 1 receipt verdict=pass
client: checkpoint save
client: checkpoint restore cp-<stateId>
client: submitting mission 2 (verify)
{"chainVerified":true,"hostCommand":"dart bin/zfa.dart zap serve",...}
```

The final stdout line is the machine verdict:
`chainVerified: true` means the client recomputed the sha256 evidence
chain from the evidence packets it received and it MATCHED the receipt's
`chainDigest` — the host's verdict is independently verified. The process
exits with the receipt's exit code (0 pass / 1 fail).

## The session, verbatim

```
client                                          host (dart bin/zfa.dart zap serve)
  │ mission{steps:[red,green], budget:8} ───────▶ schema + budget + policy gates
  │◀── evidence{s1, phase:red, exit:1} ────────── real subprocess, no shell
  │◀── evidence{s2, phase:green, exit:0} ────────
  │◀── receipt{verdict:pass, chainDigest} ─────── TDD discipline certified
  │ checkpoint{kind:save} ───────────────────────▶ snapshot
  │◀── checkpoint{kind:saved, stateId, digest} ──
  │ checkpoint{kind:restore, stateId} ───────────▶ session rebuilt
  │◀── checkpoint{kind:restored, steps:2} ────────
  │ mission{steps:[verify]} ─────────────────────▶ session continues
  │◀── evidence{s3, phase:verify, exit:0} ────────
  │◀── receipt{verdict:pass, chainDigest} ──────── cumulative chain
  │ (client recomputes the chain over s1..s3 → equal → exit 0)
```

## Where the tests live

`test/zap/zap_interop_test.dart` (A4/A5/A6) drives this demo and the
reference client against the SAME unmodified host entry point — the
interop proof for issue #809's second done-when criterion.
