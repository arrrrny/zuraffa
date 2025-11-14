# 🦒 Zuraffa

**AI-First Clean Architecture State Management for Flutter**

> Paste your JSON. Get production-ready code in 10 seconds.

```bash
$ zuraffa create usecase GetProduct --from-json product.json
✓ 18 tests passing, 100% coverage, 6.8s
```

## Features

- ✅ **TDD Enforced** - Tests before code, always
- ✅ **100% Test Coverage** - AI-generated comprehensive tests
- ✅ **Clean Architecture** - Uncle Bob's principles enforced
- ✅ **Zero Boilerplate** - CLI generates everything
- ✅ **DataSource Pattern** - Remote + Local + Mock automatically
- ✅ **Primitive JSON Forever** - String, int, double, bool, DateTime, List, nested objects
- ✅ **Morphy Integration** - Uses zikzak_morphy for immutable entities

## Quick Start

```bash
# Install Zuraffa CLI
dart pub global activate zuraffa

# Initialize new project
zuraffa init my_app

# Create UseCase from JSON
zuraffa create usecase GetProduct --from-json product.json

# Create entire feature
zuraffa create feature shopping-cart --interactive
```

## Philosophy

**Three Pillars:**

1. **Primitive JSON Forever** - Only String, int, double, bool, DateTime, List<T>, nested objects
2. **TDD First** - Red → Green → Refactor. Tests before implementation.
3. **CLI + AI First** - One command, AI does everything

## Architecture

```
lib/
├── domain/
│   ├── entities/          # Morphy entities (@morphy abstract class $Entity)
│   ├── datasources/       # Abstract interfaces
│   ├── repositories/      # Abstract interfaces
│   └── usecases/         # Business logic
├── data/
│   ├── datasources/       # Remote, Local, Mock implementations
│   └── repositories/      # DataRepository implementations
└── presentation/
    └── pages/            # Flutter UI

test/
├── domain/
│   └── usecases/         # 100% coverage, AI-generated
└── data/
    ├── datasources/
    └── repositories/
```

## Status

🚧 **In Development** - v1.0.0

See [TODO.md](TODO.md) for current progress.

## License

MIT

## Credits

Built with ❤️ using:
- [zikzak_morphy](https://pub.dev/packages/zikzak_morphy) - Immutable entities with inheritance
- [Claude AI](https://anthropic.com) - AI-powered code generation
- Uncle Bob's Clean Architecture principles
