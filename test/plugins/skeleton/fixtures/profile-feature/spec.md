# Feature: Profile Feature

## Key Entities

- **User** — the profile owner
  - id: String
  - displayName: String
  - email: String?
  - age: int
  - rating: double
  - isActive: bool
  - tags: List<String>
  - meta: Map<String, dynamic>
  - createdAt: DateTime
- **Post** — content authored by the user
  - id: String
  - title: String

## Requirements

- Users own their profile
- Posts belong to a User
