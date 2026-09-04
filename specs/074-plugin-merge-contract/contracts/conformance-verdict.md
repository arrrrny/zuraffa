# Contract: Conformance Verdict (merge gate)

## Gate order (any failure → rollback + exit 1)

1. **routes** — the regenerated barrel resolves every declared path.
2. **di** — the generated graph-construction test resolves every token
   per flavor in the merged host.
3. **views** — every merged view composes the host shell convention.
4. **featureSuite** — the feature's suite runs green in-host, compared
   against the pre-merge baseline (new failures only).

## JSON shape (stdout, `--json`)

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

## Summary line (final stdout line)

```text
slice-merge: feature=<f> host=<path> routes=<pass|fail> di=<pass|fail> views=<pass|fail> feature-suite=<pass|fail> rolled-back=<bool> outcome=<landed|refused|rolled-back>
```

## Rollback proof

On any failure the host restores the pre-merge snapshot; the restore is
verified by re-hashing (byte-identical), and the verdict reports
`rolled-back: true` with the failed checks' offenders named, each with
a `--> fix:` hint.
