// entity_id_type.dart
//
// Resolves the ACTUAL type of an entity's identity for standalone
// generator commands (`zfa view create`, `zfa route create`).
//
// Background (issue #336): `zfa view create` hardcoded the route id
// param as `String?` while `zfa make` types the presenter/controller
// accessor after the entity's real id field (e.g. `int`). Regenerating a
// view for an int-id entity then produced
// `controller.getX(widget.id!)` where `widget.id` is `String?` but the
// accessor takes `int` → argument_type_not_assignable.
//
// Resolution order:
//   1. Probe the entity source file via [EntityFieldResolver] (a field
//      named `id`, else the first field ending in `Id`, else the
//      synthetic `id: String` promised by `autoId: true`).
//   2. Fall back to the persisted args of the last `zfa make` run
//      (`.zfa/plans/last_run_<Entity>.json`). This covers entities
//      whose identity was declared explicitly at make time via
//      `--id-field`/`--id-field-type` and that have no id-like field on
//      the entity itself (e.g. CustomerProfile → yearOfBirth:int).
//
// Returns null when neither source yields a type; callers keep their
// existing default (`String`).

import '../core/plugin_system/plan_store.dart';
import '../core/project/project_root.dart';
import 'entity_field_resolver.dart';

/// Resolves the entity's actual id type for standalone view/route
/// generation, or null when it cannot be determined.
Future<String?> resolveEntityIdFieldType({
  required String entityName,
  String? projectRoot,
}) async {
  final root = projectRoot ?? ProjectRoot.find();

  // 1. Probe the entity source file.
  final resolution = EntityFieldResolver.resolveIdField(
    entityName: entityName,
    projectRoot: root,
  );
  if (resolution?.idField != null) {
    return resolution!.idField!.nonNullableType;
  }

  // 2. Fall back to the last `zfa make` plan's persisted id args.
  final report = await PlanStore.instance.loadPlan(
    'last_run_$entityName',
    baseDir: root,
  );
  final args = report?.args;
  if (args is Map<String, dynamic>) {
    final type = args['id-field-type'];
    if (type is String && type.isNotEmpty) {
      return type;
    }
  }
  return null;
}
