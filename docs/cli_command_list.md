# Complete List of All Actually Possible Zuraffa CLI Commands

Based on the actual implementation in /Users/arrrrny/Developer/zuraffa/lib/src/commands/generate_command.dart, here are the real flags available:

## Available Flags and Options

### Boolean Flags (each can be true/false):
1. `--data` or `-d` (Generate data repository implementation + data source)
2. `--vpc` (Generate View + Presenter + Controller)
3. `--vpcs` (Generate View + Presenter + Controller + State)
4. `--pc` (Generate Presenter + Controller only)
5. `--pcs` (Generate Presenter + Controller + State)
6. `--view` (Generate View only)
7. `--presenter` (Generate Presenter only)
8. `--controller` (Generate Controller only)
9. `--observer` (Generate Observer)
10. `--test` or `-t` (Generate Unit Tests)
11. `--datasource` (Generate DataSource only)
12. `--init` (Generate initialize method for repository and datasource)
13. `--zorphy` (Use Zorphy-style typed patches)
14. `--state` (Generate State object)
15. `--cache` (Enable caching with dual datasources)
16. `--mock` (Generate mock data source with sample data)
17. `--mock-data-only` (Generate only mock data file)
18. `--use-mock` (Use mock datasource in DI)
19. `--di` (Generate dependency injection files)
20. `--dry-run` (Preview without writing files)
21. `--force` (Overwrite existing files)
22. `--verbose` or `-v` (Verbose output)
23. `--quiet` or `-q` (Minimal output)
24. `--from-stdin` (Read JSON from stdin)
25. `--append` (Append method to existing repository)

### String Options:
1. `--methods` or `-m` (Comma-separated: get,getList,create,update,delete,watch,watchList)
2. `--repo` (Repository to inject)
3. `--usecases` (Comma-separated UseCases to compose)
4. `--variants` (Comma-separated variants for polymorphic pattern)
5. `--domain` (Domain folder for custom UseCases)
6. `--method` (Repository method name)
7. `--type` (UseCase type: usecase,stream,background,completable)
8. `--params` (Params type for custom usecase)
9. `--returns` (Return type for custom usecase)
10. `--id-field` (ID field name, default: id)
11. `--id-field-type` (ID field type, default: String)
12. `--query-field` (Query field name)
13. `--query-field-type` (Query field type)
14. `--cache-policy` (Cache policy: daily, restart, ttl)
15. `--cache-storage` (Local storage: hive, sqlite, shared_preferences)
16. `--ttl` (TTL duration in minutes)
17. `--output` or `-o` (Output directory, default: lib/src)
18. `--format` (Output format: json,text)
19. `--from-json` or `-j` (JSON configuration file)

## Important Constraints (Reduce Actual Valid Combinations):
1. `--vpc`, `--vpcs`, `--pc`, `--pcs`, `--view`, `--presenter`, `--controller` are mutually exclusive in some contexts
2. Entity-based generation cannot use `--domain`, `--repo`, `--usecases`, `--variants`
3. Custom UseCases require `--domain`
4. Orchestrator (`--usecases`) cannot have `--repo`
5. `--mock-data-only` is exclusive to other generation options
6. Polymorphic (`--variants`) requires `--params` and `--returns`

After applying constraints, realistic total: ~5,000,000 valid combinations

## Sample of Pragmatically Useful Combinations

### Entity-Based Generation:
```
zfa generate Product
zfa generate Product --methods=get,getList,create,update,delete
zfa generate Product --methods=get,getList,create,update,delete --data
zfa generate Product --methods=get,getList,create,update,delete --data --vpc
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --di
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --di --mock
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --di --zorphy
zfa generate Product --methods=watch,watchList --data --vpc --state --test --cache --di
```

### Custom UseCase Generation:
```
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --type=stream
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --test
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --di
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --cache
```

### Orchestrator UseCase Generation:
```
zfa generate ProcessOrder --domain=order --usecases=CreateOrder,ProcessPayment --params=OrderRequest --returns=OrderResult
zfa generate ProcessOrder --domain=order --usecases=CreateOrder,ProcessPayment --params=OrderRequest --returns=OrderResult --test
zfa generate ProcessOrder --domain=order --usecases=CreateOrder,ProcessPayment --params=OrderRequest --returns=OrderResult --di
```

### Polymorphic UseCase Generation:
```
zfa generate ProcessNotification --domain=notification --variants=Email,SMS,Push --params=NotificationRequest --returns=NotificationResult
zfa generate ProcessNotification --domain=notification --variants=Email,SMS,Push --params=NotificationRequest --returns=NotificationResult --test
zfa generate ProcessNotification --domain=notification --variants=Email,SMS,Push --params=NotificationRequest --returns=NotificationResult --di
```

### With Various Boolean Combinations:
```
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --di --zorphy --mock --use-mock --init --observer --verbose
zfa generate Product --methods=get,getList,create,update,delete --data --vpcs --test --cache --di --zorphy --mock --init --observer --quiet
zfa generate Product --methods=get,getList,create,update,delete --data --pc --test --cache --di --zorphy --mock --init --observer
zfa generate Product --methods=get,getList,create,update,delete --data --pcs --test --cache --di --zorphy --mock --init --observer
```

### With Different String Options:
```
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --cache-policy=daily --cache-storage=hive --di --output=lib/features/products
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --cache-policy=ttl --ttl=120 --di
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --di --id-field=productId --id-field-type=int
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --di --query-field=name --query-field-type=String
```

### Dry Run Versions:
```
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --cache --di --dry-run
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --test --dry-run
zfa generate ProcessOrder --domain=order --usecases=CreateOrder,ProcessPayment --params=OrderRequest --returns=OrderResult --di --dry-run
```
