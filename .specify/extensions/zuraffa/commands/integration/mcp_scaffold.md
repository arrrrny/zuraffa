---
name: "speckit.zuraffa.mcp.scaffold"
description: "Scaffold a runtime MCP server (lib/src/mcp/tools.dart + bin/mcp_server.dart) so the app can expose its features as MCP tools callable by AI agents."
category: "integration"
---

# Mcp Scaffold: Scaffold a runtime MCP server (lib/src/mcp/tools.dart + bin/mcp_server.dart) so the app can expose its features as MCP tools callable by AI agents.

## Usage

```bash
zfa mcp scaffold
```

## When to Use

Scaffold a runtime MCP server (lib/src/mcp/tools.dart + bin/mcp_server.dart) so the app can expose its features as MCP tools callable by AI agents.

## Required Parameters

- None.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | No | - | Optional name for the MCP server (defaults to the package name from pubspec.yaml). |
| `--force` | bool | No | False | Overwrite existing files |
| `--dryRun` | bool | No | False | Preview without writing files |
| `--verbose` | bool | No | False | Enable detailed logging |
| `--revert` | bool | No | False | Delete the scaffolded files |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
