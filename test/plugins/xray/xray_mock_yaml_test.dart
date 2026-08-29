// Spec 034 — Track 4.3: XRayMockYaml shared YAML parser tests.
//
// Behaviors B17..B20.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_yaml.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_type.dart';

void main() {
  group('XRayMockYaml.parse', () {
    test('B17 — single entry parses', () {
      final entries = XRayMockYaml.parse('''
- name: A
  payload: p1
''');
      expect(entries.length, 1);
      expect(entries.first.name, 'A');
      expect(entries.first.payload, 'p1');
    });

    test('B17 — two entries parse', () {
      final entries = XRayMockYaml.parse('''
- name: A
  payload: p1
- name: B
  payload: p2
''');
      expect(entries.length, 2);
      expect(entries[0].name, 'A');
      expect(entries[1].name, 'B');
    });

    test('B18 — type: valid populates XRayMockType.valid', () {
      final entries = XRayMockYaml.parse('''
- name: A
  payload: p1
  type: valid
''');
      expect(entries.first.type, XRayMockType.valid);
    });

    test('B18 — type: error populates XRayMockType.error', () {
      final entries = XRayMockYaml.parse('''
- name: A
  payload: p1
  type: error
''');
      expect(entries.first.type, XRayMockType.error);
    });

    test('B18 — no type field defaults to unknown', () {
      final entries = XRayMockYaml.parse('''
- name: A
  payload: p1
''');
      expect(entries.first.type, XRayMockType.unknown);
    });

    test('B18 — garbage type falls back to unknown', () {
      final entries = XRayMockYaml.parse('''
- name: A
  payload: p1
  type: banana
''');
      expect(entries.first.type, XRayMockType.unknown);
    });

    test('B19 — missing name throws with entry index', () {
      expect(
        () => XRayMockYaml.parse('''
- payload: p1
'''),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('0'),
          ),
        ),
      );
    });

    test('B19 — missing payload throws with entry index', () {
      expect(
        () => XRayMockYaml.parse('''
- name: A
'''),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('0'),
          ),
        ),
      );
    });

    test('B19 — error message mentions which field is missing', () {
      try {
        XRayMockYaml.parse('''
- name: A
- name: B
  payload: p2
''');
        fail('should have thrown');
      } on FormatException catch (e) {
        expect(e.message, contains('payload'));
        // Index of the failing entry (0 in this case).
        expect(e.message, contains('0'));
      }
    });

    test('B20 — empty string returns empty list (NOT an error)', () {
      expect(XRayMockYaml.parse(''), isEmpty);
    });

    test('B20 — whitespace-only string returns empty list', () {
      expect(XRayMockYaml.parse('   \n  \n'), isEmpty);
    });

    test('empty payload string is accepted', () {
      final entries = XRayMockYaml.parse('''
- name: empty
  payload: ""
''');
      expect(entries.length, 1);
      expect(entries.first.payload, '');
    });

    test('parseFile reads from disk', () async {
      final tmp = await Directory.systemTemp.createTemp('xray_yaml_');
      final path = p.join(tmp.path, 'mocks.yaml');
      File(path).writeAsStringSync('''
- name: A
  payload: p1
- name: B
  payload: p2
  type: valid
''');
      final entries = XRayMockYaml.parseFile(path);
      expect(entries.length, 2);
      expect(entries[1].type, XRayMockType.valid);
      await tmp.delete(recursive: true);
    });
  });
}
