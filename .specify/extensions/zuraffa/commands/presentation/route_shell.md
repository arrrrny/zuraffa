---
name: "speckit.zuraffa.route.shell"
description: "Generate a StatefulShellRoute.indexedStack shell with one branch per --branch <Label>:<path>, plus an optional bottom navigation bar (Material 3 NavigationBar) or desktop NavigationRail (--adaptive). Registers the shell in getAllRoutes()."
category: "presentation"
---

# Route Shell: Generate a StatefulShellRoute.indexedStack shell with one branch per --branch <Label>:<path>, plus an optional bottom navigation bar (Material 3 NavigationBar) or desktop NavigationRail (--adaptive). Registers the shell in getAllRoutes().

## Usage

```bash
zfa route shell
```

## When to Use

Generate a StatefulShellRoute.indexedStack shell with one branch per --branch <Label>:<path>, plus an optional bottom navigation bar (Material 3 NavigationBar) or desktop NavigationRail (--adaptive). Registers the shell in getAllRoutes().

## Required Parameters

- **name**: PascalCase shell name (e.g. Main, App).
- **branch**: One entry per bottom-nav tab, formatted as "<Label>:<path>" (e.g. "Home:/home"). An optional third colon-separated segment specifies the Material icon (e.g. "Home:/home:Icons.home"). Repeat the flag once per branch: --branch Home:/home --branch Deals:/deal.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | PascalCase shell name (e.g. Main, App). |
| `--branch` | list | Yes | - | One entry per bottom-nav tab, formatted as "<Label>:<path>" (e.g. "Home:/home"). An optional third colon-separated segment specifies the Material icon (e.g. "Home:/home:Icons.home"). Repeat the flag once per branch: --branch Home:/home --branch Deals:/deal. |
| `--bottomNav` | bool | No | True | Emit a Material 3 NavigationBar bound to navigationShell.currentIndex + goBranch (default: true). |
| `--adaptive` | bool | No | False | Also emit a <Name>ShellDesktop variant with a NavigationRail for wide layouts; the shell builder picks between them via LayoutBuilder. |
| `--dry-run` | bool | No | False |  |
| `--force` | bool | No | False |  |
| `--verbose` | bool | No | False |  |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
