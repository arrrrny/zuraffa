/// Shared fixture for spec 1114 (typed, worktree-scoped, contract-checked
/// slice): a minimal probe project declaring a `login` feature contract
/// with engine + skin trees, plus an `other` entity that the contract
/// does NOT own — the negative case every scoping assertion needs.
///
/// Layout conventions exercised (the composer's documented discovery
/// rules, spec 1114):
///   lib/src/domain/entities/<snake(entity)>/**
///   lib/src/domain/usecases/**            (filename mentions the entity)
///   lib/src/domain/repositories/**        (filename mentions the entity)
///   lib/src/domain/services/**            (filename mentions the entity)
///   lib/src/data/datasources/**           (filename mentions the entity)
///   lib/src/data/mocks/mock_<entity>*.dart
///   lib/src/di/**                         (content mentions the entity)
///   lib/src/presentation/views/<route>_view.dart
///   lib/src/presentation/widgets/**       (filename mentions a route token)
///   lib/src/presentation/states/**        (filename mentions a route token)
///   specs/<id>/contract.yaml + spec.md + tdd/test-list.md
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The `login` contract body (specs/login/contract.yaml) — presentation
/// layer, two entities, two routes, a resolvable boundary.
const String loginContractYaml = '''
id: login
display_name: Login
xray_layer: presentation
entities:
  - User
  - Session
routes:
  - /login
  - /login/forgot
boundary:
  type_name: LoginRepository
  interface_file: lib/src/domain/repositories/user_repository.dart
  mock_strategy: auto
''';

/// Writes one file under [root], creating parents.
void writeFile(String root, String relPath, String content) {
  final file = File(p.join(root, relPath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// The login spec markdown (receipts fixture).
const String loginSpecMd = '''
# Login

The login feature: user authentication with a forgot-password flow.

## Key Entities

- `User`: id:String, email:String
- `Session`: token:String

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1, U2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
```
''';

/// Builds the full login probe project under [root]. Returns the root.
String buildLoginProbe(String root) {
  writeFile(
    root,
    'pubspec.yaml',
    'name: probe\nenvironment:\n  sdk: ^3.11.0\n',
  );

  // — engine: owned by the contract —
  writeFile(
    root,
    'lib/src/domain/entities/user/user.dart',
    'class User {\n  final String id;\n  final String email;\n}\n',
  );
  writeFile(
    root,
    'lib/src/domain/entities/session/session.dart',
    'class Session {\n  final String token;\n}\n',
  );
  writeFile(
    root,
    'lib/src/domain/repositories/user_repository.dart',
    'abstract class LoginRepository {\n  Future<bool> login(String email);\n}\n',
  );
  writeFile(
    root,
    'lib/src/domain/usecases/login_user.dart',
    'class LoginUserUseCase {\n  final dynamic repo;\n}\n',
  );
  writeFile(
    root,
    'lib/src/domain/services/user_service.dart',
    'class UserService {}\n',
  );
  writeFile(
    root,
    'lib/src/data/datasources/user_remote_datasource.dart',
    'class UserRemoteDataSource {}\n',
  );
  writeFile(
    root,
    'lib/src/data/mocks/mock_user_datasource.dart',
    '// GENERATED — certified mock for User (probe).\nclass MockUserDataSource {}\n',
  );
  writeFile(
    root,
    'lib/src/di/user_di.dart',
    '// DI wiring for User / LoginRepository (probe).\nvoid registerUser() {}\n',
  );

  // — engine: NOT owned by the contract (must be excluded) —
  writeFile(
    root,
    'lib/src/domain/entities/other/other.dart',
    'class Other {}\n',
  );
  writeFile(
    root,
    'lib/src/domain/usecases/other_usecase.dart',
    'class OtherUseCase {}\n',
  );

  // — skin: owned by the contract routes —
  writeFile(
    root,
    'lib/src/presentation/views/login_view.dart',
    'class LoginView {}\n',
  );
  writeFile(
    root,
    'lib/src/presentation/views/login_forgot_view.dart',
    'class LoginForgotView {}\n',
  );
  writeFile(
    root,
    'lib/src/presentation/widgets/login_button.dart',
    'class LoginButton {}\n',
  );
  writeFile(
    root,
    'lib/src/presentation/states/login_state.dart',
    'class LoginState {}\n',
  );

  // — skin: NOT owned by the contract (must be excluded) —
  writeFile(
    root,
    'lib/src/presentation/views/other_view.dart',
    'class OtherView {}\n',
  );

  // — receipts: the declared contract + spec + tdd list —
  writeFile(root, p.join('specs', 'login', 'contract.yaml'), loginContractYaml);
  writeFile(root, p.join('specs', 'login', 'spec.md'), loginSpecMd);
  writeFile(
    root,
    p.join('specs', 'login', 'tdd', 'test-list.md'),
    '# Test list\n\n| Entity | Fields |\n| --- | --- |\n| User | id:String |\n',
  );

  return root;
}

/// Initializes [root] as a git repo with one commit (for worktree tests).
Future<void> gitInitWithCommit(String root) async {
  Future<ProcessResult> git(List<String> args) =>
      Process.run('git', args, workingDirectory: root);
  await git(['init', '-b', 'master']);
  await git(['config', 'user.email', 'probe@example.com']);
  await git(['config', 'user.name', 'Probe']);
  await git(['add', '-A']);
  await git(['commit', '-m', 'probe baseline']);
}
