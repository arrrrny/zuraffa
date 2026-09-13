# Contract: `zfa package plugin`

**Feature**: specs/1601-package-plugin-scaffold | **Type**: CLI surface

## Invocation

```text
zfa package plugin <name> [options]
```

`zfa package plugin` with no `<name>` (or `-h`/`--help`) prints usage and
exits 0 via the help path / 64 via the usage-error path, consistent with
`zfa package create`.

## Options

| Option | Type | Default | Meaning |
| -- | -- | -- | -- |
| `--platforms` | csv | `android,ios,macos` | adapter packages to generate; unknown or empty selection is a usage error |
| `--description` | String | role-composed default | stamped into every package's metadata + READMEs |
| `--repo` | String | `arrrrny/<name>` | GitHub `owner/name` → `repository` + `issue_tracker` |
| `--output` | String | `.` | parent directory for the monorepo |
| `--zuraffa-path` | String | (hosted `^version`) | resolve the framework from a local checkout via overrides |
| `--dry-run` | flag | off | report every file that would be created; write nothing |

## Exit codes

| Code | When |
| -- | -- |
| 0 | scaffold (or dry-run) completed |
| 1 | `PackageScaffoldException`-class failure: invalid name, existing target, empty/unknown platform, bad `--zuraffa-path` — message is operator-fixable, filesystem untouched |

## Success output (stdout)

Human-readable, in order:

1. `Plugin monorepo: <absolute monorepoPath>` (dry-run prefix: `[dry-run] `)
2. one line per package: `  ✓ <package-name> (<role>[, <platform>])`
3. `Created <N> files.`
4. `Next steps:` — `dart pub get` per package, `dart analyze`, `dart test`,
   and the publish flow pointer to `PUBLISH.md`.

## Generated family (normative shape)

Five packages for the default platform set — `<name>` (app),
`<name>_platform` (core), `<name>_android`, `<name>_ios`, `<name>_macos`
(adapters) — under `packages/`, plus root `README.md`, `PUBLISH.md`,
`LICENSE`, `CHANGELOG.md`, `.gitignore`, and `scripts/{prepare_for_publish,
publish,push_to_master}.sh`.

Per package (all roles): `pubspec.yaml`, `analysis_options.yaml`,
`README.md`, `CHANGELOG.md`, `LICENSE`, `lib/<package>.dart` barrel, at
least one `lib/src/**` source, and a `test/` harness that exercises the
generated surface through a fake channel.

Dependency invariants (see data-model.md): app → zuraffa only; core → app;
adapters → app + core; nobody → adapter. In-family constraints `^1.0.0`;
dev-only sibling resolution in `dependency_overrides`.

## Validation rules (error messages MUST name the rule)

- name: snake_case, letter-first (`^[a-z][a-z0-9_]*$`)
- target directory must not exist
- platforms: non-empty subset of `android, ios, macos`
- `--zuraffa-path` must be an existing directory
- monorepo target must not collide with the output parent itself
