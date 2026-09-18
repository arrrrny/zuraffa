/// The #307 id-gate refusal diagnostic, shared by every surface that
/// refuses an id-less entity BEFORE generation.
///
/// `zfa make` (lib/src/commands/make_command.dart) and the tdd make path
/// (lib/src/plugins/tdd/commands/make_command.dart) must print this text
/// VERBATIM — the tdd suites pin their copy word-for-word. Living in one
/// place is what keeps the two surfaces from drifting when a hint's flag
/// or wording changes.
void printIdGateDiagnostic(
  String entityName, {
  List<String> extraLines = const [],
}) {
  print(
    '❌ Cannot generate architecture for "$entityName": the entity '
    'has no id field.',
  );
  print('');
  print('Entities need a real identity. Choose one of:');
  print(
    '  1. Add an id field:    zfa entity add-field -n '
    '$entityName --field id:String',
  );
  print(
    '  2. Auto-generate one:  recreate with '
    'zfa entity create -n $entityName --auto-id <fields...>',
  );
  print(
    '  3. Mark it as a value object if it is an immutable '
    'composition type (no identity, no CRUD surface):',
  );
  print(
    '       zfa entity create -n $entityName --kind=value_object '
    '<fields...>',
  );
  print(
    '     or add @ZValueObject / kind: ZorphyKind.valueObject '
    'to its annotation.',
  );
  for (final line in extraLines) {
    print(line);
  }
}
