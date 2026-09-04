# Quickstart: Slice-Driven Isolation (073)

Develop a feature in a runnable sandbox — never boot the whole app.

```bash
# 1. Cut the feature into a runnable sandbox
zfa slice cut --feature login --from ~/Developer/zik_zak
# sandbox: app shell + router harness + mock DI + spec/tdd artifacts

# 2. Drive the FULL tdd loop inside the sandbox
cd <slice-root>
zfa tdd run login                 # loop writes journal/registry in the sandbox

# 3. Certify the slice is self-contained
zfa slice verify --json           # exit 0 = self-containment + mocks + suite

# 4. Land it back
zfa slice merge --into ~/Developer/zik_zak
# host suite green after landing
```

## Refusals you may see

- `slice cut`: host missing/not a zfa project (exit 2), feature spec
  absent (exit 3), duplicate routes (exit 4).
- `slice verify`: offenders named per check (exit 1).
- `slice merge`: unverified slice (exit 2), conflicts without --force
  (exit 3).
