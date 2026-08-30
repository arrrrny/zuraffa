/// Tests for DataSourceBuilder (042 working slice).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U20: mock datasource: in-memory seeded store + CRUD ops
///   042-U21: mock datasource imports dart:* only (zero external services)
///   042-U22: firebase datasource requires credentials (StateError)
///   042-U23: firebase REST URLs built from projectId + collection
///   042-U24: Firestore value mapping for entity fields
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/slice/datasource_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  const userFields = [
    EntityField(name: 'id', type: 'String'),
    EntityField(name: 'displayName', type: 'String'),
    EntityField(name: 'email', type: 'String', nullable: true),
    EntityField(name: 'age', type: 'int'),
    EntityField(name: 'rating', type: 'double'),
    EntityField(name: 'isActive', type: 'bool'),
    EntityField(name: 'tags', type: 'List<String>'),
    EntityField(name: 'meta', type: 'Map<String, dynamic>'),
    EntityField(name: 'createdAt', type: 'DateTime'),
  ];

  group('DataSourceBuilder mock (042)', () {
    final builder = DataSourceBuilder();

    test('042-U20: mock datasource is an in-memory seeded store with CRUD', () {
      final source = builder.buildMock('User', userFields);
      expect(
        source,
        contains('class UserMockDataSource implements UserDataSource'),
      );
      expect(source, contains('final Map<String, User> _store'));
      expect(source, contains('Future<User?> getUserById(String id)'));
      expect(source, contains('_store[id]'));
      expect(source, contains('Future<List<User>> getAllUsers()'));
      expect(source, contains('_store.values.toList('));
      expect(source, contains('Future<void> saveUser(User instance)'));
      expect(source, contains('Future<void> deleteUser(String id)'));
      // Seeded with a sample instance built from the field defaults.
      expect(source, contains('User('));
    });

    test('042-U21: mock datasource imports dart:* + bone-relative only — zero '
        'external services', () {
      final source = builder.buildMock('User', userFields);
      final imports = RegExp(
        r"^import\s+'([^']+)';",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!);
      for (final import in imports) {
        expect(
          import.startsWith('dart:') ||
              import.startsWith('../') ||
              !import.contains(':'),
          isTrue,
          reason:
              'mock datasource must stay self-contained, '
              'found "$import"',
        );
      }
    });

    test('mock datasource with no fields still works (auto keys)', () {
      final source = builder.buildMock('Widget', const []);
      expect(source, contains('class WidgetMockDataSource'));
      expect(source, contains('_store'));
    });
  });

  group('DataSourceBuilder firebase (042)', () {
    final builder = DataSourceBuilder();

    test('042-U22: firebase datasource constructor guards credentials with '
        'StateError', () {
      final source = builder.buildFirebase('User', userFields);
      expect(
        source,
        contains('class UserFirebaseDataSource implements UserDataSource'),
      );
      expect(source, contains('StateError'));
      expect(source, contains('projectId'));
      expect(source, contains('apiKey'));
    });

    test('042-U23: Firestore REST URLs built from projectId + collection', () {
      final source = builder.buildFirebase('User', userFields);
      expect(source, contains('firestore.googleapis.com'));
      expect(source, contains("'/user'"));
      expect(source, contains(r'$projectId'));
      expect(source, contains('databases/(default)'));
    });

    test('042-U24: Firestore value mapping for entity fields', () {
      final source = builder.buildFirebase('User', userFields);
      // toJson-side: fields wrapped in Firestore typed values.
      expect(source, contains('stringValue'));
      expect(source, contains('integerValue'));
      expect(source, contains('doubleValue'));
      expect(source, contains('booleanValue'));
      expect(source, contains('timestampValue'));
      expect(source, contains('arrayValue'));
      expect(source, contains('mapValue'));
      // fromJson-side: unwraps Firestore documents back into entity JSON.
      expect(source, contains('fields'));
    });

    test('firebase datasource uses dart:io HttpClient only', () {
      final source = builder.buildFirebase('User', userFields);
      expect(source, contains("import 'dart:io'"));
      expect(source, contains('HttpClient'));
      final imports = RegExp(
        r"^import\s+'([^']+)';",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!);
      for (final import in imports) {
        expect(
          import.startsWith('dart:') ||
              import.startsWith('../') ||
              !import.contains(':'),
          isTrue,
          reason:
              'firebase datasource must stay self-contained '
              '(dart:* or bone-relative only), found "$import"',
        );
      }
    });
  });
}
