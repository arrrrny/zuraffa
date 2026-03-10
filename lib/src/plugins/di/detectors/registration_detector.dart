import 'dart:io';
import 'package:path/path.dart' as path;
import '../../../models/generated_file.dart';

class RegistrationInfo {
  final String fileName;
  final String functionName;

  const RegistrationInfo({required this.fileName, required this.functionName});
}

class RegistrationDetector {
  const RegistrationDetector();

  List<RegistrationInfo> detectRegistrations(
    String directoryPath, {
    List<GeneratedFile> pendingFiles = const [],
  }) {
    final filesMap = <String, String>{};

    // 1. Read existing files from disk
    final dir = Directory(directoryPath);
    if (dir.existsSync()) {
      final files = dir.listSync().whereType<File>().where(
        (file) => file.path.endsWith('_di.dart'),
      );

      for (final file in files) {
        final fileName = path.basename(file.path);
        if (fileName == 'index.dart') continue;
        filesMap[fileName] = file.readAsStringSync();
      }
    }

    // 2. Merge pending files (create/update/delete)
    for (final file in pendingFiles) {
      // Check if file is in the target directory
      if (path.dirname(file.path) == directoryPath) {
        final fileName = path.basename(file.path);

        // Skip index.dart
        if (fileName == 'index.dart') continue;

        // Only consider DI files
        if (!fileName.endsWith('_di.dart')) continue;

        if (file.action == 'deleted') {
          filesMap.remove(fileName);
        } else if (file.content != null) {
          filesMap[fileName] = file.content!;
        }
      }
    }

    final registrations = <RegistrationInfo>[];
    filesMap.forEach((fileName, content) {
      final match = RegExp(
        r'void\s+(register\w+)\s*\(\s*GetIt\s+getIt\s*\)',
      ).firstMatch(content);

      if (match != null) {
        final functionName = match.group(1);
        if (functionName != null) {
          registrations.add(
            RegistrationInfo(fileName: fileName, functionName: functionName),
          );
        }
      }
    });

    // Sort for deterministic output
    registrations.sort((a, b) => a.fileName.compareTo(b.fileName));

    return registrations;
  }
}
