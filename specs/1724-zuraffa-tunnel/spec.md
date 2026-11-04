# Feature Specification: zuraffa tunnel — wrap Zuraffa apps for remote access via Cloudflare tunnel

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1724-zuraffa-tunnel`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "zuraffa_tunnel: wrap Zuraffa apps for remote access via Cloudflare tunnel — auto-generated trycloudflare DNS or user-defined named tunnel; composes with zuraffa_mcp for web-based MCP (issue arrrrny/zuraffa#2045)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Zero-config quick tunnel around a running app (Priority: P1)

A developer has a Zuraffa app (or any local HTTP surface, e.g. a `zuraffa_mcp`
Streamable HTTP endpoint) listening on a local port and wants a colleague or an
AI agent to reach it over the internet right now, without creating a Cloudflare
account or a tunnel configuration. They invoke the tunnel command against the
declared port; the tool raises an ephemeral public HTTPS URL, prints it, and
keeps it alive until interrupted.

**Why this priority**: this is the "make it reachable NOW" slice the issue's
first acceptance bullet names (`dws_playground`, `dart_scraper_sandbox` are
currently local-only); every other story builds on the same lifecycle.

**Independent Test**: can be fully tested by starting a local HTTP server,
invoking the tunnel command in quick mode, and delivering a public HTTPS URL
that reaches that server — without any credentials or configuration.

**Acceptance Scenarios**:

1. **Given** a local HTTP surface listening on a declared port, **When** the operator runs the tunnel command in quick mode, **Then** a public `trycloudflare.com` HTTPS URL is printed and recorded, and requests through that URL reach the local surface.
   **Type**: acceptance
2. **Given** the quick-tunnel command is running, **When** the operator interrupts it, **Then** the tunnel process is shut down cleanly and nothing keeps running in the background.
   **Type**: acceptance

---

### User Story 2 - Unauthenticated-endpoint guard (Priority: P1)

Local services are local for a reason. Before exposing a port to the internet,
the tool probes the local endpoint; an endpoint that does not answer with an
authentication challenge is refused with explicit guidance unless the operator
passes an explicit override flag, so nobody publishes an open service by
accident.

**Why this priority**: the issue marks the security posture "must-haves, not
nice-to-haves"; shipping the tunnel without the guard would publish open
endpoints.

**Independent Test**: can be fully tested by pointing the tunnel command at an
endpoint that answers 200 (no challenge) and observing the refusal, then
re-running with the override flag and observing the tunnel proceed.

**Acceptance Scenarios**:

1. **Given** a local endpoint that answers a probe with a success (non-challenge) response, **When** the operator runs the tunnel command without the override flag, **Then** the command refuses with a clear message naming the override flag and starts nothing.
   **Type**: acceptance
2. **Given** the same endpoint, **When** the operator passes the explicit override flag, **Then** the tunnel proceeds.
   **Type**: acceptance
3. **Given** a local endpoint that answers a probe with an authentication challenge (401/403), **When** the operator runs the tunnel command, **Then** no override is needed and the tunnel proceeds.
   **Type**: acceptance

---

### User Story 3 - Survive tunnel-process death (Priority: P2)

The tunnel process can die (crash, network blip, kill). The operator should not
have to babysit it: the wrapper notices the death, restarts the process with
backoff, re-derives the public URL (quick-tunnel URLs change on every restart),
updates the recorded state, and the next request through the fresh URL
succeeds.

**Why this priority**: the issue's acceptance names "Kill cloudflared → the
wrapper restarts it and re-registers; the next request succeeds" as its own
criterion.

**Independent Test**: can be fully tested by starting the tunnel, killing the
underlying tunnel process out from under the wrapper, and observing the
restart, the re-registered (possibly new) URL, and a succeeding next request.

**Acceptance Scenarios**:

1. **Given** a running quick tunnel, **When** the tunnel process is killed, **Then** the wrapper restarts it with backoff, re-derives the public URL, and updates the persisted state.
   **Type**: acceptance
2. **Given** the wrapper restarted the tunnel process, **When** a request arrives through the re-derived URL, **Then** it succeeds.
   **Type**: acceptance

---

### User Story 4 - Named tunnel with a user-defined DNS hostname (Priority: P2)

Anything durable needs a hostname that survives restarts. An operator with a
Cloudflare account supplies tunnel credentials and a DNS hostname; the tool
runs a named tunnel that keeps the same public hostname across restarts. A
remotely-managed variant accepts a Cloudflare-issued tunnel token instead of a
local config. Credentials and tokens are never printed or logged.

**Why this priority**: the issue asks for "auto-generated or user-defined DNS"
— the named modes are the durable half; the quick mode already delivers the
ephemeral half.

**Independent Test**: can be fully tested by running the tunnel in named mode
with supplied credentials/hostname and observing the declared hostname being
served and re-served identically after a restart.

**Acceptance Scenarios**:

1. **Given** user-supplied tunnel name, credentials file and DNS hostname, **When** the tunnel runs in named mode, **Then** the declared public hostname is served by the tunnel.
   **Type**: acceptance
2. **Given** a named tunnel that restarted, **When** the operator checks the public hostname, **Then** it is unchanged from before the restart.
   **Type**: acceptance
3. **Given** a Cloudflare-issued tunnel token, **When** the tunnel runs in token mode, **Then** the tunnel runs without a local config file and the token never appears in output or logs.
   **Type**: acceptance

---

### User Story 5 - Wrap an app end-to-end (Priority: P3)

The composition goal: point the tunnel command at an app start command (e.g. a
`zuraffa_mcp` HTTP server). The wrapper starts the app, waits for the declared
port to accept connections, then raises the tunnel — one command takes a local
surface to a public URL — and brings both down together on interrupt.

**Why this priority**: the wrapper works fine attached to an already-running
app (US1); wrapping the app process itself is the ergonomic whole that makes
the composition one command.

**Independent Test**: can be fully tested by passing an app start command that
listens on the declared port and observing: app starts, tunnel is raised after
the port opens, and both shut down together on interrupt.

**Acceptance Scenarios**:

1. **Given** an app start command that listens on the declared port, **When** the tunnel command wraps it, **Then** the app is started, the port is awaited, and the tunnel is raised once the port accepts connections.
   **Type**: acceptance
2. **Given** a wrapped app and tunnel, **When** the operator interrupts the wrapper, **Then** both the tunnel process and the app process are shut down.
   **Type**: acceptance

### Edge Cases

- What happens when the cloudflared binary is absent? The command reports a clear remediation (how to install it) instead of a stack trace.
- What happens when the declared local port has nothing listening? The command reports the dead endpoint and starts nothing (in wrap mode it awaits the port for a bounded window first).
- What happens when the declared port is missing from the invocation? The command refuses — no implicit default port exists (scope is always explicit).
- What happens when quick mode's URL changes after a restart? The persisted state records the new URL; the old URL is superseded (named mode is documented for anything durable).
- What happens when restart backoff exhausts? The wrapper gives up with a clear failure and records the failure in state rather than spinning forever.
- What happens when the token/credentials would appear in output? They are redacted everywhere (arguments, logs, printed lines).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `tunnel` command that raises a Cloudflare quick tunnel around an explicitly declared local port and prints the public URL once derived.
            traces: TunnelSupervisor, TunnelUrlParser, CloudflaredLocator
- **FR-002**: System MUST support a named-tunnel mode driven by an operator-supplied tunnel name, credentials file and DNS hostname, serving the declared hostname across restarts.
            traces: TunnelSupervisor
- **FR-003**: System MUST support a token mode that runs a remotely-managed named tunnel from a Cloudflare-issued token, and MUST never print or log the token or credential paths.
            traces: TunnelSupervisor, TunnelSecrets
- **FR-004**: System MUST probe the declared local endpoint before exposing it and MUST refuse an endpoint that does not answer with an authentication challenge unless the operator passes the explicit `--i-know-its-unauthenticated` flag.
            traces: EndpointAuthProbe, TunnelSupervisor
- **FR-005**: System MUST locate the cloudflared binary (PATH first, then common install locations) and MUST report install remediation when it is absent.
            traces: CloudflaredLocator
- **FR-006**: System MUST restart an unexpectedly-dead tunnel process with capped exponential backoff, re-derive the public URL, and update persisted state; on backoff exhaustion it MUST fail with a clear reason.
            traces: TunnelSupervisor, TunnelState
- **FR-007**: System MUST persist tunnel state (mode, ports, url, pid, restart count, timestamps, failure reason) under the project's `.zfa/` memory so any later invocation can resurface the current URL.
            traces: TunnelState
- **FR-008**: System MUST shut the tunnel process down cleanly when the wrapped app exits or the operator interrupts, and MUST shut the wrapped app down when the wrapper itself is interrupted (one owner owns both lifetimes).
            traces: TunnelSupervisor
- **FR-009**: System MUST tunnel only the explicitly declared local port(s) — never a wildcard or whole-host scope — and MUST require the port to be stated.
            traces: TunnelConfig
- **FR-010**: System MUST support both attaching to an already-running app and wrapping an app start command (awaiting the declared port within a bounded window before raising the tunnel).
            traces: TunnelSupervisor
- **FR-011**: System MUST detect tunnel liveness and report current URL/status on demand (status subcommand reading persisted state plus a live check).
            traces: TunnelState, TunnelSupervisor
- **FR-012**: Documentation MUST cover both tunnel modes, the Cloudflare Access (Zero Trust) recipe for named tunnels, and the kill/restart semantics.

## Layer Contracts

**Function**:
- `TunnelSupervisor`: `start(TunnelConfig) -> TunnelHandle`
- `TunnelSupervisor`: `stop(TunnelHandle) -> Future<void>`
- `TunnelSupervisor`: `status(TunnelHandle) -> TunnelStatus`
- `TunnelUrlParser`: `parse(String line) -> Uri?`
- `CloudflaredLocator`: `locate() -> CloudflaredInfo?`
- `EndpointAuthProbe`: `isAuthenticated(Uri target, HttpClient client) -> Future<bool>`
- `TunnelState`: `save(TunnelStateRecord) -> Future<void>`
- `TunnelState`: `read() -> TunnelStateRecord?`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| TunnelConfig | `mode: TunnelMode`, `port: int`, `host: String`, `tunnelName: String?`, `hostname: String?`, `credentialsFile: String?`, `token: String?`, `allowUnauthenticated: bool` | The declared, single-port tunnel the operator asked for |
| TunnelStateRecord | `mode: String`, `port: int`, `url: String?`, `pid: int?`, `restarts: int`, `startedAt: DateTime`, `lastRestartAt: DateTime?`, `failureReason: String?` | What a later invocation resurfaces about the tunnel |
| CloudflaredInfo | `path: String`, `version: String?` | The located binary and its version |

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1-A14]
    flutter_allowed: false
```

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Wrapping an already-running local HTTP surface in quick mode produces a reachable public HTTPS URL with zero configuration and no credentials.
- **SC-002**: After the tunnel process is killed, the wrapper re-registers the tunnel and the next request through the re-derived URL succeeds without operator intervention.
- **SC-003**: An unauthenticated endpoint is refused with guidance every time, and proceeds only under the explicit override flag.
- **SC-004**: A named tunnel serves the same public hostname after every restart.
- **SC-005**: No token, credential, or credential-file content appears anywhere in the command's output.

## Assumptions

- The `cloudflared` binary is the tunnel engine; the tool locates it on PATH (or common install locations) and never bundles or pins a copy — install remediation is documentation, not auto-download (network installs behind an operator's back are out of scope).
- Quick-tunnel URLs are ephemeral by Cloudflare's design; durability is the named/token modes' job, and the docs say so.
- The default scope is exactly the declared port forwarded to the loopback host — the tool never forwards a wildcard or a non-loopback bind.
- Endpoint authentication is judged by the probe response (401/403 counts as challenged); apps with authz schemes invisible to a single probe can be force-marked by the override flag by an operator who understands the risk.
- In token mode the public route comes from the Cloudflare dashboard ingress, which the CLI cannot verify locally. FR-004's probe and FR-009's single-port scope are therefore enforced on the declared local origin only; choosing token mode (FR-003) is the operator's explicit acceptance that the dashboard ingress must point at that same declared origin — the success output carries this caveat.
- Backoff caps (and the health-window sizes) are bounded constants, not configurable, in v1.
- The tunnel command is a long-running foreground process (like `zfa mcp serve`); daemonizing is out of scope.
