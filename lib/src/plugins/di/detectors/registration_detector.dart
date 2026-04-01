import 'package:path/path.dart' as path;
import '../../../models/generated_file.dart';
import '../../../core/context/file_system.dart';

class RegistrationInfo {
  final String fileName;
  final String functionName;

  const RegistrationInfo({required this.fileName, required this.functionName});
}

class RegistrationDetector {
  const RegistrationDetector();

  Future<List<RegistrationInfo>> detectRegistrations(
    String directoryPath, {
    List<GeneratedFile> pendingFiles = const [],
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    final filesMap = <String, String>{};

    // 1. Read existing files from disk via FileSystem
    if (await fs.exists(directoryPath)) {
      final items = await fs.list(directoryPath);
      for (final item in items) {
        if (item.endsWith('_di.dart')) {
          final fileName = path.basename(item);
          if (fileName == 'index.dart') continue;
          filesMap[fileName] = await fs.read(item);
        }
      }
    }

    // 2. Merge pending files (create/update/delete)
    for (final file in pendingFiles) {
      if (path.dirname(file.path) == directoryPath) {
        final fileName = path.basename(file.path);

        if (fileName == 'index.dart') continue;
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
