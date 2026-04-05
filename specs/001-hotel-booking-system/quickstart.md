# Quick Start Guide: Hotel Booking System Development

**Branch**: `001-hotel-booking-system`
**Date**: 2026-04-03
**Status**: Complete

## Prerequisites

- Flutter 3.41+ installed
- Dart 3.11+ SDK
- Zuraffa CLI installed globally: `dart pub global activate zuraffa`
- IDE with Flutter support (VS Code or Android Studio)
- Git for version control

## Project Setup

### 1. Initialize Zuraffa Project Structure

```bash
# Create new Flutter project
flutter create hotel_booking_demo
cd hotel_booking_demo

# Initialize Zuraffa configuration
zfa config init

# Set project-specific configurations
zfa config set defaultEntityOutput "lib/src/domain/entities"
zfa config set gqlByDefault false
zfa config set mockByDefault true
zfa config set testByDefault true
```

### 2. Configure Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  zuraffa: ^3.20.1
  zorphy: ^1.6.5
  zorphy_annotation: ^1.6.5
  get_it: ^9.2.1
  go_router: ^17.1.0
  hive: ^2.3.4
  hive_flutter: ^1.1.0
  http: ^1.6.0
  provider: ^6.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.11.0
  json_serializable: ^6.13.1
  mocktail: ^1.0.4
  zuraffa: ^3.20.1
```

### 3. Install Dependencies

```bash
flutter pub get
dart pub global activate build_runner
```

## Entity Generation (Phase 1)

### Core Business Entities

```bash
# Generate Hotel entity with Zorphy annotations
zfa entity create \
  --name Hotel \
  --fields "id:String" "name:String" "description:String" "starRating:int" "address:String" "amenities:List<String>" "photos:List<String>" "checkInTime:String" "checkOutTime:String" \
  --json \
  --compare

# Generate Room entity
zfa entity create \
  --name Room \
  --fields "id:String" "hotelId:String" "type:String" "name:String" "maxOccupancy:int" "basePrice:double" "currency:String" "amenities:List<String>" "photos:List<String>" \
  --json \
  --compare

# Generate User entity with role-based permissions
zfa entity create \
  --name User \
  --fields "id:String" "email:String" "firstName:String" "lastName:String" "phoneNumber:String" "role:String" "isActive:bool" \
  --json \
  --compare

# Generate Booking entity
zfa entity create \
  --name Booking \
  --fields "id:String" "confirmationNumber:String" "userId:String" "hotelId:String" "roomId:String" "checkInDate:DateTime" "checkOutDate:DateTime" "guestCount:int" "totalAmount:double" "status:String" \
  --json \
  --compare

# Generate Review entity
zfa entity create \
  --name Review \
  --fields "id:String" "userId:String" "hotelId:String" "overallRating:double" "title:String" "comment:String" "isVerified:bool" "stayDate:DateTime" \
  --json \
  --compare
```

### Supporting Entities

```bash
# Generate Address entity
zfa entity create \
  --name Address \
  --fields "street:String" "city:String" "state:String" "country:String" "postalCode:String" \
  --json

# Generate Payment entity
zfa entity create \
  --name PaymentRecord \
  --fields "id:String" "amount:double" "currency:String" "method:String" "status:String" "transactionId:String" "processedAt:DateTime" \
  --json

# Generate Search query entity
zfa entity create \
  --name SearchQuery \
  --fields "id:String" "destination:String" "checkIn:DateTime" "checkOut:DateTime" "guestCount:int" "priceMin:double?" "priceMax:double?" \
  --json
```

### Generate Enums

```bash
# User roles enum
zfa entity enum \
  --name UserRole \
  --values "Guest" "RegisteredUser" "Admin"

# Booking status enum
zfa entity enum \
  --name BookingStatus \
  --values "Pending" "Confirmed" "CheckedIn" "CheckedOut" "Cancelled"

# Payment status enum
zfa entity enum \
  --name PaymentStatus \
  --values "Pending" "Completed" "Failed" "Refunded"

# Room types enum
zfa entity enum \
  --name RoomType \
  --values "Standard" "Deluxe" "Suite" "Presidential"
```

### Run Code Generation

```bash
zfa build
```

## Feature Scaffolding (Phase 2)

### Hotel Search Feature

```bash
# Generate complete hotel search feature with VPCS pattern
zfa feature scaffold Hotel \
  --methods get,getList \
  --vpcs \
  --state \
  --mock \
  --test \
  --cache
```

### Room Management Feature

```bash
# Generate room management with filtering capabilities
zfa feature scaffold Room \
  --methods get,getList,create,update \
  --vpcs \
  --state \
  --mock \
  --test
```

### Booking Management Feature

```bash
# Generate booking workflow with complete CRUD
zfa feature scaffold Booking \
  --methods get,getList,create,update,delete \
  --vpcs \
  --state \
  --mock \
  --test \
  --cache
```

### User Management Feature

```bash
# Generate user authentication and profile management
zfa feature scaffold User \
  --methods get,create,update \
  --vpcs \
  --state \
  --mock \
  --test
```

### Review System Feature

```bash
# Generate review submission and display
zfa feature scaffold Review \
  --methods get,getList,create,update \
  --vpcs \
  --state \
  --mock \
  --test
```

## Custom Use Cases (Phase 3)

### Search-Specific Use Cases

```bash
# Generate search hotels by destination use case
zfa usecase create \
  --name SearchHotelsByDestination \
  --domain search \
  --params SearchRequest \
  --returns "List<Hotel>" \
  --repo HotelRepository

# Generate apply filters use case
zfa usecase create \
  --name ApplySearchFilters \
  --domain search \
  --params FilterRequest \
  --returns "List<Hotel>" \
  --repo HotelRepository

# Generate get destination suggestions use case
zfa usecase create \
  --name GetDestinationSuggestions \
  --domain search \
  --params "String" \
  --returns "List<String>" \
  --repo HotelRepository
```

### Booking-Specific Use Cases

```bash
# Generate check room availability use case
zfa usecase create \
  --name CheckRoomAvailability \
  --domain booking \
  --params AvailabilityRequest \
  --returns RoomAvailability \
  --repo RoomRepository

# Generate calculate pricing use case
zfa usecase create \
  --name CalculateBookingPrice \
  --domain booking \
  --params PricingRequest \
  --returns PricingInfo \
  --repo BookingRepository

# Generate process payment use case
zfa usecase create \
  --name ProcessPayment \
  --domain payment \
  --params PaymentRequest \
  --returns PaymentResult \
  --repo PaymentRepository
```

### Admin-Specific Use Cases

```bash
# Generate hotel management use cases
zfa usecase create \
  --name ManageHotelInventory \
  --domain admin \
  --params InventoryUpdate \
  --returns "void" \
  --repo HotelRepository

# Generate booking analytics use case
zfa usecase create \
  --name GenerateBookingAnalytics \
  --domain admin \
  --params AnalyticsRequest \
  --returns BookingAnalytics \
  --repo BookingRepository
```

## Mock Data Generation (Phase 4)

### Generate Mock Providers

```bash
# Generate mock hotel data provider
zfa mock create \
  --name HotelMockProvider \
  --domain hotel \
  --service HotelService

# Generate mock booking data provider
zfa mock create \
  --name BookingMockProvider \
  --domain booking \
  --service BookingService

# Generate mock payment provider
zfa mock create \
  --name PaymentMockProvider \
  --domain payment \
  --service PaymentService

# Generate mock user authentication provider
zfa mock create \
  --name AuthMockProvider \
  --domain auth \
  --service AuthService
```

### Generate Test Data

```bash
# Generate comprehensive test data sets
zfa mock create \
  --name TestDataGenerator \
  --domain test \
  --dataOnly
```

## Dependency Injection Setup (Phase 5)

### Generate DI Configuration

```bash
# Generate DI for hotel management
zfa di create \
  --name Hotel \
  --useMock

# Generate DI for booking management
zfa di create \
  --name Booking \
  --useMock

# Generate DI for user management
zfa di create \
  --name User \
  --useMock

# Generate DI for payment processing
zfa di create \
  --name Payment \
  --useMock
```

## Final Build and Validation

### Build Generated Code

```bash
# Build all generated code
zfa build

# Run architectural compliance check
zfa doctor

# Run generated tests
flutter test
```

### Start Development Server

```bash
# Run in debug mode
flutter run

# Or run with specific device
flutter devices
flutter run -d <device-id>
```

## Development Workflow

### Daily Development Cycle

1. **Feature Planning**: Define required entities and use cases
2. **Entity Generation**: Use `zfa entity create` for new data models
3. **Feature Scaffolding**: Use `zfa feature scaffold` for complete features
4. **Custom Logic**: Use `zfa usecase create` for specific business logic
5. **Testing**: Use `zfa test create` for comprehensive test coverage
6. **Validation**: Use `zfa doctor` for architectural compliance
7. **Build**: Use `zfa build` for code generation

### Best Practices

- **Always use CLI**: Never create files manually - use Zuraffa CLI exclusively
- **Test-First**: Generate tests before implementing business logic
- **Mock-Driven**: Use mock providers for all external dependencies
- **Incremental**: Build features incrementally with frequent validation
- **Documentation**: Update contracts when adding new interfaces

### Common Commands Reference

```bash
# Entity operations
zfa entity list                    # List all entities
zfa entity add-field Hotel location:LatLng  # Add field to existing entity

# Feature operations
zfa feature controller Hotel       # Add controller to existing feature
zfa feature state Booking         # Add state management to feature

# Build and validation
zfa build                         # Generate code
zfa doctor                        # Check compliance
flutter test                      # Run tests
flutter analyze                   # Static analysis
```

## Troubleshooting

### Common Issues

1. **Build Errors**: Run `flutter clean && flutter pub get && zfa build`
2. **Missing Dependencies**: Check `pubspec.yaml` for required packages
3. **DI Issues**: Verify all providers are registered in DI configuration
4. **Test Failures**: Ensure mock providers return expected data types

### Getting Help

- Zuraffa Documentation: Check official docs for command references
- Architecture Issues: Run `zfa doctor` for compliance validation
- Community Support: Check GitHub issues for common problems

This quick start guide demonstrates Zuraffa's complete capabilities for enterprise-grade mobile application development using Clean Architecture principles and mock-driven development patterns.