import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// SC-003 / FR-005 acceptance + unit tests for the generator's pure-Dart
/// view mode (spec 038, behaviors U23..U26).
///
/// - U23: `generateView(..., pureDart: true)` emits the v6 pattern
///   (ControlledWidget + FragmentBuilder + SignalBuilder) importing only
///   `package:zuraffa/zuraffa.dart`.
/// - U24: the default (Flutter) emission stays byte-identical to the
///   pre-feature output (FR-006 — no breaking changes).
/// - U25: the generated view compiles — `dart analyze` on a temp package
///   directory inside this repo, with fixture presenter/domain/view-state
///   files, reports no errors.
/// - U26: the widget types are exported from the package barrel.
/// Walk up from the current working directory (the package root when
/// `dart test` runs) to the repo root (where `pubspec.yaml` lives) so the
/// temp package can pin `zuraffa` via an absolute `path:` dependency and
/// resolve it offline instead of reaching for the network.
String _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return dir.path;
}

void main() {
  late Directory tempDir;
  late ViewTemplateGenerator gen;

  setUp(() {
    tempDir = Directory('.tmp_sc003_${DateTime.now().microsecondsSinceEpoch}');
    tempDir.createSync();
    gen = ViewTemplateGenerator(outputDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('ViewTemplateGenerator pureDart mode (FR-005, SC-003)', () {
    test('emits ControlledWidget + FragmentBuilder + SignalBuilder [U23]', () {
      final path = gen.generateView(
        'ProductDetail',
        useCases: ['product', 'reviews'],
        pureDart: true,
      );
      final content = File(path).readAsStringSync();

      // Pure-Dart imports only — no Flutter, no zuraffa_flutter.
      expect(content, contains("import 'package:zuraffa/zuraffa.dart'"));
      expect(
        content,
        isNot(contains('flutter')),
        reason: 'pure-Dart mode must not reference Flutter',
      );
      expect(content, contains("import 'product_detail_presenter.dart'"));

      // v6 pattern.
      expect(
        content,
        contains('extends ControlledWidget<ProductDetailPresenter>'),
        reason: 'generated views extend the typed controlled base class',
      );
      expect(
        content,
        contains('FragmentBuilder<dynamic>'),
        reason: 'one FragmentBuilder per use-case slice',
      );
      expect(
        content,
        contains('controller.domain.product.refresh();'),
        reason: 'onInit bootstraps the lazy product slice field',
      );
      expect(
        content,
        contains('controller.domain.reviews.refresh();'),
        reason: 'onInit bootstraps the lazy reviews slice field',
      );
      expect(
        content,
        contains('slice: controller.domain.product,'),
        reason: 'build binds the typed product slice field',
      );
      expect(
        content,
        contains('slice: controller.domain.reviews,'),
        reason: 'build binds the typed reviews slice field',
      );
      expect(
        content,
        contains('SignalBuilder<bool>'),
        reason: 'SignalBuilder for the isLoading UI signal',
      );
      expect(
        content,
        contains('SignalBuilder<int>'),
        reason: 'SignalBuilder for the activeTabIndex UI signal',
      );
      expect(
        content,
        contains('context.attach('),
        reason: 'fragments attach through the view context',
      );
      expect(
        content,
        contains('ViewContext context'),
        reason: 'build takes the pure-Dart ViewContext',
      );
      expect(content, contains('onInit()'));
    });

    test('default Flutter emission is byte-identical to pre-feature [U24]', () {
      final path = gen.generateView(
        'ProductDetail',
        useCases: ['product', 'reviews'],
      );
      final content = File(path).readAsStringSync();

      // Golden captured from master at 4c1c2641 BEFORE this feature touched
      // the generator (FR-006: the default emission must not change).
      expect(content, _preFeatureFlutterGolden);
    });

    test(
      'generated pure-Dart view compiles under dart analyze [U25]',
      () async {
        // Self-contained temp PACKAGE (not a bare dir): a pubspec.yaml with a
        // path dependency on the repo gives `dart analyze` a deterministic
        // resolution root. Running `dart analyze` on a pubspec-less directory
        // inside the repo made the check depend on ambient package resolution
        // walking up to the repo root, which timed out in CI (the comment
        // above already calls this a "temp package").
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: sc003_temp
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  zuraffa:
    path: ${_repoRoot()}
''');
        // Fixture presenter pipeline (mirrors generatePresenter output shape,
        // importing the pure-Dart core barrel).
        File(
          '${tempDir.path}/product_detail_view_state.dart',
        ).writeAsStringSync(_fixtureViewState);
        File(
          '${tempDir.path}/product_detail_domain_state.dart',
        ).writeAsStringSync(_fixtureDomainState);
        File(
          '${tempDir.path}/product_detail_presenter.dart',
        ).writeAsStringSync(_fixturePresenter);

        gen.generateView(
          'ProductDetail',
          useCases: ['product', 'reviews'],
          pureDart: true,
        );

        final pubGet = await Process.run(Platform.resolvedExecutable, [
          'pub',
          'get',
        ], workingDirectory: tempDir.path);
        final pubGetOut = pubGet.stdout.toString() + pubGet.stderr.toString();
        expect(
          pubGet.exitCode,
          0,
          reason:
              'dart pub get in the temp package must succeed. '
              'Output:\n$pubGetOut',
        );

        final result = await Process.run(Platform.resolvedExecutable, [
          'analyze',
          '--no-fatal-warnings',
        ], workingDirectory: tempDir.path);
        final output = result.stdout.toString() + result.stderr.toString();

        expect(
          result.exitCode,
          0,
          reason:
              'generated view + fixtures must analyze clean. '
              'Output:\n$output',
        );
        expect(
          output,
          isNot(contains(' error - ')),
          reason: 'no analyzer errors allowed in generated code:\n$output',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('widget types are exported from the package barrel [U26]', () {
      // Compiling at all proves the barrel resolves; the base-typed
      // assignments below prove each class is usable through
      // package:zuraffa/zuraffa.dart, so accidental export removals fail here.
      final ControlledWidget<_ProbeController> asBase = _ProbeView(
        controller: _ProbeController(),
      );
      expect(asBase.controller, isA<_ProbeController>());
      expect(asBase.controller, isNotNull);
      expect(
        FragmentBuilder<int>(
          slice: SignalSlice<int>(useCase: _ProbeUseCase(), params: null),
          builder: (context, data) => data,
        ).runtimeType.toString(),
        contains('FragmentBuilder'),
      );
      expect(
        SignalBuilder<bool>(
          signal: Signal<bool>(false),
          builder: (context, value) => value,
        ).runtimeType.toString(),
        contains('SignalBuilder'),
      );
      expect(
        WidgetHost<_ProbeController>(
          _ProbeView(controller: _ProbeController()),
        ).runtimeType.toString(),
        contains('WidgetHost'),
      );
      expect(FragmentContextError('probe').message, 'probe');
    });
  });
}

class _ProbeController {}

class _ProbeView extends ControlledWidget<_ProbeController> {
  _ProbeView({required super.controller});
}

class _ProbeUseCase extends ZuraffaUseCase<dynamic, int> {
  @override
  SignalResult<int> call(dynamic params, {ZuraffaContext? context}) =>
      SignalResult<int>.success(0);
}

const _fixtureViewState = '''
import 'package:zuraffa/zuraffa.dart';

class ProductDetailViewState extends ViewState {
  ProductDetailViewState() {
    registerSignal(isLoading);
    registerSignal(activeTabIndex);
  }

  final isLoading = Signal<bool>(false);
  final activeTabIndex = Signal<int>(0);
}
''';

const _fixtureDomainState = '''
import 'package:zuraffa/zuraffa.dart';

class _ProbeUseCase extends ZuraffaUseCase<dynamic, dynamic> {
  @override
  SignalResult<dynamic> call(dynamic params, {ZuraffaContext? context}) =>
      SignalResult<dynamic>.success(null);
}

class ProductDetailDomainState extends DomainState {
  ProductDetailDomainState({required super.presenter});

  // Mirrors StateGenerator.generateDomainState output: late-final slice
  // fields whose names equal the slice keys.
  late final product = bind<dynamic>('product', _ProbeUseCase(), null);
  late final reviews = bind<dynamic>('reviews', _ProbeUseCase(), null);
}
''';

const _fixturePresenter = '''
import 'package:zuraffa/zuraffa.dart';

import 'product_detail_domain_state.dart';
import 'product_detail_view_state.dart';

// NOTE: the shipped generatePresenter emits `SlicePresenter()` — but
// SlicePresenter is abstract, so that emitted code cannot compile as-is.
// That quirk predates this feature (Flutter-mode output was never
// compile-checked); flagged in tdd/verification.md. The fixture uses a
// concrete subclass so the VIEW (the artifact under compile test) is
// validated on its own merits.
class _FixtureSlicePresenter extends SlicePresenter {
  _FixtureSlicePresenter() : super();
}

class ProductDetailPresenter extends DualLayerPresenter {
  ProductDetailPresenter()
      : super(
          domain: ProductDetailDomainState(presenter: _FixtureSlicePresenter()),
          view: ProductDetailViewState(),
        );

  @override
  ProductDetailViewState get view => super.view as ProductDetailViewState;

  @override
  ProductDetailDomainState get domain =>
      super.domain as ProductDetailDomainState;
}
''';

const _preFeatureFlutterGolden = '''
import 'package:flutter/material.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import 'product_detail_presenter.dart';

class ProductDetailView extends ControlledWidget<ProductDetailPresenter> {
  const ProductDetailView({
    Key? super.key,
    required ProductDetailPresenter super.controller,
  });

  @override
  void onInit() {
    controller.domain.slice('product')?.refresh();
    controller.domain.slice('reviews')?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // product slice
          FragmentBuilder<dynamic>(
            slice: controller.domain.slice('product')!,
            onLoading: (context) => const CircularProgressIndicator(),
            onError: (context, error) => Text(error.message),
            builder: (context, data) => Text(data.toString()),
          ),
          // reviews slice
          FragmentBuilder<dynamic>(
            slice: controller.domain.slice('reviews')!,
            onLoading: (context) => const CircularProgressIndicator(),
            onError: (context, error) => Text(error.message),
            builder: (context, data) => Text(data.toString()),
          ),
          // UI signals
          SignalBuilder<bool>(
            signal: controller.view.isLoading,
            builder: (context, value) => Text("isLoading: \$value"),
          ),
          SignalBuilder<int>(
            signal: controller.view.activeTabIndex,
            builder: (context, value) => Text("activeTabIndex: \$value"),
          ),
        ],
      ),
    );
  }
}
''';
