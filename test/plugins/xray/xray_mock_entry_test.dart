// Spec 034 — Track 4.3: XRayMockEntry data class tests.
//
// Behaviors B03, B04, B05: dedup equality, JSON round-trip, empty payload.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_entry.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_type.dart';

void main() {
  group('XRayMockEntry', () {
    test('constructor defaults type to unknown', () {
      const e = XRayMockEntry(name: 'A', payload: 'p1');
      expect(e.name, 'A');
      expect(e.payload, 'p1');
      expect(e.type, XRayMockType.unknown);
    });

    test('constructor accepts explicit type', () {
      const e = XRayMockEntry(
        name: 'A',
        payload: 'p1',
        type: XRayMockType.valid,
      );
      expect(e.type, XRayMockType.valid);
    });

    test('B03 — two entries with same name+payload are equal', () {
      const a = XRayMockEntry(name: 'A', payload: 'p1');
      const b = XRayMockEntry(name: 'A', payload: 'p1');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('B03 — two entries with same name but different payloads are NOT equal',
        () {
      const a = XRayMockEntry(name: 'A', payload: 'p1');
      const b = XRayMockEntry(name: 'A', payload: 'p2');
      expect(a, isNot(equals(b)));
    });

    test('B03 — two entries with different names but same payload are NOT equal',
        () {
      const a = XRayMockEntry(name: 'A', payload: 'p1');
      const b = XRayMockEntry(name: 'B', payload: 'p1');
      expect(a, isNot(equals(b)));
    });

    test('B03 — type field does NOT affect equality (only name+payload)', () {
      const a = XRayMockEntry(
        name: 'A',
        payload: 'p1',
        type: XRayMockType.valid,
      );
      const b = XRayMockEntry(
        name: 'A',
        payload: 'p1',
        type: XRayMockType.error,
      );
      expect(a, equals(b),
          reason: 'Equality is by name+payload only, per the spec edge case');
    });

    test('B04 — toJson produces canonical shape', () {
      const e = XRayMockEntry(
        name: 'A',
        payload: 'p1',
        type: XRayMockType.valid,
      );
      final j = e.toJson();
      expect(j['name'], 'A');
      expect(j['payload'], 'p1');
      expect(j['type'], 'valid');
    });

    test('B04 — toJson emits unknown for default type', () {
      const e = XRayMockEntry(name: 'A', payload: 'p1');
      expect(e.toJson()['type'], 'unknown');
    });

    test('B04 — fromJson round-trips', () {
      const original = XRayMockEntry(
        name: 'A',
        payload: 'p1',
        type: XRayMockType.error,
      );
      final j = original.toJson();
      final reconstructed = XRayMockEntry.fromJson(j);
      expect(reconstructed.name, original.name);
      expect(reconstructed.payload, original.payload);
      expect(reconstructed.type, original.type);
    });

    test('B04 — fromJson accepts missing type (defaults to unknown)', () {
      final e = XRayMockEntry.fromJson({
        'name': 'A',
        'payload': 'p1',
      });
      expect(e.type, XRayMockType.unknown);
    });

    test('B04 — toJson is json-serializable', () {
      const e = XRayMockEntry(name: 'A', payload: 'p1');
      expect(jsonEncode(e.toJson()), isA<String>());
    });

    test('B05 — empty payload is accepted', () {
      const e = XRayMockEntry(name: 'empty-payload', payload: '');
      expect(e.payload, '');
      expect(e.toJson()['payload'], '');
    });

    test('toString includes name and payload', () {
      const e = XRayMockEntry(name: 'A', payload: 'p1');
      expect(e.toString(), contains('A'));
      expect(e.toString(), contains('p1'));
    });
  });
}
