# Bug Issue: Speckit CLI Commands: 10 commands missing from extension manifest

- **Slug**: speckit-cli-commands-10-commands-missing-from-extension-mani
- **Fetched**: 2026-08-27T14:26:41.112828+00:00
- **Issue**: 499
- **URL**: https://github.com/arrrrny/zuraffa/issues/499
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

# Bug Assessment: Missing Commands in Speckit Extension

**Feature**: 003-speckit-cli-commands  
**Bug ID**: 003-speckit-cli-commands-missing-commands  
**Date**: 2026-08-26  
**Commit**: `614e648`  
**Severity**: Medium  

---

## Summary

The Zuraffa Speckit extension is missing **10 commands** from the `zfa manifest` output. These commands exist in the CLI but do not have corresponding `.md` files in the extension, nor are they registered in `extension.yml`.

---

## Root Cause

The extension commands are **auto-generated** from `zfa manifest` JSON output via the `generate-commands` script. The script appears to not cover all plugin subcommands, or the generation logic filters out certain plugin types.

---

## Evidence

### Manifest Commands (53 total)
```
$ dart run bin/zfa.dart manifest | jq 'length'
53
```

### Extension .md Files (43 total)
```
$ find .specify/extensions/zuraffa/commands -name "*.md" | wc -l
43
```

### Missing Commands (10)

| # | Plugin | Subcommand | Full CLI Command |
|---|---|---|---|
| 1 | api | create-api-bridge | `zfa api create-api-bridge` |
| 2 | gym | create | `zfa gym create` |
| 3 | mock | json | `zfa mock json` |
| 4 | mcp | scaffold | `zfa mcp scaffold` |
| 5 | module | create_module | `zfa module create_module` |
| 6 | route | deep-link | `zfa route deep-link` |
| 7 | route | shell | `zfa route shell` |
| 8 | sync | enable | `zfa sync enable` |
| 9 | strategy | create | `zfa strategy create` |
| 10 | gql | generate | `zfa gql generate` |

---

## Impact

### Functional Impact
- **AI agents cannot invoke these 10 commands** through the Speckit extension
- Commands are only available via direct CLI usage
- Breaks the "all CLI commands available through extension" requirement (FR-001, SC-001)

### User Stories Affected
- **US1** (P1): "AI agent uses extension commands to scaffold features" - incomplete coverage
- **US2** (P2): "Commands organized by category" - these commands have no category
- **SC-001**: "All plugin commands from `zfa manifest` are available as extension .md files" - **FAILS**

---

## Technical Analysis

### Extension Generation Flow
1. `zfa manifest` outputs 53 plugin commands with schemas
2. `generate-commands` script parses manifest and creates `.md` files
3. `.md` files are organized into category subdirectories
4. `extension.yml` registers commands with aliases

### Gap Location
The gap is in step 2 - the generation script. The existing `generate-commands.md` command file describes the regeneration process but the actual generation code may be incomplete.

### Files to Investigate
- `.specify/extensions/zuraffa/commands/generate-commands.md` - documents the script
- Generation logic (likely in zfa CLI source, not in extension)

---

## Reproduction Steps

1. Run `zfa manifest` and count commands: 53
2. Count extension `.md` files: 43
3. Compare plugin/subcommand pairs - 10 missing
4. Verify missing commands not in `extension.yml` provides section

---

## Suggested Fix

### Option 1: Regenerate with Complete Coverage (Recommended)
Update the `generate-commands` script to handle all plugin types, then re-run:
```bash
zfa generate-commands --force
```

### Option 2: Manual Addition
Manually create 10 missing `.md` files and update `extension.yml`.

### Option 3: Investigate Generation Script
Check why certain plugins (api, gym, mock json, mcp, module, sync, strategy, gql) are excluded.

---

## Assessment Verdict

**Type**: Missing Feature / Incomplete Generation  
**Priority**: P2 (blocks full CLI parity)  
**Effort**: Small (regenerate or add 10 files)  
**Risk**: Low (no breaking changes, only additions)

---

## Next Steps

1. **File GitHub issue** on `arrrrny/zuraffa` with this assessment
2. **Investigate** `generate-commands` script in zfa CLI source
3. **Regenerate** extension commands with full coverage
4. **Add tests** for manifest coverage (A4) and regeneration reproducibility (A5)

## Comments

None.
