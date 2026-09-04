# Quickstart: Dependency-Table Mocks (072)

Declare a row, generate its certified mock, test against it, swap it later.

```text
1. Declare in your spec's `## External Dependencies & Contracts`:

   | Dependency  | Type    | Contract                                            | Mock Priority |
   | ----------- | ------- | --------------------------------------------------- | ------------- |
   | FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void  | P1            |
   | Hive         | storage | openBox(name) -> Box, put(key, value) -> void       | P2            |

2. Generate the certified mock from the declared row:

   zfa mock dependency FirebaseAuth
   # mock-dependency: name=FirebaseAuth kind=service priority=P1 methods=2 outcome=generated feature=<feature>

3. Run the loop: behaviors whose trace names the row test against the
   generated mock automatically (provenance names the row).

   zfa tdd run --all

4. Later, swap in the real adapter behind the same interface:

   zfa tdd realize --adapter FirebaseAuth
   # differential gates arbitrate against the DECLARED contract;
   # surface drift refuses naming the member + row.
```

## Refusals you may see

- `no declared dependency row named "X"` → add the row (exit 2).
- malformed signature → fix to `name(Params) -> Return` (exit 3).
- duplicate dependency name → merge the rows (exit 4).
