/// `CycleLog` — append-only writer for `tdd/cycle-log.md`.
library;

import 'dart:io';

import '../models/cycle_entry.dart';

class CycleLog {
  const CycleLog(this.featureDir);

  final String featureDir;

  Future<void> append(CycleLogEntry entry) async {
    final dir = Directory('$featureDir/tdd');
    final file = File('${dir.path}/cycle-log.md');
    await dir.create(recursive: true);

    if (!await file.exists()) {
      await file.writeAsString(
        '# Cycle Log\n\nAppend only. Newest last. Every entry\'s `red` block '
        'is the evidence that the test existed and failed before the '
        'implementation.\n\n',
      );
    }

    final sink = file.openWrite(mode: FileMode.append);
    sink.write(entry.toMarkdown());
    await sink.close();
  }
}
