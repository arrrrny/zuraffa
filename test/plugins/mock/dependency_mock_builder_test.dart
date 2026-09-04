import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

void main() {
  // Production shape (ZikZak login engine slice): an internal service
  // whose declared signatures reference project entity types.
  DependencyContract contract() => DependencyContract.parseRow(
    name: 'AuthService',
    type: 'service',
    contract: 'login(AuthRequest params) -> User',
    priority: 'P1',
    specLine: 109,
  );

  group('issue #1030 — declared artifacts import the types they reference', () {
    test('interface emits contract-derived entity imports', () {
      final artifacts = DependencyMockBuilder.emit(
        contract: contract(),
        outDir: 'test/mock/dependencies/auth_service',
      );

      final interface = artifacts
          .firstWhere((a) => a.path.endsWith('/auth_service.dart'))
          .content;
      expect(
        interface.contains(
          "import '../../../../lib/src/domain/entities/auth_request/auth_request.dart';",
        ),
        isTrue,
        reason:
            'AuthRequest is referenced by the declared login signature — '
            'the artifact must import it (4 segments deep from the '
            'artifact dir to the project root)',
      );
      expect(
        interface.contains(
          "import '../../../../lib/src/domain/entities/user/user.dart';",
        ),
        isTrue,
        reason: 'User is the declared return type',
      );
    });

    test('fake and fixtures carry the same import block', () {
      final artifacts = DependencyMockBuilder.emit(
        contract: contract(),
        outDir: 'test/mock/dependencies/auth_service',
      );

      for (final artifact in artifacts) {
        expect(
          artifact.content.contains('entities/user/user.dart'),
          isTrue,
          reason: '${artifact.path} references User and must import it',
        );
      }
    });

    test('primitive-only signatures emit no entity imports', () {
      final contract = DependencyContract.parseRow(
        name: 'Clock',
        type: 'service',
        contract: 'now() -> DateTime, tick(String label) -> void',
        priority: 'P2',
      );
      final artifacts = DependencyMockBuilder.emit(
        contract: contract,
        outDir: 'test/mock/dependencies/clock',
      );

      for (final artifact in artifacts) {
        expect(
          artifact.content.contains('lib/src/domain/entities/'),
          isFalse,
          reason:
              'DateTime/String/void are primitives — no entity import '
              'for ${artifact.path}',
        );
      }
    });

    test('same contract emits byte-identical artifacts (determinism)', () {
      final first = DependencyMockBuilder.emit(
        contract: contract(),
        outDir: 'test/mock/dependencies/auth_service',
      );
      final second = DependencyMockBuilder.emit(
        contract: contract(),
        outDir: 'test/mock/dependencies/auth_service',
      );

      for (var i = 0; i < first.length; i++) {
        expect(second[i].content, first[i].content);
      }
    });

    test('absolute outDir anchors depth on the test segment, not the path '
        'length', () {
      final relative = DependencyMockBuilder.emit(
        contract: contract(),
        outDir: 'test/mock/dependencies/auth_service',
      );
      final absolute = DependencyMockBuilder.emit(
        contract: contract(),
        outDir: '/Users/dev/proj/test/mock/dependencies/auth_service',
      );

      // Both resolve to the same 4-hop prefix from the artifact dir to
      // the project root — the depth must not count absolute-only
      // leading segments (issue #1030 follow-up).
      for (var i = 0; i < relative.length; i++) {
        expect(
          absolute[i].content.contains("'../../../../lib/src/"),
          isTrue,
          reason: '${absolute[i].path} anchors 4 hops to lib/',
        );
        expect(
          absolute[i].content.contains("'../../../../../lib/src/"),
          isFalse,
          reason: 'no over-deep hop chains',
        );
      }
    });
  });
}
