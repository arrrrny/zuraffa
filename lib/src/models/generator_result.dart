import 'generated_file.dart';

class GeneratorResult {
  final bool success;
  final String name;
  final List<GeneratedFile> files;
  final List<String> errors;
  final List<String> nextSteps;

  GeneratorResult({
    required this.success,
    required this.name,
    required this.files,
    required this.errors,
    required this.nextSteps,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'name': name,
        'generated': files.map((f) => f.toJson()).toList(),
        'errors': errors,
        'next_steps': nextSteps,
      };
}
