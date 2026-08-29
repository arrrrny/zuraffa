// Spec 025 demo app — the ENTIRE integration code a consuming app writes.
//
// Compare with `zfa setup` + `zfa app shell` apps: there is no
// setupDependencies(), no service locator import, no per-component
// registration. Importing the package and activating its module IS the
// wiring (FR-005, SC-002).
import 'package:zuraffa/zuraffa.dart';
import 'package:notes_package/notes_package.dart';

Future<void> main() async {
  // 1. Activate the package module (registerPackage validates the
  //    package's zuraffa constraint first — FR-015).
  final engine = ZuraffaEngine()..registerPackage(NotesPackageModule());

  // 2. Bootstrap: registerDependencies (auto-DI through the package
  //    registrar) runs for every module, then onInit.
  await engine.bootstrap();

  // 3. Ready: every module's onReady fires, in registration order.
  await engine.ready();

  // 4. The app container now resolves the package's contributions —
  //    with zero manual registration code in this file.
  final usecase = engine.di.get<GetNoteUseCase>();
  final note = await usecase.execute(
    QueryParams<Note>(params: {'id': 'id 1'}),
    null,
  );
  print('resolved via auto-DI: ${note.id} — ${note.body}');

  // 5. Merge the package's agent tools into the app registry, namespaced
  //    (FR-008): `notes_package.get_note`.
  final tools = McpToolRegistry();
  PackageAgentTools.registerInto(tools, NotesPackageModule(), engine.di);
  final result = await tools.find('notes_package.get_note')!.call({
    'params': {'id': 'id 2'},
  });
  print('agent tool notes_package.get_note → ${result.text}');

  // 6. Shutdown: onDispose runs in reverse registration order.
  await engine.shutdown();
  print('done.');
}
