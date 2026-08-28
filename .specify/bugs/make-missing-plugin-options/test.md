# Test: make-missing-plugin-options

- **Slug**: make-missing-plugin-options
- **Result**: verified
- **Branch**: fix/make-missing-plugin-options

## Reproduction (from assessment)

`zfa make Product --preset=crud --with=view --methods=get --xray` previously
aborted with `❌ Error: Invalid argument(s): Could not find an option named
"--type".`

## Re-run result

- `dart test test/commands/make_command_xray_default_test.dart` → **All tests
  passed!** (3/3, ~1m49s). This suite drives the exact failing path (graphql's
  `--type` schema property is active in the resolved plan).
- Manual smoke: `zfa make ... --cache --cache-storage=hive --ttl=60` and
  `zfa make ... --usecase --type=query` both generate and exit 0, confirming the
  other plugin-derived options are registered too.

## Regression guard

`make --help` lists the plugin-derived options (`--type`, `--cache-storage`,
`--ttl`, `--gql-type`, `--input-type`), so the ordering regression is now visible
at a glance.
