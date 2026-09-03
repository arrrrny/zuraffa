# Quickstart: ZAP v0.1 (spec 071, issue #809)

## 1. Self-test the reference implementation

```bash
zfa zap conform                 # text: per-check lines + machine summary
zfa zap conform --format json   # one verdict object (CI-able, #778)
zfa zap conform --drift-dir specs/071-zuraffa-agent-protocol
```

Exit 0 = the conformance suite passes (goldens, rejections, reference
client session); exit 1 = a check failed. `--drift-dir` additionally
fails if the committed `schemas/` + `golden/` files drifted from the code.

## 2. Serve the protocol

```bash
zfa zap serve
```

Reads NDJSON ZAP messages on stdin, writes replies to stdout (human logs
on stderr). Exits 0 at EOF. See `contracts/zap.md` for the full message
grammar.

## 3. Publish the contract

```bash
zfa zap schema --type mission            # print one schema
zfa zap schema --export <dir>            # write schemas/ + golden/
```

The committed copy lives in this spec directory; the drift gate keeps it
honest.

## 4. Run the external demo (non-MCP client, full TDD loop)

```bash
dart examples/zap_demo/foreign_client.dart
```

Watch an independent, zero-import client drive red → green → verify with
a checkpoint save + restore, and verify the receipt's chain digest from
the outside. Details: `examples/zap_demo/README.md`.

## 5. Use the reference client in Dart

```dart
import 'package:zuraffa/zap.dart';

final host = await Process.start('dart', ['bin/zfa.dart', 'zap', 'serve']);
final client = ZapClient.overProcess(host)..start();
final receipt = await client.submit(mission);
if (!client.verifyReceipt(receipt)) throw 'the host lied';
```

## 6. What a mission looks like

```json
{
  "zap": "0.1", "type": "mission", "id": "m-1", "ts": "2026-09-03T10:00:00Z",
  "missionId": "demo-tdd", "agent": "claude", "goal": "Drive a full TDD loop",
  "budget": {"maxSteps": 8},
  "policy": {"riskTier": "standard", "toolAllowlist": ["dart"]},
  "steps": [
    {"id": "s1", "command": "dart examples/zap_demo/tdd_loop.dart red", "phase": "red"},
    {"id": "s2", "command": "dart examples/zap_demo/tdd_loop.dart green", "phase": "green"}
  ]
}
```

The host validates it against `schemas/mission.schema.json` (closed
envelope — hallucinated fields are schema errors), enforces the budget
and the tool allowlist BEFORE executing anything, runs each step as a
real subprocess without a shell, streams one evidence packet per step,
and finishes with a receipt whose `chainDigest` you recompute and
compare. An undisciplined loop (a red that passes, a green that fails, a
green with no red ever witnessed) executes fine — and FAILS in the
receipt, with the violated rule named.
