/// AgentReadmeGenerator (spec 043): SLICE.md (FR-007).
///
/// The agent instruction file: what the slice is, which files may be
/// modified freely (owned) vs with caution (shared), the boundary
/// interfaces and their mocks, the run command with the exact `-t` path,
/// and how to hand the work back through `zfa slice merge`.
library;

import '../models/slice_manifest.dart';

/// Generates the agent instruction file.
class AgentReadmeGenerator {
  /// Generates the SLICE.md content for [manifest].
  String generate({required SliceManifest manifest}) {
    final owned = manifest.files
        .where((f) => f.ownership.name == 'owned')
        .toList();
    final shared = manifest.files
        .where((f) => f.ownership.name == 'shared')
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('# Slice: ${manifest.name}');
    buffer.writeln();
    buffer.writeln(
      'A self-contained, runnable extraction of the '
      '"${manifest.entries.join('", "')}" feature(s) from '
      '`${manifest.packageName}`.',
    );
    buffer.writeln();
    buffer.writeln('- Depth: `${manifest.depth.name}`');
    buffer.writeln('- Entry points:');
    for (final entry in manifest.entries) {
      buffer.writeln('  - `$entry`');
    }
    buffer.writeln('- Cut from branch: `${manifest.branch}`');
    buffer.writeln();

    buffer.writeln('## Files you may modify');
    buffer.writeln();
    buffer.writeln(
      'These files belong to this feature alone. Change them freely; merge '
      'will copy them back without warnings:',
    );
    buffer.writeln();
    for (final file in owned) {
      buffer.writeln('- `${file.relativePath}`');
    }
    buffer.writeln();

    buffer.writeln('## Files shared with other features');
    buffer.writeln();
    buffer.writeln(
      'These files are also used outside this slice. Modify with caution — '
      'merge will ask for confirmation before overwriting them in the main '
      'project:',
    );
    buffer.writeln();
    for (final file in shared) {
      buffer.writeln('- `${file.relativePath}`');
    }
    buffer.writeln();

    if (manifest.boundaries.isNotEmpty) {
      buffer.writeln('## Boundary interfaces');
      buffer.writeln();
      buffer.writeln(
        'Traversal stopped at these interfaces (the cut-off layers are not '
        'part of the slice). Each is wired to a generated mock — return '
        'realistic values from the mocks to exercise the feature:',
      );
      buffer.writeln();
      for (final boundary in manifest.boundaries) {
        final mock = 'Mock${boundary.typeName}';
        final note = boundary.mockStrategy == 'existing'
            ? ' (reuses the project\'s own mock)'
            : ' (generated at `lib/src/mocks/mock_${_snake(boundary.typeName)}.dart`)';
        buffer.writeln(
          '- **${boundary.typeName}** — `${boundary.interfaceFile}`'
          '${boundary.diRegistrationFile != null ? ', registered by `${boundary.diRegistrationFile}`' : ''}'
          ' → mocked by `$mock`$note',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('## Running the slice');
    buffer.writeln();
    buffer.writeln(
      'From the project root (the sandbox mirrors `lib/`, so package imports '
      'resolve against the project):',
    );
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln(
      'flutter run -t .zuraffa/slices/${manifest.name}/main_slice.dart',
    );
    buffer.writeln('```');
    buffer.writeln();

    buffer.writeln('## Handing your work back');
    buffer.writeln();
    buffer.writeln(
      'Edit the mirrored files under this sandbox. When done, the developer '
      'merges your changes into the main project with:',
    );
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln('zfa slice merge ${manifest.name}');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln(
      'Do not move or rename files — the merge maps sandbox paths back to '
      'project paths one to one.',
    );

    return buffer.toString();
  }

  String _snake(String typeName) {
    final buffer = StringBuffer();
    for (var i = 0; i < typeName.length; i++) {
      final ch = typeName[i];
      if (ch.toUpperCase() == ch && ch.toLowerCase() != ch && i > 0) {
        buffer.write('_');
      }
      buffer.write(ch.toLowerCase());
    }
    return buffer.toString();
  }
}
