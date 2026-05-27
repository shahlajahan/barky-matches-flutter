# Firebase Architecture

## Firebase Components

- Firebase Auth
- Cloud Firestore
- Cloud Functions
- Firebase Storage
- Firebase Messaging
- Firebase Analytics
- App Check

## Important Files

- `firebase.json`
- `firestore.rules`
- `storage.rules`
- `functions/index.js`
- `lib/services/`

## Main Collections

Detected / expected collections:

- `users`
- `businesses`
- `vet_appointments`
- `groomy_appointments`
- `hotel_bookings`
- `notifications`
- `subscriptions`
- `reviews`
- `business_chats`
- `orders`
- `order_returns`
- `products`
- `adoption_requests`
- `adoption_listings`
- `lost pets / lost dog reports`
- `found pets / found dog reports`
- `medical_records`

## Firebase Usage by Module

### Users

Used for:
- authentication profile
- role data
- subscription state
- language/preferences
- business ownership links

### Businesses

Used for:
- vet profiles
- groomy profiles
- pet hotel profiles
- petshop profiles
- adoption center profiles
- pet taxi profiles

### Appointments / Bookings

Used for:
- veterinary appointments
- groomy appointments
- pet hotel bookings

### Medical Records

Used for:
- pet medical profile
- visit history
- vaccine data
- allergies / chronic conditions
- vet-patient relationship

Risk:
- avoid storing unlimited visit history in one document
- prefer subcollections for long-term records

### Business Chat

Used for:
- user ↔ business messaging
- vet inbox
- user inbox
- quick replies

Risk:
- unread counters can create contention
- push notification backend must be verified

### Marketplace

Used for:
- products
- carts
- orders
- returns
- seller orders

Risk:
- payment gateway must be production verified

## Security Risks to Review

- role-based write access
- business owner verification
- medical record write permissions
- chat sender/receiver verification
- order/return ownership
- admin-only operations
- storage upload permissions

## Recommended Firebase Improvements

P0:
- Verify Firestore rules for medical records
- Verify business ownership checks
- Use subcollections for visit history and chat messages
- Validate order/return permissions

P1:
- Add backend validation for critical writes
- Move important transitions to Cloud Functions
- Add server-side notification triggers

P2:
- Add analytics events
- Add admin audit logs
- Add automated cleanup jobs where needed