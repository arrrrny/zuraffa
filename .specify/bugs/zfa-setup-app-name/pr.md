# Bug Fix PR: derive app shell file and widget class from the project name

- **Slug**: zfa-setup-app-name
- **Opened**: 2026-09-10
- **PR**: 1473
- **URL**: https://github.com/arrrrny/zuraffa/pull/1473
- **Branch**: fix/zfa-setup-app-name
- **Issue**: 1465

`zfa setup <name>` / `zfa app shell` now emit `<name>.dart` with the
PascalCase `+App` widget class (legacy `my_app` collapses to
`my_app.dart`/`MyApp`), legacy shells are never deleted, and a real
`zfa setup zik_zak` + `flutter analyze` reproduction is clean.
