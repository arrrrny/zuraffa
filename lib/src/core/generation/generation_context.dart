import '../../models/generator_config.dart';
import '../context/context_store.dart';
import '../context/file_system.dart';
import '../context/progress_reporter.dart';

class GenerationContext {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final FileSystem fileSystem;
  final ContextStore store;
  final ProgressReporter progress;

  GenerationContext({
    required this.config,
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    required this.fileSystem,
    required this.store,
    required this.progress,
  });

  factory GenerationContext.create({
    required GeneratorConfig config,
    String outputDir = 'lib/src',
    bool dryRun = false,
    bool force = false,
    bool verbose = false,
    String? root,
    ProgressReporter? progressReporter,
  }) {
    return GenerationContext(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      fileSystem: FileSystem.create(root: root),
      store: ContextStore(),
      progress:
          progressReporter ??
          (verbose
              ? CliProgressReporter(verbose: true)
              : NullProgressReporter()),
    );
  }
}
