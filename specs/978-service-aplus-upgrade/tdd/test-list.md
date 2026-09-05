# Test List: 978-service-aplus-upgrade

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | a service generation request that cannot resolve a service name never yields a silent empty success: the skip reason is logged with a `--> fix:` line, and the CLI layer exits non-zero (zero-file guard, #769 family). | AC-1 | DONE |
| A2 | schema ≡ grammar: `params`/`returns`/`type`/`init` exist in `configSchema`, in the `create` capability inputSchema (so `--init` parses), and on the service command grammar — both directions asserted. | AC-2 | DONE |
| A3 | `zfa make <Entity> --service` end-to-end: service interface + DI wiring + provider files land in a temp project with correct content and a proof receipt covering them. | AC-3 | DONE |
| A4 | `zfa service method` on an existing service preserves hand-written members and appends the new method correctly (action `updated`). | AC-4 (append half) | DONE |
| A5 | `zfa service create` in `--json` machine mode prints a single verdict object `{schema:1, ok, file, methods[], type}` on success and a `--> fix:` line (plus non-zero exit) on error paths. | AC-4 (json half) | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `ServicePlugin.generate` with no resolvable service name prints `Skipping service generation` + `--> fix:` and returns an empty list. | A1 | DONE |
| U2 | `ServicePlugin.generateWithContext` with no `service` in context data prints the same structured skip. | A1 | DONE |
| U3 | `ServicePlugin.configSchema.properties` ⊇ {params, returns, type, init} (and keeps `service`). | A2 | DONE |
| U4 | the `create` capability's `inputSchema` declares `init` and `type` with the CLI's allowed enum. | A2 | DONE |
| U5 | every plugin-specific flag of `ServiceCommand` (params/returns/type/init) is declared in `configSchema`; every non-positional `configSchema` property other than `service` round-trips as a `ServiceCommand`/create-subcommand flag. | A2 | DONE |
| U6 | make run output: `domain/services/<x>_service.dart` contains the abstract interface; `di/services/<x>_service_di.dart` contains the registration; `data/providers/**/<x>_provider.dart` implements the service; ReceiptStore holds a proof.v1 receipt whose digest matches the service file. | A3 | DONE |
| U7 | method append: existing hand-written method + doc comment survive; new method signature lands; host file action is `updated`; no `import augment`. | A4 | DONE |
| U8 | `--json '{"name":...}'` on service create prints exactly one JSON object; decoded envelope has schema==1, ok==true, file endswith `<snake>_service.dart`, methods == expected member names, type == requested. | A5 | DONE |
| U9 | `--json` machine mode with missing required name → verdict with ok==false + `fix` hint, `--> fix:` line printed, exit code 64. | A5 | DONE |
| U10 | prose mode (no `--json`) unchanged: `✅ Success! Created/Modified:` framing still prints (regression guard for the verdict hook). | A5 | DONE |
