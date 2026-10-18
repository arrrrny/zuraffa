# Skin Plan: 004-login-ui (SKIN + BOTH)

The skin lane (issue #1000): Flutter allowed — behaviors whose lane is SKIN or BOTH, plus the AdaptiveViewSlots the spec declares (the adaptive-layout contract slots the skin must provide).

## Adaptive view slots

| slot |
| ---- |
| mobile |
| ios |
| android |
| macos |

## Platform contract

The adaptive-layout platform matrix (issue #1004): every SKIN behavior renders the declared slots on every adaptive platform; platform overrides refine the contract per platform.

| platform | contract | behaviors | source |
| -------- | -------- | --------- | ------ |
| mobile | renders the adaptive slots | W1 | adaptive_slots |
| ios | renders the adaptive slots; home_indicator_safe_area: required | W1 | adaptive_slots, platform_overrides.ios |
| android | renders the adaptive slots | W1 | adaptive_slots |
| macos | renders the adaptive slots; title_bar_alignment: trailing | W1 | adaptive_slots, platform_overrides.macos |

## State machine contract

The declared state machine (issue #1004): the happy path runs the declared states in order — states: initial -> loading -> data (alternate states: error, empty).

| state | transition | source |
| ----- | ---------- | ------ |
| initial | initial -> loading | states |
| loading | loading -> data | states |
| data | terminal | states |
| error | alternate | states |
| empty | alternate | states |

## Route contract

The declared routes (issue #1004): navigation target, screen class, and route path for every route the skin can navigate to.

| navigation target | screen class | route path | source |
| ----------------- | ------------ | ---------- | ------ |
| login | LoginScreen | /login | routes |
| deal_list | DealListScreen | /deal_list | routes |
| settings | SettingsScreen | /settings | routes |

## Skin contract (machine)

The typed contract (issue #1004): machine-parseable JSON generated from the typed model — schema-validated, never prose.

```json
{
  "schemaVersion": "1",
  "adaptiveSlots": [
    "mobile",
    "ios",
    "android",
    "macos"
  ],
  "platformOverrides": {
    "ios": {
      "home_indicator_safe_area": "required"
    },
    "macos": {
      "title_bar_alignment": "trailing"
    }
  },
  "states": [
    "initial",
    "loading",
    "data",
    "error",
    "empty"
  ],
  "routes": [
    {
      "target": "login",
      "screenClass": "LoginScreen",
      "path": "/login"
    },
    {
      "target": "deal_list",
      "screenClass": "DealListScreen",
      "path": "/deal_list"
    },
    {
      "target": "settings",
      "screenClass": "SettingsScreen",
      "path": "/settings"
    }
  ]
}
```

## Outer loop: widget behaviors

Skin behaviors (bug #830 / issue #1000): asserted through a testWidgets pair — includes the hand-declared lane rows (the `W` ids the `## Lanes` section reserves).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W1 | skin behavior declared in `## Lanes` | LANE:SKIN | PENDING |


