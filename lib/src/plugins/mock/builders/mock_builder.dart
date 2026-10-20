import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../core/transaction/generation_transaction.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/method_extractor.dart';
import '../../../utils/string_utils.dart';
import '../../datasource/builders/interface_generator.dart';
import 'failing_mock_provider_builder.dart';
import 'mock_data_builder.dart';
import 'mock_datasource_builder.dart';
import 'mock_provider_builder.dart';
import 'mock_entity_graph_builder.dart';
import 'mock_json_builder.dart';

/// Generates mock data builders for entities and their variants.
class MockBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockDataBuilder dataBuilder;
  final MockDataSourceBuilder dataSourceBuilder;
  // #417: emits the `${entitySnake}_datasource.dart` interface file when
  // MockBuilder runs without the datasource plugin active. The mock
  // datasource file always imports + implements `${entityName}DataSource`;
  // without the interface file the generated code is broken
  // (uri_does_not_exist + implements_non_class).
  final DataSourceInterfaceBuilder interfaceBuilder;
  final MockProviderBuilder providerBuilder;
  // Spec 1110: the `--fail` preset's throwing double.
  final FailingMockProviderBuilder failingProviderBuilder;
  final MockEntityGraphBuilder entityGraphBuilder;
  final MockJsonBuilder jsonBuilder;
  final FileSystem fileSystem;

  /// Creates a [MockBuilder].
  MockBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockDataBuilder? dataBuilder,
    MockDataSourceBuilder? dataSourceBuilder,
    DataSourceInterfaceBuilder? interfaceBuilder,
    MockProviderBuilder? providerBuilder,
    FailingMockProviderBuilder? failingProviderBuilder,
    MockEntityGraphBuilder? entityGraphBuilder,
    MockJsonBuilder? jsonBuilder,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create(),
       dataBuilder =
           dataBuilder ??
           MockDataBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       dataSourceBuilder =
           dataSourceBuilder ??
           MockDataSourceBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       interfaceBuilder =
           interfaceBuilder ??
           DataSourceInterfaceBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       providerBuilder =
           providerBuilder ??
           MockProviderBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       failingProviderBuilder =
           failingProviderBuilder ??
           FailingMockProviderBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       entityGraphBuilder =
           entityGraphBuilder ??
           MockEntityGraphBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       jsonBuilder =
           jsonBuilder ??
           MockJsonBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(),
           );

  /// Issue #1952: refuses a `--force` run whose interface regeneration
  /// would drop declared members the generator's vocabulary cannot
  /// reproduce — a hand-authored contract. Throws [StateError] naming the
  /// interface file and the lost members, before any file is written, so
  /// the CLI exits non-zero and the tree stays byte-identical. Members
  /// inside [DataSourceInterfaceBuilder.interfaceEmissionVocabulary] are
  /// the #1418 methods-driven drift (a previous generated emission's
  /// output) and keep regenerating.
  Future<void> _refuseLostDeclaredMembers(GeneratorConfig config) async {
    if (config.generateMockDataOnly ||
        config.hasService ||
        config.appendToExisting ||
        !config.force ||
        config.revert ||
        config.overwriteInterface) {
      return;
    }
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final interfacePath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
      '${entitySnake}_datasource.dart',
    );
    if (!await fileSystem.exists(interfacePath)) return;
    // PR #1649: a combined make run whose datasource plugin already owns
    // this path in the shared transaction keeps its contract — the mock
    // lane does not speak for it.
    final interfacePending =
        GenerationTransaction.current?.operations.any(
          (op) => op.path == interfacePath,
        ) ??
        false;
    if (interfacePending) return;
    // The interface writer only fires past these gates (#1037/#1747): an
    // enum target returns before it — gated on the same returns-type-derived
    // target the writer arm checks (a custom-usecase run whose returns
    // entity is an enum returns before the writer, so the guard must not
    // refuse it either) — and a no-CRUD-surface target without a declared
    // interface is skipped before it too. Refuse only where the writer can
    // actually run.
    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;
    if (EntityAnalyzer.isEnum(
      targetEntity,
      outputDir,
      fileSystem: fileSystem,
    )) {
      return;
    }
    if (EntityAnalyzer.lacksCrudSurface(
          entityName,
          outputDir,
          fileSystem: fileSystem,
        ) &&
        !EntityAnalyzer.hasDeclaredDataSourceInterface(
          entityName,
          outputDir,
          fileSystem: fileSystem,
        )) {
      return;
    }
    final declared = await MethodExtractor.extractMethodsFromInterface(
      interfacePath,
      '${entityName}DataSource',
      fileSystem: fileSystem,
    );
    if (declared.isEmpty) {
      // Never a silent skip: this arm also swallows an interface whose class
      // no longer matches `${entityName}DataSource` (a renamed class, extra
      // declarations in the file) — say why the refusal did not arm.
      if (config.verbose) {
        print(
          'ℹ️  No declared members parsed from $interfacePath as '
          '${entityName}DataSource — the issue #1952 refusal does not arm.',
        );
      }
      return;
    }
    final planned = DataSourceInterfaceBuilder.plannedMemberNames(config);
    final lost = declared
        .map((member) => member.fieldName)
        .where((name) => !planned.contains(name))
        .where(
          (name) => !DataSourceInterfaceBuilder.interfaceEmissionVocabulary
              .contains(name),
        )
        .toList();
    if (lost.isEmpty) return;
    throw StateError(
      'Refusing to overwrite $interfacePath: --force would remove the '
      'declared member(s) ${lost.join(", ")} that this run\'s --methods do '
      'not declare (issue #1952). Add the members to --methods, or pass '
      '--overwrite-interface to discard them explicitly.',
    );
  }

  /// Generates mock files for the given [config].
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.generateMockJson) {
      return jsonBuilder.generate(config);
    }

    final files = <GeneratedFile>[];

    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;

    // Issue #1952: a `--force` run must not silently replace a hand-authored
    // `<Entity>DataSource` interface with the generated CRUD surface. Before
    // the first write, the on-disk declared members are compared against the
    // member names this run's emission would declare; a loss outside the
    // interface vocabulary (a member no generated emission could ever carry)
    // refuses the run. Gated exactly like the interface writer's own force
    // arm below — data-only/service runs never reach it, an append run
    // takes the writer's add-only append branch (nothing is removed), enums
    // and no-CRUD-surface targets return before it (#1037/#1747), a revert
    // run keeps the revert contract, an interface this run's datasource
    // plugin already owns stays #1649's, and `--overwrite-interface` is the
    // explicit opt-in.
    await _refuseLostDeclaredMembers(config);

    // Issue #1922: validate every arbitrary member shape BEFORE the first
    // write. The datasource-interface writer below used to run first, so a
    // refused member (the #1850 "honest bodies" ArgumentError) exited 1
    // with `<Entity>DataSource` — and the fixture files above it — already
    // clobbered. The pre-flight is gated exactly like the emission path
    // (data-only and service runs never emit the CRUD datasource surface,
    // and enum / no-CRUD-surface targets are skipped before the writer
    // too), so no working path changes.
    if (!config.generateMockDataOnly &&
        !config.hasService &&
        !EntityAnalyzer.isEnum(
          targetEntity,
          outputDir,
          fileSystem: fileSystem,
        ) &&
        !EntityAnalyzer.lacksCrudSurface(
          targetEntity,
          outputDir,
          fileSystem: fileSystem,
        )) {
      MockDataSourceBuilder.validateMemberShapes(
        config,
        fileSystem: fileSystem,
      );
    }

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      targetEntity,
      outputDir,
      fileSystem: fileSystem,
    );
    final isPolymorphic = subtypes.isNotEmpty;
    final entityExists = EntityAnalyzer.entityFileExists(
      targetEntity,
      outputDir,
      fileSystem: fileSystem,
    );

    // Issue #1851: in service mode the "entity" is the service interface
    // (an abstract type). Never emit a mock-data file instantiating it;
    // only concrete fixture entities (params/returns) get fixtures, and
    // those are handled by the fixture loop below.
    // Issue #1851: skip the top-level mock-data file only when the target
    // is the service interface itself (an abstract type) — never instantiate
    // it. Concrete return/param entities still get their fixtures here.
    if (!isPolymorphic &&
        !(config.hasService && targetEntity == config.effectiveService)) {
      final dataConfig = config.name == targetEntity
          ? config
          : config.copyWith(name: targetEntity);

      final hasCustomVerbs =
          config.paramsType != null ||
          config.returnsType != null ||
          config.methods.any(
            (m) => !DataSourceInterfaceBuilder.interfaceEmissionVocabulary
                .contains(m),
          );
      final needsConcreteEntity =
          config.generateMockDataOnly ||
          (config.name == targetEntity &&
              !config.isCustomUseCase &&
              !config.hasService &&
              !hasCustomVerbs);

      if (!entityExists) {
        if (needsConcreteEntity) {
          throw StateError(
            'Entity file not found for $targetEntity. '
            'Expected to find a Dart entity declaration under '
            '$outputDir/domain/entities.',
          );
        }
        // Issue #1865: only generate mock data for custom-usecase runs
        // when there is a returns entity; otherwise skip with an honest
        // `skipped` action (like the primitive path) instead of writing a
        // phantom `*_mock_data.dart` for a non-existent entity.
        if (config.isCustomUseCase) {
          if (config.returnsType == null || config.returnsType!.isEmpty) {
            files.add(
              GeneratedFile(
                path: '',
                content: '',
                action: 'skipped',
                type: 'mock_data',
              ),
            );
          } else {
            files.add(await dataBuilder.generateMockDataFile(dataConfig));
          }
        }
      } else if (EntityAnalyzer.isSealedEntity(
        targetEntity,
        outputDir,
        fileSystem: fileSystem,
      )) {
        print(
          '⚠️  No concrete polymorphic subtypes found for sealed entity '
          '$targetEntity. Skipping mock data generation for the base type.',
        );
      } else {
        files.add(await dataBuilder.generateMockDataFile(dataConfig));
      }
    }

    if (!config.hasService && entityExists) {
      files.addAll(
        await entityGraphBuilder.generateNestedEntityMockFiles(
          config: config.name == targetEntity
              ? config
              : config.copyWith(name: targetEntity),
          generateMockDataFile: dataBuilder.generateMockDataFile,
        ),
      );
    }

    if (!config.generateMockDataOnly) {
      // Issue #1037: an enum entity is a value type — no id, no Patch, no
      // copyWithField — so the class-shaped CRUD datasource/provider
      // surface cannot compile against it (the entity lives under
      // entities/enums/, not the canonical class path). The mock-data
      // section above already emitted enum-value fixtures; emitting the
      // stack here produces the #1037 lie the `zfa build` analyzer gate
      // then correctly refuses, dead-ending every `zfa tdd` feature that
      // traces the enum as a Key Entity.
      if (EntityAnalyzer.isEnum(
        targetEntity,
        outputDir,
        fileSystem: fileSystem,
      )) {
        print(
          'ℹ️  $targetEntity is an enum entity — mock data generated; '
          'skipping the CRUD datasource/provider surface (issue #1037).',
        );
        return files;
      }
      if (!config.hasService) {
        // Issue #1747: a non-enum type may still be no CRUD entity at all —
        // a plain DTO or value class declares no `id`, no `copyWithField`,
        // and no `<Type>Patch` companion, so the class-shaped datasource
        // body below cannot compile against it (the #1037 enum lie in a
        // different shape), while the mock certification still reports
        // `(conforms)`. Emit the fixtures the mock-data section above
        // already produced and stop, naming the missing surface instead of
        // writing a broken pair. Service-mode providers are unaffected —
        // they implement the service interface, not the entity's CRUD
        // surface, so the `!hasService` gate above keeps them flowing.
        // Gated on the source being ON DISK ([lacksCrudSurface]): a target
        // with no entity file at all keeps its historical path — there is
        // nothing to probe, and that shape is a different report. The same
        // predicate gates MockPlugin's simulation binding, so the two
        // cannot disagree about whether this run emits a CRUD surface.
        // Issue #1898: only short-circuit when the requested methods
        // actually need the CRUD surface. A run asking solely for
        // non-CRUD verbs (`list`, or any verb outside the standard CRUD
        // vocabulary) keeps the datasource/mock-datasource path open, so
        // the #1787 arm is reachable on a non-CRUD entity.
        if (EntityAnalyzer.lacksCrudSurface(
              targetEntity,
              outputDir,
              fileSystem: fileSystem,
            ) &&
            !EntityAnalyzer.hasDeclaredDataSourceInterface(
              targetEntity,
              outputDir,
              fileSystem: fileSystem,
            ) &&
            EntityAnalyzer.methodsRequireCrudSurface(config.methods)) {
          print(
            'ℹ️  $targetEntity declares no CRUD surface (no id / '
            'copyWithField / ${targetEntity}Patch) — mock data generated; '
            'skipping the CRUD datasource/provider surface (issue #1747).',
          );
          return files;
        }
        // #417: ensure the datasource interface file exists before emitting
        // the mock_datasource that imports + implements
        // `${entityName}DataSource`. Without the interface file the
        // generated mock_datasource triggers uri_does_not_exist +
        // implements_non_class when the datasource plugin is NOT active
        // (e.g. `zfa make X mock repository` without `datasource`).
        //
        // The check is file-existence-based (not plugin-active-based) so it
        // works regardless of plugin execution order:
        //   * DataSourcePlugin ran first → file exists → skip (no conflict).
        //   * RepositoryPlugin's #406 fallback ran first → file exists → skip.
        //   * MockPlugin runs first / alone → file missing → MockBuilder
        //     emits it here.
        final interfaceEntityName = config.repo != null
            ? config.repo!.replaceAll('Repository', '')
            : config.name;
        final interfaceSnake = StringUtils.camelToSnake(interfaceEntityName);
        final interfacePath = path.join(
          outputDir,
          'data',
          'datasources',
          interfaceSnake,
          '${interfaceSnake}_datasource.dart',
        );
        // Issue #1418: --force must regenerate the WHOLE generated pair.
        // The old guard was pure create-if-absent: an existing interface
        // was never invalidated by --force (nor by a --methods change),
        // while the mock body always regenerated from the current
        // --methods — the pair drifted and `--certify` dead-ended on
        // `Missing concrete implementation`. Under `force && !revert` the
        // interface writer is invoked unconditionally and its fresh-write
        // path (exists && (append || !force) → else force overwrite)
        // regenerates the interface from the current config.methods — the
        // same pattern the datasource and repository plugins already use.
        // Non-force keeps the #417 create-if-absent contract byte-for-byte
        // (the writer is not invoked on an existing file, so its append
        // path cannot fire from the mock lane), and revert keeps the
        // revert contract (the guard does not fire over it — the same
        // precedence the #1570 staleness arming uses).
        //
        // Invariant (PR #1649 review): this guard arms on `config.force`,
        // but the writer's overwrite path fires on `options.force`
        // (DataSourceInterfaceBuilder.generate → FileUtils.writeFile(force:
        // options.force)). The two cannot diverge on real call paths —
        // MockPlugin.generate re-delegates with GeneratorOptions mirrored
        // from config whenever they disagree — and a future direct
        // MockBuilder caller must preserve that mirroring, or a
        // guard-fired writer invocation is silently skipped (ledger
        // `skipped`, no regeneration).
        // PR #1649 follow-up (A-1530-6): under `force && !revert` the
        // writer must not fire when THIS RUN already owns the file — a
        // combined `make Product datasource --with mock --force` has the
        // datasource plugin's own force-overwrite of the same interface
        // pending in the shared transaction, and GenerationTransaction
        // rejects two operations for one path ("Multiple operations for
        // …"). Standalone `mock create --force` has no pending claim and
        // still regenerates. Same "check current transaction first" seam
        // as DiscoveryEngine; raw-path equality mirrors the transaction's
        // own duplicate detection (both writers emit the identical joined
        // path).
        final interfacePending =
            GenerationTransaction.current?.operations.any(
              (op) => op.path == interfacePath,
            ) ??
            false;
        if (!await fileSystem.exists(interfacePath) ||
            (config.force && !config.revert && !interfacePending)) {
          files.add(await interfaceBuilder.generate(config));
        }
        files.add(await dataSourceBuilder.generateMockDataSource(config));
        // Spec 1110 (issue #1110): the `--fail` preset — a throwing twin
        // of the certified mock, emitted beside the mock datasource
        // (same interface, every method throws the sealed failure type).
        // The succeeding mock artifacts above are still generated: the
        // pair (succeeding + failing) is the feature.
        if (config.failMock) {
          files.add(
            await failingProviderBuilder.generateFailingMockProvider(config),
          );
        }
      }
      if (config.hasService) {
        files.add(await providerBuilder.generateMockProvider(config));
        // Issue #1735: the provider imports a `<snake>_mock_data.dart` fixture
        // for every entity type it names, but only the target entity's fixture
        // came out of the mock-data path above — a service-mode run with a
        // `--params` type emitted the import and no file, so its own output
        // failed `dart analyze` with uri_does_not_exist. Emit the rest here, in
        // the same run, so every import the provider writes resolves.
        final emitted = files.map((file) => file.path).toSet();
        for (final fixtureType in await providerBuilder.fixtureEntityTypes(
          config,
        )) {
          if (!EntityAnalyzer.entityFileExists(
            fixtureType,
            outputDir,
            fileSystem: fileSystem,
          )) {
            continue;
          }
          // Review #1739: the fixture's identity only — never the parent
          // SERVICE's `returnsType` / `useCaseType` / `isCustomUseCase`, which
          // `copyWith` carried over. `generateMockDataFile` short-circuits a
          // primitive `--returns` to an empty path, so a service returning
          // `String` dropped the params fixture the provider still imported.
          // The nested builder builds its configs from scratch for the same
          // reason; `seed` flows through to keep spec 1001's replays stable.
          final fixtureConfig = GeneratorConfig(
            name: fixtureType,
            generateMockDataOnly: true,
            outputDir: outputDir,
            revert: config.revert,
            force: config.force,
            verbose: config.verbose,
            seed: config.seed,
          );
          // Review #1739: claim the path BEFORE writing. `generateMockDataFile`
          // writes as a side effect, so the post-hoc check this loop used to
          // run could not stop a second write of a path the mock-data path
          // above had already emitted — one operation per path, and two for
          // that path is exactly what GenerationTransaction rejects
          // ("Multiple operations for …") when the run is wrapped in one.
          final fixturePath = dataBuilder.mockDataPathFor(fixtureType);
          if (!emitted.add(fixturePath)) continue;
          final fixtureFile = await dataBuilder.generateMockDataFile(
            fixtureConfig,
          );
          if (fixtureFile.path.isEmpty) {
            // Nothing was written (primitive / completable shape), so release
            // the claim and let a later fixture type take this path.
            emitted.remove(fixturePath);
            continue;
          }
          files.add(fixtureFile);
          files.addAll(
            await entityGraphBuilder.generateNestedEntityMockFiles(
              config: fixtureConfig,
              // The nested builder de-duplicates only within its own call, so
              // a nested entity/enum shared by two fixture types was written
              // once per type. Claim its path through the same set, and report
              // the loser as an honest skip.
              generateMockDataFile: (nestedConfig) async {
                final nestedPath = dataBuilder.mockDataPathFor(
                  nestedConfig.name,
                );
                if (!emitted.add(nestedPath)) {
                  return GeneratedFile(
                    path: '',
                    content: '',
                    action: 'skipped',
                    type: 'mock_data',
                  );
                }
                return dataBuilder.generateMockDataFile(nestedConfig);
              },
            ),
          );
        }
        if (config.failMock) {
          // Honest scope notice (never a silent skip): the failure preset
          // targets the entity datasource seam; the service-mode provider
          // twin is future work.
          print(
            '⚠️  --fail preset: the failing provider is emitted for the '
            'entity datasource interface; the service-mode failing '
            'provider (spec 1110) is not generated for '
            '"${config.effectiveService}".',
          );
        }
      }
    }

    return files;
  }
}
