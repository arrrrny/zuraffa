# Tasks: Hotel Booking System (Demo Clone of Booking.com)

**Input**: Design documents from `/specs/001-hotel-booking-system/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are included as this project demonstrates TDD with Zuraffa-generated test suites.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter project**: `lib/src/`, `test/` at repository root
- Paths shown below follow Flutter Clean Architecture with Zuraffa conventions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Zuraffa framework setup

- [x] T001 Create Flutter project structure with Zuraffa configuration
- [ ] T002 Initialize Zuraffa configuration file (.zfa.json) and set project defaults
- [ ] T003 [P] Configure pubspec.yaml with Zuraffa, GetIt, GoRouter, and Hive dependencies
- [ ] T004 [P] Setup Hive local storage initialization for mock data persistence
- [ ] T005 [P] Configure linting and formatting tools per Flutter best practices

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core entities, enums, and infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Entity Generation via Zuraffa CLI

- [ ] T006 [P] Generate UserRole enum using `zfa entity enum --name UserRole --values Guest,RegisteredUser,Admin`
- [ ] T007 [P] Generate BookingStatus enum using `zfa entity enum --name BookingStatus --values Pending,Confirmed,CheckedIn,CheckedOut,Cancelled`
- [ ] T008 [P] Generate PaymentStatus enum using `zfa entity enum --name PaymentStatus --values Pending,Completed,Failed,Refunded`
- [ ] T009 [P] Generate RoomType enum using `zfa entity enum --name RoomType --values Standard,Deluxe,Suite,Presidential`
- [ ] T010 [P] Generate PaymentMethod enum using `zfa entity enum --name PaymentMethod --values CreditCard,DebitCard,PayPal,ApplePay,GooglePay`

### Supporting Entities

- [ ] T011 [P] Generate Address entity using `zfa entity create --name Address --fields street:String,city:String,state:String,country:String,postalCode:String --json`
- [ ] T012 [P] Generate LatLng entity using `zfa entity create --name LatLng --fields latitude:double,longitude:double --json`
- [ ] T013 [P] Generate ContactInfo entity using `zfa entity create --name ContactInfo --fields phone:String,email:String,website:String --json`
- [ ] T014 [P] Generate Guest entity using `zfa entity create --name Guest --fields firstName:String,lastName:String,email:String,isPrimary:bool --json`
- [ ] T015 [P] Generate PaymentRecord entity using `zfa entity create --name PaymentRecord --fields id:String,method:String,amount:double,currency:String,status:String,transactionId:String,processedAt:DateTime --json`

### Core Business Entities

- [ ] T016 Generate User entity using `zfa entity create --name User --fields id:String,email:String,firstName:String,lastName:String,phoneNumber:String,role:String,isActive:bool --json --compare`
- [ ] T017 Generate Hotel entity using `zfa entity create --name Hotel --fields id:String,name:String,description:String,starRating:int,amenities:List<String>,photos:List<String>,checkInTime:String,checkOutTime:String --json --compare`
- [ ] T018 Generate Room entity using `zfa entity create --name Room --fields id:String,hotelId:String,type:String,name:String,maxOccupancy:int,basePrice:double,currency:String,amenities:List<String>,photos:List<String> --json --compare`
- [ ] T019 Generate Booking entity using `zfa entity create --name Booking --fields id:String,confirmationNumber:String,userId:String,hotelId:String,roomId:String,checkInDate:DateTime,checkOutDate:DateTime,guestCount:int,totalAmount:double,status:String --json --compare`
- [ ] T020 Generate Review entity using `zfa entity create --name Review --fields id:String,userId:String,hotelId:String,overallRating:double,title:String,comment:String,isVerified:bool,stayDate:DateTime --json --compare`

### Build Generated Code

- [ ] T021 Run `zfa build` to generate all Zorphy entities and supporting code

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Hotel Search and Discovery (Priority: P1) 🎯 MVP

**Goal**: Enable users (guest or registered) to search for hotels by destination, dates, and guest count with basic filtering

**Independent Test**: Search for "Paris" with check-in "2026-05-01", check-out "2026-05-03", 2 guests, and verify relevant hotels appear with names, prices, ratings, and images

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T022 [P] [US1] Generate Hotel feature tests using `zfa feature scaffold Hotel --methods get,getList --test --mock`
- [ ] T023 [P] [US1] Generate search-specific use case tests using `zfa usecase create --name SearchHotelsByDestination --domain search --params SearchRequest --returns List<Hotel> --test`

### Mock Data Providers for User Story 1

- [ ] T024 [P] [US1] Generate Hotel mock provider using `zfa mock create --name HotelMockProvider --domain hotel --service HotelService`
- [ ] T025 [P] [US1] Generate search mock provider using `zfa mock create --name SearchMockProvider --domain search --service SearchService`
- [ ] T026 [US1] Configure mock data generation for 50+ hotels across 10+ cities with realistic data

### Implementation for User Story 1

- [ ] T027 [US1] Generate Hotel feature scaffold using `zfa feature scaffold Hotel --methods get,getList --vpcs --state --mock --cache`
- [ ] T028 [US1] Generate search-specific use cases using `zfa usecase create --name SearchHotelsByDestination --domain search --params SearchRequest --returns List<Hotel> --repo HotelRepository`
- [ ] T029 [US1] Generate destination autocomplete use case using `zfa usecase create --name GetDestinationSuggestions --domain search --params String --returns List<String> --repo HotelRepository`
- [ ] T030 [US1] Generate search filters use case using `zfa usecase create --name ApplySearchFilters --domain search --params FilterRequest --returns List<Hotel> --repo HotelRepository`
- [ ] T031 [US1] Generate search validation use case for date ranges and guest counts
- [ ] T032 [US1] Generate dependency injection for search features using `zfa di create --name Hotel --useMock`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Hotel Detail Exploration (Priority: P1)

**Goal**: Display comprehensive hotel information including photos, amenities, reviews, and room options

**Independent Test**: Select any hotel from search results and verify detailed information page loads with photos, description, amenities, reviews, and room options

### Tests for User Story 2 ⚠️

- [ ] T033 [P] [US2] Generate hotel detail view tests for photo gallery, amenities display, and review sections
- [ ] T034 [P] [US2] Generate use case tests for hotel detail retrieval and related room information

### Mock Data Enhancement for User Story 2

- [ ] T035 [P] [US2] Generate Review mock provider using `zfa mock create --name ReviewMockProvider --domain review --service ReviewService`
- [ ] T036 [US2] Enhance Hotel mock provider with detailed descriptions, photo galleries, and comprehensive amenities lists

### Implementation for User Story 2

- [ ] T037 [US2] Generate Review feature scaffold using `zfa feature scaffold Review --methods get,getList --vpcs --state --mock`
- [ ] T038 [US2] Generate hotel detail view using `zfa view create --name HotelDetailView --state --di`
- [ ] T039 [US2] Generate get hotel details use case with related room information
- [ ] T040 [US2] Generate get hotel reviews use case with filtering and pagination
- [ ] T041 [US2] Integrate photo gallery functionality with navigation controls
- [ ] T042 [US2] Generate dependency injection for hotel detail features

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Room Selection and Booking (Priority: P1)

**Goal**: Complete reservation workflow from room selection through payment to booking confirmation

**Independent Test**: Select a room from hotel details, fill guest information, enter payment details, and receive booking confirmation with reservation number

### Tests for User Story 3 ⚠️

- [ ] T043 [P] [US3] Generate Booking feature tests using `zfa feature scaffold Booking --methods get,create,update --test --mock`
- [ ] T044 [P] [US3] Generate payment processing tests using `zfa mock create --name PaymentMockProvider --domain payment --test`
- [ ] T045 [P] [US3] Generate booking confirmation and email notification tests

### Mock Provider Setup for User Story 3

- [ ] T046 [P] [US3] Generate Payment mock provider using `zfa mock create --name PaymentMockProvider --domain payment --service PaymentService`
- [ ] T047 [P] [US3] Generate Email notification mock provider using `zfa mock create --name EmailMockProvider --domain notification --service EmailService`
- [ ] T048 [US3] Configure realistic payment success/failure scenarios (95% success rate)

### Implementation for User Story 3

- [ ] T049 [US3] Generate Booking feature scaffold using `zfa feature scaffold Booking --methods get,create,update --vpcs --state --mock`
- [ ] T050 [US3] Generate room availability check use case using `zfa usecase create --name CheckRoomAvailability --domain booking --params AvailabilityRequest --returns RoomAvailability --repo RoomRepository`
- [ ] T051 [US3] Generate booking creation use case using `zfa usecase create --name CreateBooking --domain booking --params BookingRequest --returns BookingConfirmation --repo BookingRepository`
- [ ] T052 [US3] Generate payment processing use case using `zfa usecase create --name ProcessPayment --domain payment --params PaymentRequest --returns PaymentResult --repo PaymentRepository`
- [ ] T053 [US3] Generate booking confirmation view with email confirmation status
- [ ] T054 [US3] Generate booking validation for guest counts, date ranges, and room capacity
- [ ] T055 [US3] Generate dependency injection for booking and payment features

**Checkpoint**: All three P1 user stories should now be independently functional

---

## Phase 6: User Story 4 - Advanced Search Filtering (Priority: P2)

**Goal**: Enhanced search with price range, star rating, amenities, and guest rating filters

**Independent Test**: Apply filters (price $100-300, 4+ stars, Wi-Fi required) and verify results update with only matching hotels

### Implementation for User Story 4

- [ ] T056 [P] [US4] Generate search filter state management using `zfa state create --name SearchFilter --methods get,update`
- [ ] T057 [US4] Generate advanced filter use cases for price range, star rating, and amenities
- [ ] T058 [US4] Generate filter persistence for registered users using user preferences
- [ ] T059 [US4] Enhance search UI with collapsible filter panel and sort options

---

## Phase 7: User Story 5 - User Account and Booking Management (Priority: P2)

**Goal**: User registration, authentication, booking history, and reservation management

**Independent Test**: Create account, make booking while logged in, access account dashboard to view booking history and manage reservations

### Implementation for User Story 5

- [ ] T060 [US5] Generate User feature scaffold using `zfa feature scaffold User --methods get,create,update --vpcs --state --mock`
- [ ] T061 [P] [US5] Generate authentication mock provider using `zfa mock create --name AuthMockProvider --domain auth --service AuthService`
- [ ] T062 [US5] Generate user registration and login use cases
- [ ] T063 [US5] Generate booking history and management use cases
- [ ] T064 [US5] Generate user profile management views and controllers
- [ ] T065 [US5] Generate session management and cross-device sync capabilities

---

## Phase 8: User Story 6 - Real-time Availability and Pricing (Priority: P3)

**Goal**: Simulated real-time inventory updates and dynamic pricing

**Independent Test**: Verify availability status and prices reflect simulated inventory changes within 1 minute

### Implementation for User Story 6

- [ ] T066 [P] [US6] Generate inventory mock provider with real-time simulation using `zfa mock create --name InventoryMockProvider --domain inventory --service InventoryService`
- [ ] T067 [US6] Generate real-time pricing calculation use cases with seasonal variations
- [ ] T068 [US6] Generate inventory conflict handling for booking attempts on unavailable rooms
- [ ] T069 [US6] Implement pricing update streams and UI refresh mechanisms

---

## Phase 9: User Story 7 - Multi-device Booking Continuation (Priority: P3)

**Goal**: Cross-device session synchronization and booking progress preservation

**Independent Test**: Start search on desktop, save preferences, login on mobile, and verify synchronization

### Implementation for User Story 7

- [ ] T070 [P] [US7] Generate session synchronization mock provider using `zfa mock create --name SyncMockProvider --domain sync --service SyncService`
- [ ] T071 [US7] Generate cross-device state persistence use cases
- [ ] T072 [US7] Generate booking progress restoration capabilities
- [ ] T073 [US7] Generate user preference synchronization across devices

---

## Phase 10: Admin Features (Supporting Multi-Role System)

**Goal**: Administrative functions for hotel, room, and booking management

### Implementation for Admin Features

- [ ] T074 [P] Generate admin authentication and role validation
- [ ] T075 [P] Generate hotel management admin views for CRUD operations
- [ ] T076 [P] Generate booking analytics and reporting use cases
- [ ] T077 Generate admin dashboard with booking statistics and hotel performance metrics

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final optimization

- [ ] T078 [P] Run comprehensive architectural compliance check using `zfa doctor`
- [ ] T079 [P] Generate performance optimization for large dataset handling
- [ ] T080 [P] Generate error handling and offline capability enhancements
- [ ] T081 [P] Run complete test suite validation using `flutter test`
- [ ] T082 [P] Generate app-wide theming and responsive design improvements
- [ ] T083 [P] Documentation updates for demo presentation and quickstart validation
- [ ] T084 Performance testing across all user flows with 60fps validation
- [ ] T085 Final demo preparation and data reset capabilities

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-9)**: All depend on Foundational phase completion
  - P1 stories (3-5) can proceed in parallel or priority order
  - P2/P3 stories (6-9) can start after P1 completion or run in parallel
- **Admin Features (Phase 10)**: Can run in parallel with P2/P3 stories
- **Polish (Phase 11)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - May integrate with US1 but independently testable
- **User Story 3 (P1)**: Can start after Foundational - May integrate with US1/US2 but independently testable
- **User Stories 4-7**: Can start after Foundational - May integrate with P1 stories but independently testable

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD cycle)
- Mock providers before use cases and repositories
- Entities and supporting structures before business logic
- Use cases before presentation layer (VPC pattern)
- Core implementation before UI integration
- Story completion validation before moving to next priority

### Parallel Opportunities

All tasks marked [P] can run in parallel within their phase:

```bash
# Example: User Story 1 Parallel Tasks
Task T022: "Generate Hotel feature tests"
Task T023: "Generate search use case tests" 
Task T024: "Generate Hotel mock provider"
Task T025: "Generate search mock provider"
```

Different user stories can be worked on in parallel by different team members once Foundational phase completes.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently using Zuraffa-generated tests
5. Demo/validate if ready - demonstrates basic hotel search capabilities

### Incremental Delivery with Zuraffa

1. Complete Setup + Foundational → Foundation ready with all entities generated
2. Add User Story 1 → Test independently → Demo basic search (MVP!)
3. Add User Story 2 → Test independently → Demo hotel details 
4. Add User Story 3 → Test independently → Demo complete booking flow
5. Each additional story adds value without breaking previous functionality
6. Use `zfa doctor` at each checkpoint to validate architectural compliance

### Parallel Team Strategy

With multiple developers using Zuraffa CLI:

1. Team completes Setup + Foundational together using CLI commands
2. Once Foundational is done:
   - Developer A: User Story 1 using `zfa feature scaffold Hotel`
   - Developer B: User Story 2 using `zfa feature scaffold Review`  
   - Developer C: User Story 3 using `zfa feature scaffold Booking`
3. Stories complete and integrate independently through well-defined interfaces
4. All code generated through CLI ensures architectural consistency

---

## Zuraffa CLI Validation

### Required CLI Usage Validation

- All entities MUST be generated via `zfa entity create` commands
- All features MUST be scaffolded via `zfa feature scaffold` commands
- All use cases MUST be created via `zfa usecase create` commands
- All mock providers MUST be generated via `zfa mock create` commands
- All DI configuration MUST use `zfa di create` commands
- Build process MUST use `zfa build` exclusively
- Architectural compliance MUST be validated via `zfa doctor`

### Success Criteria

- Zero manual file creation (except UI widgets)
- 100% CLI-generated architectural components
- >95% test coverage through generated test suites
- All constitutional principles satisfied per `zfa doctor` validation
- Seamless mock provider swapping demonstration
- Complete Clean Architecture layer separation
- Working demo across all priority 1 user stories

## Notes

- [P] tasks = different files, no dependencies within phase
- [Story] label maps task to specific user story for traceability  
- Each user story should be independently completable and testable
- Verify Zuraffa-generated tests fail before implementing business logic (TDD)
- Use `zfa doctor` at each checkpoint to validate architectural compliance
- Commit after each logical task group or user story completion
- All code generation through Zuraffa CLI demonstrates framework capabilities
- Mock providers enable complete offline development and testing