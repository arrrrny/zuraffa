import 'dart:io';

Future<void> main(List<String> args) async {
  final grandchild = await Process.start(Platform.resolvedExecutable, [args[0]]);
  await grandchild.exitCode;
}