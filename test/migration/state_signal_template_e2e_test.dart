// Issue #2076 — the emitted state file must COMPILE and BEHAVE with no manual
// edit (acceptance criteria 2, 1 and 3).
//
// `test/migration/state_signal_template_test.dart` pins the emitted TEXT. This
// suite runs the real template output inside a throwaway pure-Dart package
// that depends on this checkout by path, then executes it:
//
//   * `dart analyze lib` — the generated view/domain state needs no hand fix;
//   * a probe binary — N setters inside one `batch(...)` produce exactly ONE
//     notification carrying the final values, and disposing the owning
//     presenter releases the signals (`isDisposed`).
//
// e2e-tagged: it spawns `dart pub get`, `dart analyze` and `dart run`.
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/migration/fixers/state_fixer.dart';
import 'package:zuraffa/src/migration/migration_models.dart';

import '../helpers/project_root.dart';

/// The v5 file the migration consumes. `Cart` is a domain type, so it is
/// imported the way a real project imports it.
const _sourceStateFile = '''
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/cart/cart.dart';

class CartState {
  /// Failure of the last load.
  final AppFailure? error;
  final bool isLoading;
  final bool isRefreshing;
  final Cart? cart;

  const CartState({
    this.error,
    this.isLoading = false,
    this.isRefreshing = false,
    this.cart,
  });
}
''';

const _presenterFile = '''
import 'package:zuraffa/zuraffa.dart';

import 'cart_domain_state.dart';
import 'cart_view_state.dart';

/// Concrete [SlicePresenter] for the fixture (the base class is abstract).
class CartSlicePresenter extends SlicePresenter {}

class CartPresenter extends DualLayerPresenter {
  CartPresenter(CartViewState view)
    : super(
        domain: CartDomainState(presenter: CartSlicePresenter()),
        view: view,
      );
}
''';

const _probeFile = '''
import 'dart:io';

import 'package:zuraffa/zuraffa.dart';

import '../lib/presentation/pages/cart/cart_presenter.dart';
import '../lib/presentation/pages/cart/cart_view_state.dart';

int failures = 0;

void check(String name, bool ok, [String detail = '']) {
  if (ok) {
    print('PASS \$name');
  } else {
    failures++;
    print('FAIL \$name \$detail');
  }
}

void main() {
  final view = CartViewState();

  var notifications = 0;
  CartViewData? last;
  view.state.listen((value) {
    notifications++;
    last = value;
  });
  // Drop the eager delivery of the initial value.
  notifications = 0;
  last = null;

  batch(() {
    // Reads inside a batch see freshly written values, never a deferred one.
    check('read-inside-batch', view.isLoading == false);
    view.isLoading = true;
    view.isRefreshing = true;
  });

  check(
    'batch-notifies-once',
    notifications == 1,
    'notifications=\$notifications',
  );
  check('final-values-visible', view.isLoading && view.isRefreshing);
  check(
    'one-notification-carries-final-values',
    last != null && last!.isLoading && last!.isRefreshing,
    'last=\$last',
  );

  // Outside a batch a single write notifies once.
  notifications = 0;
  view.isLoading = false;
  check(
    'single-write-notifies-once',
    notifications == 1,
    'notifications=\$notifications',
  );

  // A write that changes nothing is silent (signal equality gate).
  notifications = 0;
  view.isLoading = false;
  check(
    'no-op-write-is-silent',
    notifications == 0,
    'notifications=\$notifications',
  );

  // Presenter ownership: disposing the presenter releases the signals.
  final owned = CartViewState();
  final presenter = CartPresenter(owned);
  check('signal-live-while-presenter-lives', !owned.state.isDisposed);
  presenter.dispose();
  check('signal-disposed-with-presenter', owned.state.isDisposed);

  print(failures == 0 ? 'PROBE OK' : 'PROBE FAILED (\$failures)');
  if (failures > 0) exitCode = 1;
}
''';

void main() {
  late Directory fixture;
  late Directory stateDir;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await Directory.systemTemp.createTemp('zfa_state_signal_e2e_');
    stateDir = Directory(
      p.join(fixture.path, 'lib', 'presentation', 'pages', 'cart'),
    );
    await stateDir.create(recursive: true);

    await _write(
      p.join(fixture.path, 'pubspec.yaml'),
      'name: zfa_state_signal_fixture\n'
      'publish_to: none\n'
      'environment:\n'
      '  sdk: ^3.11.0\n'
      'dependencies:\n'
      '  zuraffa:\n'
      '    path: $repoRoot\n',
    );
    await _write(
      p.join(fixture.path, 'lib', 'domain', 'entities', 'cart', 'cart.dart'),
      'class Cart {\n'
      '  final String id;\n'
      '  const Cart({required this.id});\n'
      '}\n',
    );
    await _write(p.join(stateDir.path, 'cart_state.dart'), _sourceStateFile);

    final migrator = StateMigrator();
    final result = await migrator.migrate(
      findings: [
        MigrationFinding(
          message: 'Mixed state',
          filePath: 'lib/presentation/pages/cart/cart_state.dart',
          line: 1,
          ruleId: 'v5_mixed_state',
          severity: MigrationSeverity.warning,
        ),
      ],
      projectDir: fixture.path,
      dryRun: false,
    );
    expect(
      result.filesCreated,
      equals(2),
      reason: 'the migration must emit the domain + view state',
    );

    await _write(p.join(stateDir.path, 'cart_presenter.dart'), _presenterFile);
    await _write(p.join(fixture.path, 'bin', 'probe.dart'), _probeFile);

    final pub = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: fixture.path);
    expect(
      pub.exitCode,
      0,
      reason:
          'dart pub get must succeed in the fixture.\n${pub.stdout}${pub.stderr}',
    );
  });

  tearDownAll(() async {
    if (await fixture.exists()) {
      try {
        await fixture.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test(
    'generated state analyzes clean and notifies once per batched transition',
    () async {
      final analyze = await Process.run('dart', [
        'analyze',
        '--no-fatal-warnings',
        'lib',
      ], workingDirectory: fixture.path);
      final analyzeOutput = '${analyze.stdout}${analyze.stderr}';
      expect(
        analyze.exitCode,
        0,
        reason:
            'the emitted state must analyze clean with no manual edit:\n'
            '$analyzeOutput',
      );

      final probe = await Process.run('dart', [
        'run',
        'bin/probe.dart',
      ], workingDirectory: fixture.path);
      final probeOutput = '${probe.stdout}${probe.stderr}';
      expect(
        probe.exitCode,
        0,
        reason: 'the generated state must behave as specified:\n$probeOutput',
      );
      expect(probeOutput, contains('PASS batch-notifies-once'));
      expect(probeOutput, contains('PASS final-values-visible'));
      expect(
        probeOutput,
        contains('PASS one-notification-carries-final-values'),
      );
      expect(probeOutput, contains('PASS signal-disposed-with-presenter'));
      expect(probeOutput, contains('PROBE OK'));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _write(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
