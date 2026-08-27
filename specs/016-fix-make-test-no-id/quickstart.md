# Quickstart: verify the #508 fix locally

**Feature**: 016-fix-make-test-no-id | **Date**: 2026-08-27

Five-minute smoke test from a fresh checkout of this branch. It uses a throwaway Dart package as a stand-in for `apps/zikzak_demo` (which lives outside this repo): an id-less entity with pre-existing get/update/toggle usecases.

## 0. Prerequisites

Dart 3.11+. From the zuraffa checkout root:

```bash
dart pub get
```

## 1. Build the fixture (≈2 min)

```bash
mkdir -p /tmp/zzd && cd /tmp/zzd
cat > pubspec.yaml <<'EOF'
name: zikzak_demo
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: /path/to/zuraffa
  zorphy: ^2.2.0
  zorphy_annotation: ^2.2.0
dev_dependencies:
  test: ^1.25.0
  mocktail: ^1.0.4
  build_runner: ^2.15.2
EOF
dart pub get
ZFA="dart run /path/to/zuraffa/bin/zfa.dart"

# entity with a TEMPORARY id → generate the architecture → strip the id
$ZFA entity create -n AuthRequest --field id:String --field email:String --field password:String --field method:String
$ZFA make AuthRequest repository datasource usecase test --methods=get,update,toggle --force
$ZFA entity create -n AuthRequest --field email:String --field password:String --field method:String
$ZFA build
```

## 2. See the fix

```bash
$ZFA make AuthRequest --test --force   # exits 0, rewrites the three test files
grep -n "AuthRequestFields\." test/domain/usecases/auth_request/*_test.dart
# → references .email (a real field), NOT .id
dart test test/                        # the regenerated tests pass
```

## 3. See the #307 guard still armed

```bash
$ZFA make AuthRequest --force          # id-dependent plugins active
# → ❌ Cannot generate architecture for "AuthRequest": the entity has no id field.
#   (plus the three remediation hints, exit 1)
```

## 4. Run the repo's own proof

```bash
cd /path/to/zuraffa
dart analyze
dart test test/commands/make_command_test.dart
dart test test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart
dart test
```
