# Scratch PR — zikzak-review E2E trigger

This file exists only to trigger the zikzak-review webhook pipeline end-to-end
against the REAL pool (forklift `bin/server_real.dart` on :8888), replacing the
wire-compatible stub used in the earlier verification round.

Expected: a review lands on this PR as `zikzak-ai[bot]`, created by a pool
`cloud` task. The PR will be closed without merging once the bot review posts.
