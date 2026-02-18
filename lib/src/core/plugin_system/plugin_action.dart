enum PluginAction {
  create, // Scaffolds new files (default if not exists)
  delete, // Removes files and cleans up references
  add,    // Appends methods/fields to existing files (default if exists)
  remove, // Removes specific methods/fields from existing files
}
