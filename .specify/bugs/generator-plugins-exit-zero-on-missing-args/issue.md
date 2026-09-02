# Bug Issue: generator plugins exit 0 (success) when required arguments are missing — systemic exit-code contract bug

- **Slug**: generator-plugins-exit-zero-on-missing-args
- **Fetched**: 2026-09-02
- **Issue**: 767
- **URL**: https://github.com/arrrrny/zuraffa/issues/767
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

## Commands (all tested exit 0 despite printing an error)
```
zfa repository create    # ❌ Error: Missing required arguments: name    -> RC=0
zfa provider inject      # ❌ Error: Missing required arguments: dependency -> RC=0
zfa usecase create       # ❌ Error: Missing required arguments: name    -> RC=0
zfa presenter create     # -> RC=0
zfa controller create    # -> RC=0
zfa view create          # -> RC=0
```

## Expected
A command invoked without its required arguments must exit non-zero (usage error, e.g. exit 64) so scripts/CI/MCP clients can detect the failure.

## Returned
Exit code 0 in every case. The error is printed to stdout with a ❌ prefix, but the process reports success — any automation layered on zfa (scripts, CI, MCP harness) will treat these failed invocations as successful.

## Scope
Systemic: appears to be the shared capability-invocation path for manifest-driven plugins. Likely one fix in the shared runner (exit non-zero on validation failure) covers all generators.

## Comments

None.
