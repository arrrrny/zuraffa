# Data Model: Zuraffa Branding for Generated Apps

This feature does not define persistent data entities. It is a pure asset-copying and configuration-update workflow.

## Branding Entities

There are no application-level entities managed by this feature. The "entities" referenced in the spec are:

- **BrandAsset** — a file on disk (source: `assets/zuraffa_app_icons/`), not a code object
- **GeneratedApp** — an existing project directory created by `flutter create` or `dart create`, not managed by this feature
- **BrandConfig** — a simple configuration class holding the asset source path and optional flags

No state machines, no persistence, no relationships between entities.
