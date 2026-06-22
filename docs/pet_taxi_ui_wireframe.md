# 🐾 Pet Taxi V2 UI / UX Wireframe

No implementation should start before the documentation is updated.

Status: Planning

Version: 2.0

Owner: Petsupo

Last Updated: 2026-06-22

---

# Philosophy

Pet Taxi is not a directory.

Pet Taxi is a real-time transportation service.

Inspired by:

- Uber
- BiTaksi

Designed for:

Pet Owners

---

# UX Principles

✅ Map First

✅ One Primary Action

✅ Minimal Inputs

✅ Live Experience

❌ Business List

❌ Card Browsing

❌ Complex Forms

---

# Navigation

Bottom Navigation

Pet Taxi

↓

PetTaxiPage

↓

Full Screen Map

↓

Bottom Sheet

---

# Screen 1

Idle State

```

```
┌────────────────────────────────────┐

🗺️

🚐

        🚐

              📍You

🚐

────────────────────────────────────

            Pet Taxi

Safe transportation
for your best friend

────────────────────────────────────

Pickup

Current Location

────────────────────────────────────

Destination

Where are you going?

────────────────────────────────────

Pet

Beni

────────────────────────────────────

Request Pet Taxi

└────────────────────────────────────┘
```

---

# Screen 2

Destination Selected

```
🗺️

🚐

🚐

──────────────

Pickup

Current Location

Destination

Happy Vet Clinic

Pet

Beni

Request Ride

```

---

# Screen 3

Searching

```
🗺️

🚐

🚐

🚐

────────────────────────

Searching nearby drivers

🐾🐾🐾

Please wait...

Cancel

```

---

# Screen 4

Driver Accepted

```
🗺️

🚐────────────📍

────────────────────────

Driver

Ahmet

⭐ 4.9

White Pet Van

ETA

5 min

Call

Message

Cancel

```

---

# Screen 5

Ride Started

```
🗺️

🚐────────────🏥

────────────────────────

Beni is on the way

ETA

11 min

```

---

# Screen 6

Ride Completed

```
🎉

Ride completed

⭐⭐⭐⭐⭐

Rate your driver

```

---

# Bottom Sheet States

Idle

DestinationSelected

Searching

DriverAccepted

RideStarted

RideCompleted

---

# Floating Buttons

Right

📍 Current Location

Left

📋 My Rides

---

# Driver Markers

Custom Petsupo Marker

White Van

Pink Accent

Paw Icon

---

# Map Layers

GoogleMap

↓

Driver Layer

↓

Route Layer

↓

User Layer

↓

Floating Buttons

↓

Bottom Sheet

---

# Animations

Driver Movement

Bottom Sheet Expand

Bottom Sheet Collapse

Camera Move

Marker Fade

Polyline Draw

---

# Empty States

No drivers nearby

Searching timeout

Location permission denied

GPS disabled

Network offline

---

# Future Features

Scheduled Ride

Favorite Driver

Promo Code

Share Live Ride

Emergency Contact

Multiple Stops

Pet Notes
