# Data Model: Slice-Driven Isolation (073)

## Entities

### SliceManifest (existing, extended)

The cut's declared facts — the treaty verify checks and merge lands.

| Field | Type | Notes |
| --- | --- | --- |
| feature | String | feature directory name |
| hostRoot | String | absolute host path at cut time |
| routes | `List<String>` | declared route paths/pages from the Presentation contract |
| dependencyBindings | `List<DependencyBinding>` | per declared dependency: name, kind, certified mock artifact path |
| artifactInventory | `List<String>` | sandbox-relative paths cut carries |
| journal | String | tdd journal/registry location inside the sandbox |
| verdict | SliceVerdict? | latest verify result (null until verified) |

### DependencyBinding (new)

| Field | Type |
| --- | --- |
| dependency | String |
| kind | String (service/storage/channel) |
| mockArtifact | String (sandbox-relative path of the certified mock/fake) |
| diToken | String (the sandbox DI registration key) |

### SliceVerdict (new)

```json
{
  "selfContainment": {"pass": true, "offenders": []},
  "mockCertification": {"pass": true, "offenders": []},
  "suiteState": {"pass": true, "offenders": []},
  "checkedAtCommand": "zfa slice verify"
}
```

Machine contract: exit 0 iff all three pass; offenders carry
sandbox-relative paths and `--> fix:` hints.

### Sandbox layout (what cut emits, deterministically)

```text
<slice-root>/
├── pubspec.yaml                 # standalone package (no host path deps)
├── lib/
│   ├── main.dart                # shell bootstrap (mock DI)
│   ├── router.dart              # routes() -> feature routes only
│   ├── di.dart                  # bind(token, certified mock) per dependency
│   └── <feature artifacts>      # generated feature code
├── specs/<feature>/             # spec + tdd artifacts + journal/registry
└── test/                        # feature suites (sandbox-scoped)
```

## Invariants

1. I1: every sandbox file resolves inside the sandbox root
   (self-containment is checkable by scan).
2. I2: every declared dependency has exactly one certified binding.
3. I3: identical cut inputs ⇒ byte-identical sandbox scaffolding.
4. I4: the verdict consumed by merge is the verdict of the CURRENT
   sandbox state (stale verdicts refuse with a re-verify hint).
