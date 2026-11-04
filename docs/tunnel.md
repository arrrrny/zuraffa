# ZFA Tunnel — wrap a Zuraffa app for remote access via Cloudflare

`zfa tunnel` raises a Cloudflare tunnel around **one explicitly declared local
port** and prints the public URL. It is the remote-access half of the
web-based MCP composition: put a `zuraffa_mcp` HTTP endpoint behind it and the
app's MCP surface is reachable from a browser or an AI agent over HTTPS
(issue #2045, spec `specs/1724-zuraffa-tunnel`).

The plugin is `zuraffa_tunnel` (a runtime plugin — no codegen) and the
command ships in two subcommands:

```sh
zfa tunnel run --port <1-65535> [--mode quick|named|token] [flags] [-- <app start command…>]
zfa tunnel status
```

## Modes

### Quick mode (default — zero config, ephemeral URL)

No Cloudflare account, no configuration. `cloudflared` is spawned as
`cloudflared tunnel --url http://localhost:<port> --no-autoupdate` and the
ephemeral `https://<something>.trycloudflare.com` URL is parsed from its
output, printed, and persisted.

```sh
# Attach to something already listening on 8080
zfa tunnel run --port 8080

# Or wrap the app start itself — one command from local to public
zfa tunnel run --port 8080 -- dart run bin/mcp_server.dart --http --port 8080
```

Quick-tunnel URLs **change on every restart** — they are for "make it
reachable NOW", not for anything durable.

### Named mode (user-defined DNS — persistent hostname)

You supply the tunnel name, the credentials file (`cloudflared tunnel login`
+ `cloudflared tunnel create <name>` produce it) and the public hostname:

```sh
zfa tunnel run --port 8080 --mode named \
  --tunnel-name dws-playground \
  --hostname dws.example.com \
  --credentials-file ~/.cloudflared/<tunnel-id>.json
```

The wrapper spawns `cloudflared tunnel run --url http://localhost:<port>
--credentials-file <file> <name>` and resolves once the edge registration
line appears. The hostname survives restarts (FR-002 / SC-004). The one-time
DNS route is `<name>.<your-domain>` bound with
`cloudflared tunnel route dns <name> <hostname>`.

### Token mode (remotely-managed named tunnel)

For tunnels managed in the Cloudflare Zero Trust dashboard (ingress lives
remotely), pass the dashboard-issued tunnel token:

```sh
zfa tunnel run --port 8080 --mode token --token <cloudflare-tunnel-token>
```

The wrapper spawns `cloudflared tunnel run --token <token>`. **The token is
never printed or logged** — every output line is redacted (SC-005), and the
credentials-file path is redacted the same way in named mode.

**Scope caveat (token mode):** the public route comes from the Cloudflare
dashboard ingress, which the CLI cannot verify locally — the FR-004 probe
covers only the declared local origin (`--port`). Choosing token mode is the
explicit acceptance that the dashboard ingress must point at that same
declared origin (FR-009: exactly one local port). The success output prints
this warning every time.

## Security

- **Unauthenticated-endpoint guard (FR-004):** before exposing anything, the
  wrapper probes `http://localhost:<port>`. An endpoint that answers
  **401/403** is treated as authenticated and tunneled. Anything else (200,
  404, …) is refused:

  ```
  ❌ http://localhost:8080 answered without an authentication challenge —
  tunneling it would publish an open service to the internet.
  --> fix: enable auth on the app (e.g. `zfa mcp serve --token <t>`), or
  pass --i-know-its-unauthenticated if you accept the risk.
  ```

  The override flag is explicit and per-invocation on purpose: local
  services are local for a reason.

- **Scope (FR-009):** the tunnel always forwards exactly the declared port
  on the loopback host. There is no implicit default port and no wildcard /
  whole-host mode.

- **Cloudflare Access (recommended for named/token modes):** put the tunnel
  behind a Zero Trust policy so only your identities can reach it:
  1. Zero Trust → Access → Applications → *Add an application* → **Self-hosted**.
  2. Application domain = the tunnel's public hostname (e.g. `dws.example.com`).
  3. Add a policy (e.g. *Allow* → *Emails* → your address; or *Service Auth*
     with a service token for machine callers).
  4. Save — requests to the hostname now require Access authentication before
     they ever reach your app.

  Quick tunnels cannot carry an Access policy (they are anonymous by
  design) — treat every quick URL as public and rely on the app's own auth
  (the guard makes that decision explicit).

- **Secrets (FR-003):** tokens and credentials-file paths are redacted from
  every output line before they reach a log, a terminal, or the persisted
  state.

## Lifecycle: kill, restart, resurface

The wrapper is the **single owner** of both lifetimes (FR-008):

- Wrapped app exits → the tunnel is shut down and the wrapper exits 0.
- You interrupt the wrapper (ctrl-c / SIGTERM) → the tunnel process is
  stopped, the wrapped app is killed, exit 0.
- The tunnel process dies on its own (crash, kill) → the wrapper **restarts
  it with capped exponential backoff** (0.5s, 1s, 2s, 4s, 8s — 5 attempts),
  re-derives the public URL (quick mode: the URL changes; named mode: the
  hostname does not), and updates the persisted state (FR-006 / SC-002).
  Backoff exhausted → the wrapper fails with the reason recorded.

State lives at `.zfa/tunnel/state.json` (mode, port, url, pid, restarts,
started-at, failure reason, running). Anything after the fact — a new
terminal, a teammate, a script — reads it back:

```sh
zfa tunnel status
# mode: quick
# port: 8080
# running: true
# restarts: 1
# started at: 2026-11-04T10:00:00.000Z
# url: https://fresh-words-here.trycloudflare.com
# reachability: reachable
```

## Install

The wrapper locates `cloudflared` on `PATH`, then `/usr/local/bin` and
`/opt/homebrew/bin`. It never downloads a binary behind your back; when
nothing is found it prints:

```
--> fix: install cloudflared — `brew install cloudflare/cloudflare/cloudflared`
(macOS), or download the binary from
https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
and put it on PATH.
```

## First users of the composition

`dws_playground` and `dart_scraper_sandbox` are currently local-only MCPs;
wrapping their HTTP endpoints with `zfa tunnel run --port <n>` (quick mode
for a demo, named mode + Access for anything durable) makes them web-based
MCPs — the same architecture the zuraffa browser web-MCP uses, generalized
to the whole fleet.
