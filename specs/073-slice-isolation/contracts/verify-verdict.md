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

### No-suite state (suiteState)

A sandbox with **no `test/` directory** declares no suite at all:
nothing ran and nothing failed. The verdict carries the named
`noSuite` marker — `{"pass": true, "offenders": [], "noSuite": true}` —
and the summary line renders `suite=none`. The verdict is not failed by
it (a suite-less sandbox is verifiable and mergeable), but the absence
is never rendered as a plain `pass`/green.

A `test/` directory **present without a runnable suite** (`*_test.dart`)
is still a failure — the runner's "no tests found" exit is an error
(absence never passes, errors-are-an-api).

`slice merge` mirrors the same rule on the host: a host with no
`test/` directory is reported as `Host suite: none declared.`, never as
green, and must not fail the merge.

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
slice-verify: feature=<f> self-containment=<pass|fail> mock-certification=<pass|fail> suite=<pass|fail|none> outcome=<verified|failed>
```

`suite=none` is the named no-suite state above (the sandbox declares no
`test/` directory); it does not fail the verdict.

Exit: 0 verified · 1 failed (offenders named in the verdict).

## No-lexicon rule

An absent ledger/manifest section reports as absent — never as passing
(absence of data is not proof).
