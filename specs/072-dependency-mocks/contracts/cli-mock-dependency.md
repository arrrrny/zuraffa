# Contract: `zfa mock dependency <Name>` (CLI surface)

## Invocation

```text
zfa mock dependency <Name> [--project <dir>] [--dry-run] [--force] [--verbose]
```

`<Name>` MUST match a declared row in the feature's External Dependencies
& Contracts table (resolved through the plan artifact's dependency rows
for the pinned feature, or every feature when unpinned — same resolution
rules as the tdd plugin's registry scans).

## Behavior

1. Resolve the declared row; undeclared name → exit 2:

   ```text
   zfa mock dependency: no declared dependency row named "Vendure"
   --> fix: add the row to `## External Dependencies & Contracts`
       (`| Vendure | <type> | <signatures> | <P1|P2|P3> |`), then re-run.
   ```

2. Parse the contract cell into signatures. Malformed text → exit 3,
   naming the row and the malformed segment
   (`--> fix: fix the signature to `name(Params) -> Return``).
3. Emit the deterministic artifact package (see
   dependency-mock-surface.md) under the feature's mock layout.
4. Record artifacts in the feature registry
   (`dependency:<Name>` provenance, row spec line).
5. Idempotent re-run: byte-identical artifacts → success, no diff noise;
   changed row → regenerate + surface the change in output.

## Machine summary line (final stdout line)

```text
mock-dependency: name=<Name> kind=<kind> priority=<P1|P2|P3|none> methods=<n> outcome=<generated|unchanged|regenerated> feature=<feature>
```

Exit codes: 0 generated/unchanged/regenerated · 2 undeclared · 3
malformed contract · 4 duplicate dependency name · 5 unsupported kind
refused.

## Duplicate names

Two rows with the same dependency name → exit 4 naming both spec lines.
