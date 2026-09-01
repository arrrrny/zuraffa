# Bug Issue: [BUG] zfa setup references assets/zuraffa_app_icons/ but doesn't create it

- **Slug**: zfa-setup-missing-assets-icons-dir
- **Fetched**: 2026-09-02
- **Issue**: 735
- **URL**: https://github.com/arrrrny/zuraffa/issues/735
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Bug Description

`zfa setup` adds `assets/zuraffa_app_icons/` to `pubspec.yaml` under the `assets:` section, but does NOT create the directory. This causes all test runs to fail with:

```
Error: unable to find directory entry in pubspec.yaml: /Users/ahmettok/zik_zak_tdd/assets/zuraffa_app_icons/
```

This breaks the entire TDD cycle because every test run hits this error.

## Confirmation (v6.1.0, fresh project)

Tested on a fresh project created with `zfa setup --platforms=ios,android,macos` at zfa v6.1.0.

**Result:** BUG CONFIRMED.

```yaml
# pubspec.yaml
flutter:
  uses-material-design: true
  assets:
    - assets/zuraffa_app_icons/  # ← directory does not exist
```

```
$ ls /Users/ahmettok/zik_zak_tdd/assets/zuraffa_app_icons/
ls: /Users/ahmettok/zik_zak_tdd/assets/zuraffa_app_icons/: No such file or directory
```

Every test run fails:
```
$ flutter test test/tdd/a5_test.dart
Error: unable to find directory entry in pubspec.yaml: /Users/ahmettok/zik_zak_tdd/assets/zuraffa_app_icons/
```

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd`
3. `flutter test`
   → **fails**: `Error: unable to find directory entry in pubspec.yaml: .../assets/zuraffa_app_icons/`

## Workaround

```bash
mkdir -p assets/zuraffa_app_icons
```

## Environment

- zfa version: v6.1.0
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.