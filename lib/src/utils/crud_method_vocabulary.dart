/// The CRUD verbs whose generated datasource surface needs the entity's
/// `<Type>Patch` companion, `copyWithField`, and identity field.
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
/// though it needs no entity CRUD surface.
const Set<String> entityTypedMethodVocabulary = <String>{
  ...crudSurfaceMethodVocabulary,
  'list',
};
