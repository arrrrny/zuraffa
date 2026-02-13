class GeneratorOptions {
  final bool dryRun;
  final bool force;
  final bool verbose;

  const GeneratorOptions({
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

  GeneratorOptions copyWith({bool? dryRun, bool? force, bool? verbose}) {
    return GeneratorOptions(
      dryRun: dryRun ?? this.dryRun,
      force: force ?? this.force,
      verbose: verbose ?? this.verbose,
    );
  }
}
