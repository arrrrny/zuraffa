# Red Evidence — XRayMockYaml shared YAML parser

**Test file**: `test/plugins/xray/xray_mock_yaml_test.dart`
**Behaviors**: B17 (single/multi parse), B18 (type field), B19 (missing
required field throws with entry index), B20 (empty input → empty list)
**Spec**: FR-002 (`@XRayMock.fromYaml`)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_mock_yaml_test.dart

Failed to load "test/plugins/xray/xray_mock_yaml_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_mock_yaml.dart'.
  Error: Method not found: 'XRayMockYaml'.
```

**Status**: RED ✓

## Resolution

Implementation: `lib/src/plugins/xray/xray_mock_yaml.dart` —
`parse(String)` + `parseFile(String)` helpers using the existing
`package:yaml`. Throws `FormatException` with a message containing the
offending entry index and missing field name.

Subsequent run (green):
```
00:04 +51: All tests passed!  (cumulative across type + entry + deck + yaml)
```
