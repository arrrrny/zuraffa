# ZFA 2.0.0 - Clean Architecture Framework

## 🚀 What's New

ZFA 2.0.0 transforms from a CRUD generator into a **complete Clean Architecture framework** with three powerful patterns:

### 1. Entity-Based (Unchanged)
Perfect CRUD generation for entities:
```bash
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc
```

### 2. Orchestrator Pattern (NEW)
Compose multiple UseCases into workflows:
```bash
# Step 1: Create atomic UseCases
zfa generate GenerateZiks --repo=Marketplace --domain=zik --params=Spark --returns=List<Zik>
zfa generate ParseZik --repo=Parser --domain=zik --params=Zik --returns=Listing
zfa generate DetectCategory --repo=Category --domain=category --params=Spark --returns=Category

# Step 2: Orchestrate them
zfa generate SearchProduct \
  --usecases=GenerateZiks,ParseZik,DetectCategory \
  --domain=search \
  --params=Spark \
  --returns=Stream<Listing> \
  --type=stream
```

**Generated:**
```dart
class SearchProductUseCase extends StreamUseCase<Listing, Spark> {
  final GenerateZiksUseCase _generateZiks;
  final ParseZikUseCase _parseZik;
  final DetectCategoryUseCase _detectCategory;

  SearchProductUseCase(
    this._generateZiks,
    this._parseZik,
    this._detectCategory,
  );

  @override
  Stream<Listing> execute(Spark params, CancelToken? cancelToken) async* {
    cancelToken?.throwIfCancelled();
    
    // TODO: Orchestrate the UseCases
    // Available:
    // - _generateZiks.execute(...)
    // - _parseZik.execute(...)
    // - _detectCategory.execute(...)
  }
}
```

### 3. Polymorphic Pattern (NEW)
Generate abstract base + concrete variants + factory:
```bash
zfa generate SparkSearch \
  --type=stream \
  --variants=Barcode,Url,Text \
  --domain=search \
  --repo=Search \
  --params=Spark \
  --returns=Listing
```

**Generated (5 files):**
- `spark_search_usecase.dart` - Abstract base
- `barcode_spark_search_usecase.dart` - Barcode variant
- `url_spark_search_usecase.dart` - URL variant
- `text_spark_search_usecase.dart` - Text variant
- `spark_search_usecase_factory.dart` - Factory with runtime switching

```dart
// Abstract base
abstract class SparkSearchUseCase extends StreamUseCase<Listing, Spark> {}

// Concrete variant
class BarcodeSparkSearchUseCase extends SparkSearchUseCase {
  final SearchRepository _search;
  
  @override
  Stream<Listing> execute(Spark params, CancelToken? cancelToken) async* {
    // TODO: Implement Barcode-specific logic
  }
}

// Factory
class SparkSearchUseCaseFactory {
  SparkSearchUseCase forParams(Spark params) {
    return switch (params.runtimeType) {
      BarcodeSpark => _barcode,
      UrlSpark => _url,
      TextSpark => _text,
      _ => throw UnimplementedError(),
    };
  }
}
```

## ⚠️ Breaking Changes

### 1. `--repos` → `--repo` (Single Repository)
**Old (1.x):**
```bash
zfa generate ProcessCheckout --repos=Cart,Order,Payment
```

**New (2.0.0):**
```bash
# Option 1: Single repo (enforces SRP)
zfa generate ProcessCheckout --repo=Checkout --domain=checkout

# Option 2: Orchestrator pattern
zfa generate ProcessCheckout --usecases=ValidateCart,CreateOrder,ProcessPayment --domain=checkout
```

### 2. `--domain` Required for Custom UseCases
**Old (1.x):**
```bash
zfa generate SearchProduct --params=Query --returns=List<Product>
```

**New (2.0.0):**
```bash
zfa generate SearchProduct --domain=search --repo=Product --params=Query --returns=List<Product>
```

### 3. Domain Organization
UseCases now organized by domain concept:
```
domain/usecases/
├── product/          # Entity-based (auto)
├── search/           # Custom domain
├── checkout/         # Custom domain
└── zik/              # Custom domain
```

## 🎯 Design Principles

### Single Responsibility
One UseCase, one repository:
```bash
# ✅ Good
zfa generate SearchProduct --repo=Product --domain=search

# ❌ Bad (no longer supported)
zfa generate SearchProduct --repos=Product,Category,Search
```

### Composition Over Complexity
Build complex workflows from simple UseCases:
```bash
# Atomic UseCases (building blocks)
zfa generate GenerateZiks --repo=Marketplace --domain=zik
zfa generate ParseZik --repo=Parser --domain=zik

# Orchestrator (composes them)
zfa generate SearchProduct --usecases=GenerateZiks,ParseZik --domain=search
```

### Polymorphism Without Switch Statements
Use factory pattern for runtime type handling:
```bash
zfa generate SparkSearch --variants=Barcode,Url,Text --domain=search
```

## 📋 Validation Rules

| UseCase Type | `--domain` | `--repo` | `--usecases` | `--variants` |
|--------------|------------|----------|--------------|--------------|
| Entity-based | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden |
| Custom | ✅ Required | ✅ Required | ❌ Forbidden | ⚠️ Optional |
| Orchestrator | ✅ Required | ❌ Forbidden | ✅ Required | ⚠️ Optional |
| Background | ✅ Required | ⚠️ Optional | ❌ Forbidden | ⚠️ Optional |
| Polymorphic | ✅ Required | ✅ Required | ❌ Forbidden | ✅ Defines pattern |

## 🔧 Complete Examples

### E-commerce Checkout Flow
```bash
# 1. Atomic UseCases
zfa generate ValidateCart --repo=Cart --domain=checkout --params=CartId --returns=bool
zfa generate CalculateTotal --repo=Pricing --domain=checkout --params=CartId --returns=Money
zfa generate CreateOrder --repo=Order --domain=checkout --params=OrderData --returns=Order
zfa generate ProcessPayment --repo=Payment --domain=checkout --params=PaymentData --returns=Receipt

# 2. Orchestrator
zfa generate ProcessCheckout \
  --usecases=ValidateCart,CalculateTotal,CreateOrder,ProcessPayment \
  --domain=checkout \
  --params=CheckoutRequest \
  --returns=Order
```

### Product Search with Multiple Sources
```bash
# 1. Polymorphic search
zfa generate SparkSearch \
  --type=stream \
  --variants=Barcode,Url,Text \
  --domain=search \
  --repo=Search \
  --params=Spark \
  --returns=Listing

# 2. Post-processing
zfa generate EnrichListing --repo=Product --domain=search --params=Listing --returns=EnrichedListing

# 3. Orchestrator
zfa generate SearchProduct \
  --usecases=SparkSearch,EnrichListing \
  --domain=search \
  --params=Spark \
  --returns=Stream<EnrichedListing> \
  --type=stream
```

### Image Processing Pipeline
```bash
# 1. Polymorphic processors
zfa generate ProcessImage \
  --type=background \
  --variants=Jpeg,Png,Webp \
  --domain=image \
  --params=ImageData \
  --returns=ProcessedImage

# 2. Post-processing
zfa generate OptimizeImage --type=background --domain=image --params=ProcessedImage --returns=OptimizedImage
zfa generate UploadImage --repo=Storage --domain=image --params=OptimizedImage --returns=ImageUrl

# 3. Orchestrator
zfa generate ProcessAndUploadImage \
  --usecases=ProcessImage,OptimizeImage,UploadImage \
  --domain=image \
  --params=ImageData \
  --returns=ImageUrl
```

## 🎓 Best Practices

### 1. Start with Atomic UseCases
Build small, focused UseCases first:
```bash
zfa generate GenerateZiks --repo=Marketplace --domain=zik --params=Spark --returns=List<Zik>
```

### 2. Compose into Workflows
Orchestrate atomic UseCases:
```bash
zfa generate SearchProduct --usecases=GenerateZiks,ParseZik --domain=search
```

### 3. Use Polymorphism for Type Variants
When you have multiple implementations of the same operation:
```bash
zfa generate SparkSearch --variants=Barcode,Url,Text --domain=search
```

### 4. Keep Repositories Focused
One repository per domain concept:
```bash
# ✅ Good
zfa generate SearchProduct --repo=Product --domain=search

# ❌ Bad
zfa generate SearchProduct --repos=Product,Category,Search,User
```

## 🚀 Migration Path

### Step 1: Identify Multi-Repo UseCases
Find UseCases using `--repos` with multiple repositories.

### Step 2: Choose Pattern
- **Single repo?** → Use `--repo`
- **Multiple repos?** → Break into atomic UseCases + orchestrator

### Step 3: Refactor
```bash
# Old
zfa generate ProcessCheckout --repos=Cart,Order,Payment

# New (Option 1: Single repo)
zfa generate ProcessCheckout --repo=Checkout --domain=checkout

# New (Option 2: Orchestrator)
zfa generate ValidateCart --repo=Cart --domain=checkout
zfa generate CreateOrder --repo=Order --domain=checkout
zfa generate ProcessPayment --repo=Payment --domain=checkout
zfa generate ProcessCheckout --usecases=ValidateCart,CreateOrder,ProcessPayment --domain=checkout
```

## 📚 Resources

- [CHANGELOG.md](CHANGELOG.md) - Full release notes
- [README.md](README.md) - Updated documentation
- [CLI_GUIDE.md](CLI_GUIDE.md) - Complete CLI reference

---

**ZFA 2.0.0** - From CRUD Generator to Clean Architecture Framework 🦒
