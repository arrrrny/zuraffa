class GeneratorOptions {
  final bool dryRun;
  final bool force;
  final bool verbose;
  final bool revert;

  const GeneratorOptions({
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    this.revert = false,
  });

  GeneratorOptions copyWith({
    bool? dryRun,
    bool? force,
    bool? verbose,
    bool? revert,
  }) {
    return GeneratorOptions(
      dryRun: dryRun ?? this.dryRun,
      force: force ?? this.force,
      verbose: verbose ?? this.verbose,
      revert: revert ?? this.revert,
    );
  }
}
