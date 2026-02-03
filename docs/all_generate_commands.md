# Complete List of zfa generate Command Combinations

This file contains all possible combinations of the `zfa generate` command with its various options and parameters.

## Basic Entity Generation

```
zfa generate Product
zfa generate Product --methods=get
zfa generate Product --methods=get,getList
zfa generate Product --methods=get,getList,create
zfa generate Product --methods=get,getList,create,update
zfa generate Product --methods=get,getList,create,update,delete
zfa generate Product --methods=get,getList,create,update,delete,watch
zfa generate Product --methods=get,getList,create,update,delete,watch,watchList
```

## Entity Generation with Repository

```
zfa generate Product --repository
zfa generate Product --methods=get --repository
zfa generate Product --methods=get,getList --repository
zfa generate Product --methods=get,getList,create --repository
zfa generate Product --methods=get,getList,create,update --repository
zfa generate Product --methods=get,getList,create,update,delete --repository
zfa generate Product --methods=get,getList,create,update,delete,watch --repository
zfa generate Product --methods=get,getList,create,update,delete,watch,watchList --repository
```

## Entity Generation with Data Layer

```
zfa generate Product --data
zfa generate Product --methods=get --data
zfa generate Product --methods=get,getList --data
zfa generate Product --methods=get,getList,create --data
zfa generate Product --methods=get,getList,create,update --data
zfa generate Product --methods=get,getList,create,update,delete --data
zfa generate Product --methods=get,getList,create,update,delete,watch --data
zfa generate Product --methods=get,getList,create,update,delete,watch,watchList --data
zfa generate Product --methods=get,getList,create,update,delete --repository --data
```

## Entity Generation with VPC (View, Presenter, Controller)

```
zfa generate Product --vpc
zfa generate Product --methods=get --vpc
zfa generate Product --methods=get,getList --vpc
zfa generate Product --methods=get,getList,create --vpc
zfa generate Product --methods=get,getList,create,update --vpc
zfa generate Product --methods=get,getList,create,update,delete --vpc
zfa generate Product --methods=get,getList,create,update,delete,watch --vpc
zfa generate Product --methods=get,getList,create,update,delete,watch,watchList --vpc
zfa generate Product --methods=get,getList,create,update,delete --repository --vpc
zfa generate Product --methods=get,getList,create,update,delete --data --vpc
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc
```

## Entity Generation with State Management

```
zfa generate Product --state
zfa generate Product --methods=get --state
zfa generate Product --methods=get,getList --state
zfa generate Product --methods=get,getList,create --state
zfa generate Product --methods=get,getList,create,update --state
zfa generate Product --methods=get,getList,create,update,delete --state
zfa generate Product --methods=get,getList,create,update,delete --repository --state
zfa generate Product --methods=get,getList,create,update,delete --data --state
zfa generate Product --methods=get,getList,create,update,delete --repository --data --state
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state
```

## Entity Generation with Tests

```
zfa generate Product --test
zfa generate Product --methods=get --test
zfa generate Product --methods=get,getList --test
zfa generate Product --methods=get,getList,create --test
zfa generate Product --methods=get,getList,create,update --test
zfa generate Product --methods=get,getList,create,update,delete --test
zfa generate Product --methods=get,getList,create,update,delete --repository --test
zfa generate Product --methods=get,getList,create,update,delete --data --test
zfa generate Product --methods=get,getList,create,update,delete --repository --data --test
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --test
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test
```

## Entity Generation with Caching

```
zfa generate Product --cache
zfa generate Product --methods=get --cache
zfa generate Product --methods=get,getList --cache
zfa generate Product --methods=get,getList,create --cache
zfa generate Product --methods=get,getList,create,update --cache
zfa generate Product --methods=get,getList,create,update,delete --cache
zfa generate Product --methods=get,getList,create,update,delete --repository --cache
zfa generate Product --methods=get,getList,create,update,delete --data --cache
zfa generate Product --methods=get,getList,create,update,delete --repository --data --cache
zfa generate Product --methods=get,getList,create,update,delete --cache --cache-policy=daily
zfa generate Product --methods=get,getList,create,update,delete --cache --cache-policy=restart
zfa generate Product --methods=get,getList,create,update,delete --cache --cache-policy=ttl --ttl=60
zfa generate Product --methods=get,getList,create,update,delete --cache --cache-storage=hive
zfa generate Product --methods=get,getList,create,update,delete --cache --cache-storage=sqlite
zfa generate Product --methods=get,getList,create,update,delete --cache --cache-storage=shared_preferences
```

## Entity Generation with Mock Data

```
zfa generate Product --mock
zfa generate Product --methods=get --mock
zfa generate Product --methods=get,getList --mock
zfa generate Product --methods=get,getList,create --mock
zfa generate Product --methods=get,getList,create,update --mock
zfa generate Product --methods=get,getList,create,update,delete --mock
zfa generate Product --methods=get,getList,create,update,delete --repository --mock
zfa generate Product --methods=get,getList,create,update,delete --data --mock
zfa generate Product --methods=get,getList,create,update,delete --repository --data --mock
zfa generate Product --mock-data-only
zfa generate Product --methods=get --mock-data-only
zfa generate Product --methods=get,getList --mock-data-only
```

## Entity Generation with Dependency Injection

```
zfa generate Product --di
zfa generate Product --methods=get --di
zfa generate Product --methods=get,getList --di
zfa generate Product --methods=get,getList,create --di
zfa generate Product --methods=get,getList,create,update --di
zfa generate Product --methods=get,getList,create,update,delete --di
zfa generate Product --methods=get,getList,create,update,delete --repository --di
zfa generate Product --methods=get,getList,create,update,delete --data --di
zfa generate Product --methods=get,getList,create,update,delete --repository --data --di
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --di
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --di
```

## Entity Generation with Morphy

```
zfa generate Product --morphy
zfa generate Product --methods=get --morphy
zfa generate Product --methods=get,getList --morphy
zfa generate Product --methods=get,getList,create --morphy
zfa generate Product --methods=get,getList,create,update --morphy
zfa generate Product --methods=get,getList,create,update,delete --morphy
zfa generate Product --methods=get,getList,create,update,delete --repository --morphy
zfa generate Product --methods=get,getList,create,update,delete --data --morphy
zfa generate Product --methods=get,getList,create,update,delete --repository --data --morphy
```

## Entity Generation with Custom ID Fields

```
zfa generate Product --id-field=id
zfa generate Product --id-field-type=String
zfa generate Product --id-field=productId --id-field-type=int
zfa generate Product --query-field=name
zfa generate Product --query-field-type=String
zfa generate Product --methods=get,getList --query-field=name --query-field-type=String
zfa generate Product --methods=get,getList --id-field=productId --id-field-type=int
```

## Custom UseCase Generation

```
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --type=usecase
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --type=stream
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --type=background
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --type=completable
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --test
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --di
```

## Orchestrator UseCase Generation

```
zfa generate ProcessOrder --domain=order --usecases=CreateOrder,ProcessPayment --params=OrderRequest --returns=OrderResult
zfa generate ProcessOrder --domain=order --usecases=CreateOrder,ProcessPayment --params=OrderRequest --returns=OrderResult --test
zfa generate ProcessOrder --domain=order --usecases=CreateOrder,ProcessPayment --params=OrderRequest --returns=OrderResult --di
```

## Polymorphic UseCase Generation

```
zfa generate ProcessNotification --domain=notification --variants=Email,SMS,Push --params=NotificationRequest --returns=NotificationResult
zfa generate ProcessNotification --domain=notification --variants=Email,SMS,Push --params=NotificationRequest --returns=NotificationResult --test
zfa generate ProcessNotification --domain=notification --variants=Email,SMS,Push --params=NotificationRequest --returns=NotificationResult --di
```

## VPC Layer Generation (Preserve Views)

```
zfa generate Product --pc
zfa generate Product --pcs
zfa generate Product --view
zfa generate Product --presenter
zfa generate Product --controller
zfa generate Product --observer
zfa generate Product --methods=get,getList,create,update,delete --pcs
zfa generate Product --methods=get,getList,create,update,delete --pc
```

## DataSource Only Generation

```
zfa generate Product --datasource
zfa generate Product --methods=get --datasource
zfa generate Product --methods=get,getList --datasource
zfa generate Product --methods=get,getList,create --datasource
zfa generate Product --methods=get,getList,create,update --datasource
zfa generate Product --methods=get,getList,create,update,delete --datasource
zfa generate Product --methods=get,getList,create,update,delete --datasource --init
```

## Advanced Combinations

```
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --di
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --mock --di
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --mock --di
zfa generate Product --methods=watch,watchList --repository --data --vpc --state --test --cache --di
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --di --morphy
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --di --id-field=productId --id-field-type=int
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --di --use-mock
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --di --output=lib/custom/path
```

## Dry Run Combinations

```
zfa generate Product --dry-run
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --dry-run
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --di --dry-run
zfa generate ProcessOrder --domain=order --repo=OrderRepository --params=OrderRequest --returns=OrderResult --dry-run
```

## Force Override Combinations

```
zfa generate Product --force
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --force
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --cache --di --force
```

## JSON Input Combinations

```
zfa generate Product --from-json=config.json
zfa generate Product --from-stdin
echo '{"name":"Product","methods":["get","getList"]}' | zfa generate Product --from-stdin
echo '{"name":"Product","methods":["get","getList"],"repository":true,"vpc":true}' | zfa generate Product --from-stdin
```

## Output Format Combinations

```
zfa generate Product --format=text
zfa generate Product --format=json
zfa generate Product --methods=get,getList,create,update,delete --repository --data --format=json
zfa generate Product --methods=get,getList,create,update,delete --repository --data --format=text
```

## Verbose and Quiet Modes

```
zfa generate Product --verbose
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --verbose
zfa generate Product --quiet
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --test --quiet
```