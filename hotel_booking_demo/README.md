# Hotel Booking Demo

A comprehensive hotel booking system demo showcasing Zuraffa's Clean Architecture capabilities.

## Overview

This Flutter application demonstrates:
- Clean Architecture with Domain-Data-Presentation layer separation
- Zuraffa CLI-driven code generation
- Mock-driven development for offline-first capabilities
- Test-driven development with generated test suites
- Type-safe error handling with Result patterns

## Project Structure

```
lib/src/
├── domain/           # Business logic layer
│   ├── entities/     # Core business objects (generated via Zuraffa)
│   ├── repositories/ # Repository interfaces
│   └── usecases/     # Business use cases
├── data/             # Data access layer
│   ├── datasources/  # Data source interfaces and implementations
│   ├── repositories/ # Repository implementations
│   └── models/       # Data transfer objects
├── presentation/     # UI layer
│   ├── views/        # Flutter screens and widgets
│   ├── presenters/   # Presentation logic
│   ├── controllers/  # User interaction handling
│   └── state/        # State management
└── di/               # Dependency injection configuration

test/
├── unit/             # Unit tests for business logic
├── integration/      # Integration tests
├── widget/           # Flutter widget tests
└── mocks/            # Mock data providers
```

## Getting Started

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Generate entities and features using Zuraffa CLI:
   ```bash
   zfa entity create --name Hotel --fields "id:String,name:String,description:String" --json
   zfa feature scaffold Hotel --methods get,getList --vpcs --state --mock --test
   ```

3. Run the application:
   ```bash
   flutter run
   ```

## Development Workflow

This project follows Zuraffa's AI-first development principles:
- All architectural components generated via CLI
- No manual boilerplate creation
- Test-driven development with generated test suites
- Mock-driven external dependencies for offline development

For detailed development guide, see the Zuraffa documentation.
