# Migration Guide to Zuraffa v3

This guide helps Zuraffa v2 users migrate their projects to v3. The major changes in v3 are the **Modular Plugin System**, the new `zfa feature` and `zfa make` commands, and the built-in **MCP Server** for AI-native development.

---

## 🦄 Quick Checklist

- Update `zuraffa` dependency to `^3.19.0`.
- Update the global CLI: `dart pub global activate zuraffa`.
- Switch from `zfa generate` to `zfa feature` or `zfa make`.
- Enable the **MCP Server** for your AI IDE (Trae, Cursor, etc.).
- Review the new **VPC (View-Presenter-Controller)** patterns.

---

## 1) CLI Command Changes (Breaking)

The `zfa generate` command is now deprecated in favor of a more modular approach.

### Feature Generation
Use `zfa feature` to generate a complete architectural slice (Domain, Data, Presentation).

**Before (v2):**
```bash
zfa generate Product --methods=get,getList,create --data --vpcs --di --test
```

**After (v3):**
```bash
zfa feature Product --methods=get,getList,create --data --vpcs --di --test
```

### Granular Plugin Generation
Use `zfa make` to run specific plugins. The key advantage is that you can now combine multiple plugins in one command.

**Before (v2):**
```bash
zfa generate Search --domain=search --params=SearchRequest --returns=Listing
```

**After (v3):**
```bash
zfa make Search usecase data di --domain=search --params=SearchRequest --returns=Listing
```

---

## 2) Smart Revert

v3 introduces an AST-aware revert system. If you accidentally generate code, you can now undo it safely without losing your manual changes in the same files.

```bash
zfa make Product usecase --methods=watch --revert
```

---

## 3) AI-First Development (MCP)

Zuraffa v3 is designed to be built by AI agents. By enabling the built-in MCP server, your AI agent can now:
- Understand your project's Clean Architecture structure.
- Generate features and entities with 100% precision.
- Run diagnostics and fix architectural violations.

To set up, see the [MCP Server Guide](https://arrrrny.github.io/zuraffa/doc/features/mcp-server).

---

## 4) Presentation Layer: VPC Pattern

The presentation layer has been refined into the **VPC (View-Presenter-Controller)** pattern. 
- **View**: Pure UI.
- **Presenter**: Logic orchestration and UseCase injection.
- **Controller**: Interaction handling and state management.

If you are migrating existing UI, use the `--pcs` flag to update the logic layer while preserving your custom View code:

```bash
zfa feature Product --methods=newMethod --pcs --force
```

---

## 5) Dependency Updates

Update your `pubspec.yaml` to the latest versions:

```yaml
dependencies:
  zuraffa: ^3.19.0

dev_dependencies:
  zuraffa: ^3.19.0
  zorphy_annotation: ^1.6.0
```

---

## 📂 Need Help?

- Check the [New Documentation](https://arrrrny.github.io/zuraffa/).
- Join the community or open an issue on [GitHub](https://github.com/arrrrny/zuraffa).

Made with 🦒 and ⚡️ by [Arrrrny](https://github.com/arrrrny).
