# Contract: Generated Dependency Mock Surface

For a declared row `FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1`:

## Interface (exactly the declared members)

```dart
abstract class FirebaseAuth {
  Future<User> signIn({required String email, required String password});
  Future<void> signOut();
}
```

- Method names, parameter names/order, and return types come from the
  declared signatures verbatim. Async shaping follows the existing mock
  datasource convention (Future-wrapped returns) so the fake is
  awaitable uniformly.
- No invented members, no missing members, no renames (data-model I1).

## Certified fake (scriptable + recording)

```dart
class FirebaseAuthFake implements FirebaseAuth {
  // per-method scripted response slots (settable per test)
  // call recorder: (method, args, sequence) queryable per method
}
```

- Scripting a method returns exactly the scripted value; unscripted
  calls fail the recorder (named unscripted-call error) rather than
  returning a silent default — a green must mean the staged scenario
  happened.
- Recorded calls expose method name, arguments, and invocation order.

## Fixture lane

Deterministic, dependency-scoped scenario fixtures staged through the
existing fixture registry seam (#832/#893 convention): named scenarios
the loop can reference; content derived from the declared signatures
only.

## Determinism

Same row ⇒ byte-identical artifacts (no timestamps, stable ordering).
Changed row ⇒ deterministic regeneration; the CLI output names what
changed.
