/// The CRUD verbs whose generated datasource surface needs the entity's
/// `<Type>Patch` companion, `<Type>Fields` registry (`copyWith`), and
/// identity field.
///
/// `list` is deliberately absent: it is surface-free (`list(NoParams)`), so
/// a request for `list` alone must NOT trip the #1747 guard and close the
/// `--methods` arm (issue #1898).
///
/// This is the single source for that classification. A new CRUD verb added
/// to the generator vocabulary but not here would be classified as non-CRUD
/// and silently reopen the broken-surface path.
const Set<String> crudSurfaceMethodVocabulary = <String>{
  'get',
  'getList',
  'create',
  'update',
  'delete',
  'toggle',
  'watch',
  'watchList',
};

/// Standard CRUD verbs whose datasource signatures reference the entity
/// type. `list` belongs here — its return type is `List<Entity>` — even
/// though it needs no entity CRUD surface. `delete` is deliberately
/// absent: its signature is `Future<void> delete(DeleteParams<id>)` and
/// references only the id type, never the entity, so requiring an entity
/// reference there is a false positive (issue #1898 / zuraffa datasource
/// verify).
const Set<String> entityTypedMethodVocabulary = <String>{
  'get',
  'getList',
  'list',
  'create',
  'update',
  'toggle',
  'watch',
  'watchList',
};

/// The "any field" descriptor a toggle carries for entity [entityName]:
/// `ZorphyField<E, Object?>` — the write-capable v3 field descriptor with
/// its value type erased.
///
/// The erase is the contract, not a convenience. A `ZorphyField<E, V>` is
/// invariant in `V` (its `set` is a function-typed field), so the typed
/// registry entries (`<E>Fields.id`) can only travel through an `Object?`
/// slot once erased (`<E>Fields.id.asObject` — zorphy#301). The old
/// `Field<E, dynamic>` was a query-only descriptor with no `set` at all,
/// which is why v2 toggles routed through the since-removed `copyWithField`.
String toggleFieldType(String entityName) =>
    'ZorphyField<$entityName, Object?>';

/// The full params type of a toggle for entity [entityName] with id type
/// [idFieldType]: what every generated signature — datasource interface and
/// implementation, repository, usecase, provider, presenter, service —
/// must agree on.
String toggleParamsType(String entityName, String idFieldType) =>
    'ToggleParams<$idFieldType, ${toggleFieldType(entityName)}>';

/// The expression a generated datasource body writes a toggle through:
/// `params.field.set(existing, params.value)` — the field descriptor IS the
/// write path in v3.
const String toggleWriteExpression = 'params.field.set(existing, params.value)';
