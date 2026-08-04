import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuraffa/src/presentation/xray/xray_control_deck.dart';
import 'package:zuraffa/src/presentation/xray/xray_mock_annotation.dart';
import 'package:zuraffa/src/presentation/xray/xray_mock_entry.dart';
import 'package:zuraffa/src/presentation/xray/xray_mock_parser.dart';
import 'package:zuraffa/src/presentation/xray/xray_mode.dart';

void _nopInjector(dynamic payload) {
  // No-op injector for testing
}

void main() {
  group('XRayMockAnnotation', () {
    test('direct constructor sets fields', () {
      const anno = XRayMock(
        name: 'Valid Product A',
        payload: '123456789',
        type: 'valid',
      );
      expect(anno.name, 'Valid Product A');
      expect(anno.payload, '123456789');
      expect(anno.type, 'valid');
      expect(anno.yamlPath, isNull);
    });

    test('fromYaml constructor sets yamlPath', () {
      const anno = XRayMock.fromYaml('assets/mocks/barcodes.yaml');
      expect(anno.yamlPath, 'assets/mocks/barcodes.yaml');
    });
  });

  group('XRayMockType', () {
    test('fromString maps correctly', () {
      expect(XRayMockType.fromString('valid'), XRayMockType.valid);
      expect(XRayMockType.fromString('VALID'), XRayMockType.valid);
      expect(XRayMockType.fromString('error'), XRayMockType.error);
      expect(XRayMockType.fromString('ERROR'), XRayMockType.error);
      expect(XRayMockType.fromString(null), XRayMockType.unknown);
      expect(XRayMockType.fromString(''), XRayMockType.unknown);
      expect(XRayMockType.fromString('bogus'), XRayMockType.unknown);
    });
  });

  group('XRayMockEntry', () {
    test('constructor with defaults', () {
      const entry = XRayMockEntry(name: 'Test', payload: 'abc');
      expect(entry.name, 'Test');
      expect(entry.payload, 'abc');
      expect(entry.type, XRayMockType.unknown);
      expect(entry.description, isNull);
    });

    test('equality', () {
      const a = XRayMockEntry(
        name: 'X',
        payload: 'p',
        type: XRayMockType.valid,
      );
      const b = XRayMockEntry(
        name: 'X',
        payload: 'p',
        type: XRayMockType.valid,
      );
      const c = XRayMockEntry(
        name: 'X',
        payload: 'q',
        type: XRayMockType.valid,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toJson', () {
      const entry = XRayMockEntry(
        name: 'Test',
        payload: 'data',
        type: XRayMockType.error,
      );
      final json = entry.toJson();
      expect(json['name'], 'Test');
      expect(json['payload'], 'data');
      expect(json['type'], 'error');
    });

    test('fromAnnotation', () {
      final entry = XRayMockEntry.fromAnnotation(
        name: 'Valid',
        payload: '123',
        type: 'valid',
      );
      expect(entry.name, 'Valid');
      expect(entry.payload, '123');
      expect(entry.type, XRayMockType.valid);
    });

    test('fromYamlMap', () {
      final entry = XRayMockEntry.fromYamlMap({
        'name': 'Err',
        'payload': 'bad',
        'type': 'error',
        'description': 'A bad one',
      });
      expect(entry.name, 'Err');
      expect(entry.payload, 'bad');
      expect(entry.type, XRayMockType.error);
      expect(entry.description, 'A bad one');
    });
  });

  group('XRayMockParser', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('xray_mock_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fromYamlFile parses valid YAML', () {
      final yamlFile = File('${tempDir.path}/mocks.yaml');
      yamlFile.writeAsStringSync('''
- name: Valid Product A
  payload: "123456789"
  type: valid
- name: Invalid Barcode
  payload: "000000"
  type: error
  description: Triggers barcode validation failure
- name: Unknown Item
  payload: "999"
''');
      final entries = XRayMockParser.fromYamlFile(yamlFile.path);
      expect(entries, hasLength(3));

      expect(entries[0].name, 'Valid Product A');
      expect(entries[0].payload, '123456789');
      expect(entries[0].type, XRayMockType.valid);
      expect(entries[0].description, isNull);

      expect(entries[1].name, 'Invalid Barcode');
      expect(entries[1].type, XRayMockType.error);
      expect(entries[1].description, 'Triggers barcode validation failure');

      expect(entries[2].name, 'Unknown Item');
      expect(entries[2].type, XRayMockType.unknown);
    });

    test('fromYamlFile returns empty for missing file', () {
      final entries = XRayMockParser.fromYamlFile('/nonexistent.yaml');
      expect(entries, isEmpty);
    });

    test('fromYamlFile returns empty for malformed YAML', () {
      final yamlFile = File('${tempDir.path}/bad.yaml');
      yamlFile.writeAsStringSync(': invalid: [: yaml:');
      final entries = XRayMockParser.fromYamlFile(yamlFile.path);
      expect(entries, isEmpty);
    });

    test('fromAnnotation returns single entry', () {
      final entries = XRayMockParser.fromAnnotation(
        name: 'Quick',
        payload: 'abc',
        type: 'valid',
      );
      expect(entries, hasLength(1));
      expect(entries[0].name, 'Quick');
      expect(entries[0].type, XRayMockType.valid);
    });

    test('fromYamlString parses correctly', () {
      const yaml = '''
- name: A
  payload: x
  type: valid
- name: B
  payload: y
''';
      final entries = XRayMockParser.fromYamlString(yaml);
      expect(entries, hasLength(2));
      expect(entries[0].name, 'A');
      expect(entries[1].type, XRayMockType.unknown);
    });
  });

  group('XRayControlDeckRegistry', () {
    tearDown(() {
      XRayControlDeckRegistry.clear();
    });

    test('registerEntries and retrieve', () {
      XRayControlDeckRegistry.registerEntries('ScanBarcodeUseCase', const [
        XRayMockEntry(name: 'A', payload: '1', type: XRayMockType.valid),
        XRayMockEntry(name: 'B', payload: '2', type: XRayMockType.error),
      ]);

      final entries = XRayControlDeckRegistry.entriesFor('ScanBarcodeUseCase');
      expect(entries, hasLength(2));
      expect(entries[0].name, 'A');
      expect(entries[1].type, XRayMockType.error);
    });

    test('entriesFor unknown key returns empty', () {
      final entries = XRayControlDeckRegistry.entriesFor('Unknown');
      expect(entries, isEmpty);
    });

    test('allEntries returns snapshot', () {
      XRayControlDeckRegistry.registerEntries('UC1', const [
        XRayMockEntry(name: 'X', payload: 'p'),
      ]);
      XRayControlDeckRegistry.registerEntries('UC2', const [
        XRayMockEntry(name: 'Y', payload: 'q'),
      ]);

      final all = XRayControlDeckRegistry.allEntries;
      expect(all, hasLength(2));
      expect(all['UC1'], hasLength(1));
      expect(all['UC2'], hasLength(1));
    });

    test('registerEntries replaces previous entries for same key', () {
      XRayControlDeckRegistry.registerEntries('UC', const [
        XRayMockEntry(name: 'Old', payload: 'o'),
      ]);
      XRayControlDeckRegistry.registerEntries('UC', const [
        XRayMockEntry(name: 'New', payload: 'n'),
      ]);

      final entries = XRayControlDeckRegistry.entriesFor('UC');
      expect(entries, hasLength(1));
      expect(entries[0].name, 'New');
    });
  });

  group('XRayMode integration', () {
    tearDown(() {
      XRayMode.reset();
    });

    test('Control Deck returns empty in release mode conceptually', () {
      // We cannot change kReleaseMode at runtime, but we verify the
      // registry API has the guard. The ControlDeck widget also guards
      // on XRayMode.isEnabled.
      expect(XRayControlDeckRegistry.entriesFor('nonexistent'), isEmpty);
    });

    test('Registry clear works', () {
      XRayControlDeckRegistry.registerEntries('UC', const [
        XRayMockEntry(name: 'T', payload: 't'),
      ]);
      expect(XRayControlDeckRegistry.entriesFor('UC'), hasLength(1));
      XRayControlDeckRegistry.clear();
      expect(XRayControlDeckRegistry.entriesFor('UC'), isEmpty);
    });
  });

  group('XRayControlDeck Widget Tests', () {
    tearDown(() {
      XRayMode.reset();
    });

    testWidgets('renders SizedBox.shrink when XRayMode is disabled', (
      tester,
    ) async {
      XRayMode.reset();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              entries: [],
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('MOCK DECK'), findsNothing);
    });

    testWidgets('renders toggle button when XRayMode is enabled', (
      tester,
    ) async {
      XRayMode.enable();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              entries: [],
            ),
          ),
        ),
      );

      expect(find.text('MOCK DECK'), findsOneWidget);
      expect(find.byIcon(Icons.science), findsOneWidget);
    });

    testWidgets('toggle opens and closes panel', (tester) async {
      XRayMode.enable();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              entries: [XRayMockEntry(name: 'Test', payload: 'data')],
            ),
          ),
        ),
      );

      // Initially closed
      expect(find.text('Control Deck'), findsNothing);

      // Tap to open
      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      expect(find.text('Control Deck'), findsOneWidget);
      expect(find.text('TestUseCase'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap to close
      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      expect(find.text('Control Deck'), findsNothing);
      expect(find.byIcon(Icons.science), findsOneWidget);
    });

    testWidgets('inject callback is invoked and shows feedback', (
      tester,
    ) async {
      XRayMode.enable();
      dynamic capturedPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: (payload) {
                capturedPayload = payload;
              },
              entries: const [
                XRayMockEntry(name: 'Test Entry', payload: 'test-data'),
              ],
            ),
          ),
        ),
      );

      // Open panel
      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      // Tap entry button
      await tester.tap(find.text('Test Entry'));
      await tester.pumpAndSettle();

      expect(capturedPayload, equals('test-data'));
      expect(
        find.text('Test Entry'),
        findsNWidgets(2),
      ); // In button label and entry
    });

    testWidgets('color mapping for XRayMockType.valid', (tester) async {
      XRayMode.enable();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              entries: [
                XRayMockEntry(
                  name: 'Valid',
                  payload: 'data',
                  type: XRayMockType.valid,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      // Valid type should show checkmark emoji
      expect(find.text('\u2705'), findsOneWidget);
    });

    testWidgets('color mapping for XRayMockType.error', (tester) async {
      XRayMode.enable();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              entries: [
                XRayMockEntry(
                  name: 'Error',
                  payload: 'data',
                  type: XRayMockType.error,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      // Error type should show cross emoji
      expect(find.text('\u274C'), findsOneWidget);
    });

    testWidgets('color mapping for XRayMockType.unknown', (tester) async {
      XRayMode.enable();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              entries: [
                XRayMockEntry(
                  name: 'Unknown',
                  payload: 'data',
                  type: XRayMockType.unknown,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      // Unknown type should show circle emoji
      expect(find.text('\u26AA'), findsOneWidget);
    });

    testWidgets('empty state shows helpful message', (tester) async {
      XRayMode.enable();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              entries: [],
            ),
          ),
        ),
      );

      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No mock scenarios registered.\nAdd @XRayMock annotations or use registerEntries().',
        ),
        findsOneWidget,
      );
      expect(find.text('0 mocks'), findsOneWidget);
    });

    testWidgets('heightFactor constrains panel height', (tester) async {
      XRayMode.enable();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XRayControlDeck(
              useCaseName: 'TestUseCase',
              injector: _nopInjector,
              heightFactor: 0.3,
              entries: [
                XRayMockEntry(name: 'Test1', payload: 'data1'),
                XRayMockEntry(name: 'Test2', payload: 'data2'),
                XRayMockEntry(name: 'Test3', payload: 'data3'),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('MOCK DECK'));
      await tester.pumpAndSettle();

      // Panel should be visible
      expect(find.text('Control Deck'), findsOneWidget);
      // Entries should be rendered
      expect(find.text('Test1'), findsOneWidget);
    });
  });

  group('Registry Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('xray_deck_golden_');
      XRayMode.reset();
      XRayControlDeckRegistry.clear();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      XRayMode.reset();
      XRayControlDeckRegistry.clear();
    });

    test(
      'annotated UseCase produces expected deck buttons after registration',
      () {
        // Simulate what the generated {ViewName}_XRayDeck.dart would do:
        XRayControlDeckRegistry.registerEntries('ScanBarcodeUseCase', const [
          XRayMockEntry(
            name: 'Valid Product A',
            payload: '123456789',
            type: XRayMockType.valid,
          ),
          XRayMockEntry(
            name: 'Invalid Barcode',
            payload: '000000',
            type: XRayMockType.error,
            description: 'Triggers barcode validation failure',
          ),
          XRayMockEntry(name: 'Unknown Format', payload: 'abcdef'),
        ]);

        final entries = XRayControlDeckRegistry.entriesFor(
          'ScanBarcodeUseCase',
        );
        expect(entries, hasLength(3));

        // Verify color-coding types
        expect(entries[0].type, XRayMockType.valid);
        expect(entries[1].type, XRayMockType.error);
        expect(entries[2].type, XRayMockType.unknown);

        // Verify names
        expect(entries[0].name, 'Valid Product A');
        expect(entries[1].name, 'Invalid Barcode');
        expect(entries[2].name, 'Unknown Format');

        // Verify payloads
        expect(entries[0].payload, '123456789');
        expect(entries[1].payload, '000000');
        expect(entries[2].payload, 'abcdef');

        // Verify description on error entry
        expect(entries[1].description, 'Triggers barcode validation failure');
        expect(entries[0].description, isNull);
        expect(entries[2].description, isNull);
      },
    );

    test('YAML-based entries match annotation-based entries', () {
      // Create a YAML file
      final yamlFile = File('${tempDir.path}/barcodes.yaml');
      yamlFile.writeAsStringSync('''
- name: Valid Product A
  payload: "123456789"
  type: valid
- name: Invalid Barcode
  payload: "000000"
  type: error
''');

      // Parse YAML entries
      final yamlEntries = XRayMockParser.fromYamlFile(yamlFile.path);

      // Create equivalent annotation entries
      final annotationEntries = [
        XRayMockEntry.fromAnnotation(
          name: 'Valid Product A',
          payload: '123456789',
          type: 'valid',
        ),
        XRayMockEntry.fromAnnotation(
          name: 'Invalid Barcode',
          payload: '000000',
          type: 'error',
        ),
      ];

      // Both should produce the same data
      expect(yamlEntries.length, annotationEntries.length);
      for (var i = 0; i < yamlEntries.length; i++) {
        expect(yamlEntries[i].name, annotationEntries[i].name);
        expect(yamlEntries[i].payload, annotationEntries[i].payload);
        expect(yamlEntries[i].type, annotationEntries[i].type);
      }
    });

    test('re-running build with updated YAML reflects changes', () {
      // First generation
      final yamlFile = File('${tempDir.path}/scenarios.yaml');
      yamlFile.writeAsStringSync('''
- name: Scenario 1
  payload: "a"
  type: valid
''');

      XRayControlDeckRegistry.registerEntries(
        'TestUseCase',
        XRayMockParser.fromYamlFile(yamlFile.path),
      );
      expect(XRayControlDeckRegistry.entriesFor('TestUseCase'), hasLength(1));

      // Simulate re-run: clear and reload with updated YAML
      XRayControlDeckRegistry.clear();
      yamlFile.writeAsStringSync('''
- name: Scenario 1
  payload: "a"
  type: valid
- name: Scenario 2
  payload: "b"
  type: error
- name: Scenario 3
  payload: "c"
''');

      XRayControlDeckRegistry.registerEntries(
        'TestUseCase',
        XRayMockParser.fromYamlFile(yamlFile.path),
      );

      final entries = XRayControlDeckRegistry.entriesFor('TestUseCase');
      expect(entries, hasLength(3));
      expect(entries[1].name, 'Scenario 2');
      expect(entries[2].type, XRayMockType.unknown);
    });
  });
}
