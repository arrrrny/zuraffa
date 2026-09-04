## Summary

An isolated build is only valuable if it **drops into the real app mechanically**. Today the artifacts of a sandbox-built feature (entities, mocks, views, routes, DI) land as loose files — the host must be hand-wired (register routes, bind DI, import views). For the ZikZak rebuild, `merge` must be a **contract-checked plug-in**, not a file copy.

## The contract (what "plugs in" means for ZikZak)

1. **Routes**: the feature's routes register in the host `GoRouter` via the existing route-generation barrel (`getAllRoutes()` regenerates; `zfa route` / `--with=route` already exist) — no hand-edit of the host router.
2. **DI**: the feature's bindings register through the host service locator; simulation/mock flavors bind via the existing flavor-switched DI (#893/#934 machinery) — the host boots with the feature's certified mocks at every touchpoint.
3. **Views**: the feature's pages compose behind the host's adaptive shell (`CleanView`/`AdaptiveViewState`, mobile/macos layouts) — the generated view skeletons + handcraft seam land in the presentation layer the app already uses.
4. **Gate**: after merge, the HOST suite + a **conformance check** run: routes resolve, DI graph constructs (the existing bootstrap smoke pattern), feature suite green inside the host — exit 0 or the merge is named-broken and rolled back.

## Acceptance (ZikZak-narrow — login again)

1. A login built entirely in a slice merges into `~/Developer/zik_zak` with **zero hand-edits**: `/login` route live, DI resolves, login suite green in-host.
2. A merge that would break host conformance fails with `--> fix:` naming the breach (not a broken host).
3. Merge is idempotent — re-merging an unchanged slice is a no-op verdict.

## Why

"Any agent can build the login with zfa, and I plug it into zik_zak" is the acceptance test of the whole rebuild. Without the plug-in contract, isolation just moves the hand-wiring elsewhere.

VISION: §3 (the manifest is a treaty — the merge contract is machine-verified), §4 (verdicts, never prose).

