# Contract: Slice Verify Verdict

## Invocation

```text
zfa slice verify [--project <slice-root>] [--json]
```

## Checks (all three, always)

| check | pass condition | offenders named as |
| --- | --- | --- |
| selfContainment | no sandbox file resolves outside the sandbox root (imports, assets, path refs) | file + offending reference |
| mockCertification | every manifest `dependencyBindings` entry binds an existing certified mock artifact | unbound dependency name |
| suiteState | the sandbox suite (profile `file`/`suite` commands at the sandbox root) is green | failing test names |

## JSON shape (stdout, `--json`)

```json
{
  "check": "slice-verify",
  "feature": "<feature>",
  "selfContainment": {"pass": true, "offenders": []},
  "mockCertification": {"pass": true, "offenders": []},
  "suiteState": {"pass": false, "offenders": ["test/a1_test.dart: A1 — nav [E]"]},
  "passed": false
}
```

Human output stays the default; the summary line is the final stdout
line:

```text
slice-verify: feature=<f> self-containment=<pass|fail> mock-certification=<pass|fail> suite=<pass|fail> outcome=<verified|failed>
```

Exit: 0 verified · 1 failed (offenders named in the verdict).

## No-lexicon rule

An absent ledger/manifest section reports as absent — never as passing
(absence of data is not proof).
