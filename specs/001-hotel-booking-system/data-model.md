# Data Model: Hotel Booking System

**Branch**: `001-hotel-booking-system`
**Date**: 2026-04-03
**Status**: Complete

## Core Entities

### Hotel
Represents accommodation properties with comprehensive information and metadata.

**Fields**:
- `id`: String (unique identifier)
- `name`: String (hotel name, max 100 chars)
- `description`: String (detailed description, max 2000 chars)
- `starRating`: int (1-5 star rating)
- `address`: Address (embedded object)
- `coordinates`: LatLng (latitude/longitude)
- `amenities`: List<String> (Wi-Fi, Pool, Gym, etc.)
- `photos`: List<String> (image URLs)
- `contactInfo`: ContactInfo (phone, email, website)
- `checkInTime`: String (e.g., "15:00")
- `checkOutTime`: String (e.g., "11:00")
- `policies`: List<String> (cancellation, pet, smoking policies)
- `createdAt`: DateTime
- `updatedAt`: DateTime

**Validation Rules**:
- name: required, 1-100 characters
- starRating: required, 1-5 range
- address: required, valid postal format
- photos: minimum 3 images required

**Relationships**:
- One-to-many: Hotel → Room
- One-to-many: Hotel → Review

### Room
Specific accommodation units within hotels with pricing and availability.

**Fields**:
- `id`: String (unique identifier)
- `hotelId`: String (foreign key to Hotel)
- `type`: RoomType (Standard, Deluxe, Suite, Presidential)
- `name`: String (room type name)
- `description`: String (room description)
- `maxOccupancy`: int (maximum guests)
- `bedConfiguration`: String (King, Queen, Twin, etc.)
- `sizeSqFt`: int (room size in square feet)
- `amenities`: List<String> (room-specific amenities)
- `photos`: List<String> (room image URLs)
- `basePrice`: double (nightly rate in USD)
- `currency`: String (price currency code)
- `taxRate`: double (tax percentage)
- `isActive`: bool (room availability status)
- `createdAt`: DateTime
- `updatedAt`: DateTime

**Validation Rules**:
- maxOccupancy: required, 1-10 range
- basePrice: required, positive value
- currency: required, 3-character ISO code

**Relationships**:
- Many-to-one: Room → Hotel
- One-to-many: Room → Booking
- One-to-many: Room → Availability

### User
Platform users with authentication and role-based permissions.

**Fields**:
- `id`: String (unique identifier)
- `email`: String (unique email address)
- `firstName`: String (user's first name)
- `lastName`: String (user's last name)
- `phoneNumber`: String (contact phone)
- `dateOfBirth`: DateTime (optional)
- `role`: UserRole (Guest, RegisteredUser, Admin)
- `preferences`: UserPreferences (search preferences)
- `loyaltyLevel`: LoyaltyLevel (Bronze, Silver, Gold, Platinum)
- `isActive`: bool (account status)
- `lastLoginAt`: DateTime (last login timestamp)
- `createdAt`: DateTime
- `updatedAt`: DateTime

**Validation Rules**:
- email: required, valid email format, unique
- firstName/lastName: required, 1-50 characters
- phoneNumber: valid international format
- role: required, valid enum value

**Relationships**:
- One-to-many: User → Booking
- One-to-many: User → Review
- One-to-many: User → SearchQuery

### Booking
Guest reservations linking users to specific rooms for defined date ranges.

**Fields**:
- `id`: String (unique identifier)
- `confirmationNumber`: String (user-facing booking reference)
- `userId`: String (foreign key to User)
- `hotelId`: String (foreign key to Hotel)
- `roomId`: String (foreign key to Room)
- `checkInDate`: DateTime (arrival date)
- `checkOutDate`: DateTime (departure date)
- `guestCount`: int (number of guests)
- `guestDetails`: List<Guest> (primary and additional guests)
- `totalAmount`: double (total booking cost)
- `taxAmount`: double (total tax amount)
- `currency`: String (booking currency)
- `status`: BookingStatus (Pending, Confirmed, CheckedIn, CheckedOut, Cancelled)
- `paymentInfo`: PaymentRecord (payment details)
- `specialRequests`: String (guest requests)
- `cancellationPolicy`: String (applicable cancellation terms)
- `createdAt`: DateTime
- `updatedAt`: DateTime

**Validation Rules**:
- checkOutDate: must be after checkInDate
- guestCount: required, 1-10 range, ≤ room maxOccupancy
- confirmationNumber: required, unique, alphanumeric
- totalAmount: required, positive value

**Relationships**:
- Many-to-one: Booking → User
- Many-to-one: Booking → Hotel
- Many-to-one: Booking → Room
- One-to-one: Booking → PaymentRecord

### Review
Guest feedback on hotels with ratings and written comments.

**Fields**:
- `id`: String (unique identifier)
- `userId`: String (foreign key to User)
- `hotelId`: String (foreign key to Hotel)
- `bookingId`: String (foreign key to Booking, optional)
- `overallRating`: double (1-5 stars, decimal precision)
- `cleanlinessRating`: double (1-5 stars)
- `serviceRating`: double (1-5 stars)
- `locationRating`: double (1-5 stars)
- `valueRating`: double (1-5 stars)
- `title`: String (review title, max 100 chars)
- `comment`: String (detailed review, max 2000 chars)
- `pros`: List<String> (positive aspects)
- `cons`: List<String> (negative aspects)
- `isVerified`: bool (verified stay)
- `helpfulVotes`: int (community helpful votes)
- `stayDate`: DateTime (when the stay occurred)
- `createdAt`: DateTime
- `updatedAt`: DateTime

**Validation Rules**:
- overallRating: required, 1-5 range
- title: required, 1-100 characters
- comment: optional, max 2000 characters
- User can only review hotels they've booked

**Relationships**:
- Many-to-one: Review → User
- Many-to-one: Review → Hotel
- Many-to-one: Review → Booking (optional)

## Supporting Entities

### Address
**Fields**:
- `street`: String
- `city`: String
- `state`: String
- `country`: String
- `postalCode`: String

### LatLng
**Fields**:
- `latitude`: double
- `longitude`: double

### ContactInfo
**Fields**:
- `phone`: String
- `email`: String
- `website`: String

### Guest
**Fields**:
- `firstName`: String
- `lastName`: String
- `email`: String
- `isPrimary`: bool

### PaymentRecord
**Fields**:
- `id`: String
- `method`: PaymentMethod (CreditCard, DebitCard, PayPal, etc.)
- `amount`: double
- `currency`: String
- `status`: PaymentStatus (Pending, Completed, Failed, Refunded)
- `transactionId`: String
- `processedAt`: DateTime

### UserPreferences
**Fields**:
- `preferredCurrency`: String
- `priceRange`: PriceRange
- `preferredAmenities`: List<String>
- `roomTypePreference`: RoomType

## Enumerations

### UserRole
- Guest (search only)
- RegisteredUser (search, book, manage)
- Admin (full system access)

### BookingStatus
- Pending (awaiting confirmation)
- Confirmed (booking confirmed)
- CheckedIn (guest has arrived)
- CheckedOut (stay completed)
- Cancelled (booking cancelled)

### PaymentStatus
- Pending (payment processing)
- Completed (payment successful)
- Failed (payment declined)
- Refunded (payment reversed)

### PaymentMethod
- CreditCard
- DebitCard
- PayPal
- ApplePay
- GooglePay

### RoomType
- Standard
- Deluxe
- Suite
- Presidential

### LoyaltyLevel
- Bronze
- Silver
- Gold
- Platinum

## State Transitions

### Booking Lifecycle
1. **Pending** → **Confirmed** (payment successful)
2. **Pending** → **Cancelled** (payment failed or user cancellation)
3. **Confirmed** → **CheckedIn** (guest arrival)
4. **Confirmed** → **Cancelled** (cancellation before arrival)
5. **CheckedIn** → **CheckedOut** (guest departure)

### Payment Lifecycle
1. **Pending** → **Completed** (successful processing)
2. **Pending** → **Failed** (processing error)
3. **Completed** → **Refunded** (cancellation refund)

## Data Relationships Summary

```
Hotel (1) ←→ (N) Room
Hotel (1) ←→ (N) Review
User (1) ←→ (N) Booking
User (1) ←→ (N) Review
Room (1) ←→ (N) Booking
Booking (1) ←→ (1) PaymentRecord
Booking (1) ←→ (0..1) Review
```

## Mock Data Requirements

### Volume Specifications
- Hotels: 50+ properties across 10+ cities
- Rooms: 5-15 rooms per hotel (250+ total)
- Users: 100+ mock users across all roles
- Bookings: 500+ historical and future bookings
- Reviews: 800+ reviews with realistic rating distributions

### Data Quality Requirements
- Realistic hotel names and descriptions
- Valid geographic coordinates for major cities
- Diverse room types and pricing ranges
- Authentic-sounding guest reviews
- Proper seasonal pricing variations
- Edge cases: sold out periods, payment failures, cancellations