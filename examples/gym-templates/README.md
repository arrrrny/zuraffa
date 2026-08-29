# GYM Templates for zuraffa's sister packages

This directory ships **reference `.gym/` artifacts** for the three
sister packages we develop daily alongside zuraffa:

- `zorphy/` — state management library
- `zikzak_inappwebview/` — Flutter InAppWebView wrapper
- `vendure-flutter-sdk/` — Vendure GraphQL client for Flutter

These templates exist because issue #397 asks for `.gym/` in each of
the four packages, but this PR can only target the zuraffa repo. The
resolution: ship the three non-zuraffa packages' `.gym/` artifacts
here as **copy-paste-ready templates** the package maintainer lifts
into their own repo root.

## How to consume a template

1. `cd` into the sister package's repo root.
2. `cp -r /path/to/zuraffa/examples/gym-templates/<pkg>/.gym .`
3. Verify the `.gym/warmup/*.dart` files reference paths that exist
   in your repo (the templates use `<pkg>/example/` and
   `<pkg>/lib/` paths that are conventional; adjust if your repo
   layout differs).
4. Run `dart run .gym/warmup/01-deps.dart` to confirm the warmup
   chain works.
5. Commit the `.gym/` directory to your repo.

## Template structure

Each template has the same shape:

```text
<pkg>/.gym/
├── gym.yaml                       # miki-consumable manifest
├── warmup/
│   ├── 01-deps.dart               # dart pub get
│   ├── 02-build.dart              # dart analyze (or flutter analyze)
│   └── 03-smoke.dart              # one authenticated smoke call
└── exercise-<task>.dart           # one graded exercise (genuine dev task)
```

The `gym.yaml` mirrors the format zuraffa itself uses (see
`/.gym/gym.yaml`) — same keys, same shape, so the miki GYM runner
consumes every package's manifest without code changes.

## DROP CARDs

Mis-fires during exercise execution produce a DROP CARD with the
four required fields (Did / Expected / Happened / Where) — see
zuraffa's `.gym/lib/drop_card.dart` for the canonical helper. The
templates inline a small DROP CARD emitter so each template is
self-contained (no cross-repo dependency on zuraffa's helper).

## Miki version compatibility

The `gym.yaml` format is stable across miki versions; if a future
miki release introduces a breaking format change, the templates
will be updated in lockstep. The current format requires:

- top-level `name`, `version`, `warmup`, `exercises`
- each warmup entry: `id`, `name`, `command`
- each exercise entry: `id`, `brief`, `setup`, `verifyCommand`, `evaluate`

If miki fails to parse a template's `gym.yaml`, check these keys are
present and well-formed.
