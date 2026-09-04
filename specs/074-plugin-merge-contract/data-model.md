# Data Model: Plug-In Merge Contract (074)

## Entities

### MergeContract (new)

The declared facts a landing must satisfy — read from the slice
manifest + host route/DI declarations.

| Field | Type |
| --- | --- |
| feature | String |
| routes | `List<RouteDecl>` (path → page) |
| bindings | `List<BindingDecl>` (token, flavor coverage mock/real) |
| viewArtifacts | `List<String>` (paths that must compose the shell) |
| suiteCommand | String (host suite command from the profile) |

### HostBaseline (new)

Pre-merge byte + suite snapshot.

| Field | Type |
| --- | --- |
| files | Map<path, contentHash> of touched-file set |
| copies | Map<path, bytes> for restore |
| suiteResults | Map<testName, passFail> (pre-merge) |

### ConformanceVerdict (new, JSON)

```json
{
  "check": "slice-merge-conformance",
  "feature": "<feature>",
  "routes": {"pass": true, "resolved": ["/login"], "offenders": []},
  "di": {"pass": true, "tokensResolved": 4, "offenders": []},
  "views": {"pass": true, "offenders": []},
  "featureSuite": {"pass": true, "newFailures": []},
  "passed": true
}
```

Exit: 0 all pass · 1 any fail (host rolled back byte-identical).

### RouteDecl / BindingDecl

| Entity | Fields |
| --- | --- |
| RouteDecl | path, page, moduleName |
| BindingDecl | token, flavors [mock, real], module |

## Invariants

1. I1: rollback restores byte-identical trees (re-hash proof).
2. I2: the gate compares against the CURRENT baseline — pre-existing
   reds never fail, new reds never pass.
3. I3: every offender message names the artifact/token/behavior + a
   `--> fix:` hint.
4. I4: re-merge with unchanged artifacts is a byte no-op.
