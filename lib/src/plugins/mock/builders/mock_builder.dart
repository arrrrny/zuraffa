import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../core/transaction/generation_transaction.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/entity_utils.dart';
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

    if (!isPolymorphic) {
      final dataConfig = config.name == targetEntity
          ? config
          : config.copyWith(name: targetEntity);

      final hasCustomVerbs =
          config.paramsType != null ||
          config.returnsType != null ||
          config.methods.any(
            (m) => !const {
              'get',
              'getList',
              'list',
              'create',
              'update',
              'toggle',
              'delete',
              'watch',
              'watchList',
            }.contains(m),
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
        // Issue #1845: only generate mock data for custom-usecase runs
        // when there is no entity file on disk.
        if (config.isCustomUseCase) {
          files.add(await dataBuilder.generateMockDataFile(dataConfig));
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

    if (entityExists) {
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
        if (EntityAnalyzer.lacksCrudSurface(
          targetEntity,
          outputDir,
          fileSystem: fileSystem,
        )) {
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
