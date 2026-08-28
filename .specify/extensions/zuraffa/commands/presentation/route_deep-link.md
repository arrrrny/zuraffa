---
name: "speckit.zuraffa.route.deep-link"
description: "Generate a deep-link GoRoute module and register the URL scheme in AndroidManifest.xml + Info.plist (idempotent)"
category: "presentation"
---

# Route Deep-Link: Generate a deep-link GoRoute module and register the URL scheme in AndroidManifest.xml + Info.plist (idempotent)

## Usage

```bash
zfa route deep-link
```

## When to Use

Generate a deep-link GoRoute module and register the URL scheme in AndroidManifest.xml + Info.plist (idempotent)

## Required Parameters

- **name**: PascalCase route name (e.g. ScanBarcode)
- **path**: URL path pattern (e.g. /scan/barcode/:barcode)
- **scheme**: URL scheme (e.g. gozuzu, https)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | PascalCase route name (e.g. ScanBarcode) |
| `--path` | string | Yes | - | URL path pattern (e.g. /scan/barcode/:barcode) |
| `--scheme` | string | Yes | - | URL scheme (e.g. gozuzu, https) |
| `--host` | string | No | - | Optional host (e.g. go.zuzu.dev) for App Links |
| `--autoVerify` | bool | No | False | Emit android:autoVerify="true" (App Links) |
| `--view` | string | No | - | Optional view class to render (default: SizedBox.shrink placeholder) |
| `--dryRun` | bool | No | False |  |
| `--force` | bool | No | False |  |
| `--verbose` | bool | No | False |  |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
