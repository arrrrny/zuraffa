/// Tests for PresentationBuilder (042 working slice, --flutter mode).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U30: page renders primary entity fields + uses a use case via DI
///   042-U31: widget test imports flutter_test and pumps the page
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/slice/presentation_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  const userFields = [
    EntityField(name: 'id', type: 'String'),
    EntityField(name: 'displayName', type: 'String'),
    EntityField(name: 'email', type: 'String', nullable: true),
  ];

  group('PresentationBuilder (042)', () {
    final builder = PresentationBuilder();

    test('042-U30: page is a real UI over the primary entity invoking a use '
        'case via the DI container', () {
      final source = builder.buildPage(
        featureSlug: 'profile-feature',
        primaryEntity: 'User',
        fields: userFields,
      );
      expect(source, contains("import 'package:flutter/material.dart'"));
      expect(source, contains('class ProfileFeaturePage'));
      expect(source, contains('Scaffold'));
      expect(source, contains('AppBar'));
      expect(source, contains('ProfileFeatureServices'));
      // Loads instances through a use case/repository from the DI container.
      expect(source, contains('updateUser')); // UpdateUserUseCase accessor
      expect(source, contains('FutureBuilder'));
      // Renders primary-entity field values.
      expect(source, contains('instance.displayName'));
      expect(source, contains('instance.id'));
    });

    test('042-U31: widget test imports flutter_test and pumps the page', () {
      final source = builder.buildPageTest(
        featureSlug: 'profile-feature',
        primaryEntity: 'User',
      );
      expect(source, contains("import 'package:flutter/material.dart'"));
      expect(
        source,
        contains("import 'package:flutter_test/flutter_test.dart'"),
      );
      expect(source, contains('testWidgets('));
      expect(source, contains('pumpWidget('));
      expect(source, contains('ProfileFeaturePage'));
      expect(source, contains('ProfileFeatureServices.create(backend: BoneBackend.mock)'));
    });
  });
}
