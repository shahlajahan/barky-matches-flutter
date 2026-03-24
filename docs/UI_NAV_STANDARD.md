# BarkyMatches UI & Navigation Standard

این سند «قانون رسمی پروژه» است. هر صفحه جدید باید یکی از Typeهای زیر باشد.
هدف: جلوگیری از باگ‌های تکراری AppBar/BottomNav/Overlay/SubPage و حذف آزمون‌وخطا.

---

## Terminology

- **Tab Page**: صفحه‌ای که داخل BottomNav نمایش داده می‌شود.
- **Overlay**: لایه‌ای که روی Tab سوار می‌شود (مثل Notifications).
- **SubPage**: زیرصفحه داخل یک Tab بدون Navigator.push (مثل Profile -> Saved Parks).
- **Detail Route**: صفحه‌ای که با Navigator.push باز می‌شود (مثل Scheduling).

---

## TYPE A — Tab Page (BottomNav Pages)

مثال:
- HomePage, FavoritesPage, VetPage, PlayDateRequestsPageNew, UserProfilePage

قوانین:
- ❌ Scaffold ممنوع
- ❌ AppBar ممنوع
- ❌ BottomNavigationBar ممنوع
- ✅ فقط Body
- ✅ Background از AppTheme.bg
- ✅ SafeArea(top: false)

علت:
AppBar و BottomNav فقط باید در BarkyScaffold ساخته شوند.

---

## TYPE B — Overlay (UI-only)

مثال:
- NotificationsPage
- ParkPlaydateEntryView

قوانین:
- ❌ Scaffold ممنوع
- ❌ BottomNav ممنوع
- ✅ UI-only
- ✅ بستن فقط با AppState (closeOverlay/closeNotifications/closeHomeOverlay)
- ✅ اگر روی کل صفحه tap می‌شود و باید بسته شود → GestureDetector در ریشه

نکته:
Overlay نباید Route جدید push کند مگر در قالب یک FlowManager کنترل‌شده.

---

## TYPE C — SubPage داخل Tab

مثال:
- SavedParksPage داخل UserProfilePage

قوانین:
- ❌ Navigator.push ممنوع
- ❌ Scaffold ممنوع
- ✅ کنترل نمایش فقط با AppState.profileSubPage
- ✅ Back فقط با appState.closeProfileSubPage()

نکته:
SubPage باید Material داشته باشد اگر TextField/InkWell استفاده می‌کند.

---

## TYPE D — Detail Route (Navigator.push)

مثال:
- PlayDateSchedulingPage
- AddDogPage
- DogDetailsPage

قوانین:
- ✅ Scaffold دارد
- ✅ AppBar دارد
- ❌ BottomNav ندارد
- ✅ Navigator.push مجاز

---

## Golden Rules

1) AppBar و BottomNav فقط در BarkyScaffold
2) هیچ صفحه Tab نباید Scaffold بسازد
3) Overlay فقط UI است و state-driven
4) هر Flow چندمرحله‌ای باید با FlowManager باشد (نه دستکاری پراکنده state)

---

## Checklist قبل از Merge

- [ ] صفحه جدید یکی از Typeهاست؟
- [ ] رنگ‌ها از AppTheme هستند؟
- [ ] هیچ Scaffold در Tab Page نیست؟
- [ ] SubPage هیچ Navigator.push ندارد؟
- [ ] Flow جدید از FlowManager استفاده می‌کند؟



---

# 🐾 BarkyMatches UI & Navigation Standard (Business-Ready Edition)

این سند «قانون رسمی پروژه» است.
هر صفحه جدید باید دقیقاً یکی از Typeهای زیر باشد.

هدف:

* جلوگیری از تداخل Navigation
* جلوگیری از Scaffold تکراری
* جلوگیری از Overlay crash
* جلوگیری از Business state duplication

---

# Terminology

* **Tab Page**: صفحه‌ای که داخل BottomNav نمایش داده می‌شود.
* **Overlay**: لایه‌ای که روی Tab سوار می‌شود (state-driven, route نیست).
* **SubPage**: زیرصفحه داخل یک Tab بدون Navigator.push.
* **Detail Route**: صفحه‌ای که با Navigator.push باز می‌شود.
* **Business**: هر موجودیت خدماتی (Vet / Adoption / Groomer / PetShop).

---

# TYPE A — Tab Page (BottomNav Pages)

مثال:

* HomePage
* FavoritesPage
* VetPage
* AdoptionPage (future)
* PlayDateRequestsPageNew
* UserProfilePage

قوانین:

* ❌ Scaffold ممنوع
* ❌ AppBar ممنوع
* ❌ BottomNavigationBar ممنوع
* ✅ فقط Body
* ✅ Background از `AppTheme.bg`
* ✅ `SafeArea(top: false)`
* ✅ کنترل نمایش Overlay فقط با AppState

علت:
AppBar و BottomNav فقط باید در `BarkyScaffold` ساخته شوند.

---

# TYPE B — Overlay (UI-only, State Driven)

مثال:

* NotificationsPage
* ParkPlaydateEntryView
* BusinessDetailOverlay

قوانین:

* ❌ Scaffold ممنوع
* ❌ BottomNav ممنوع
* ❌ Navigator.push ممنوع
* ✅ فقط UI
* ✅ بستن فقط از طریق AppState
* ✅ اگر tap خارج برای بستن نیاز است → GestureDetector در root

Overlay هرگز route جدید push نمی‌کند.

---

# TYPE C — SubPage داخل Tab

مثال:

* SavedParksPage
* Business Appointment Page

قوانین:

* ❌ Navigator.push ممنوع
* ❌ Scaffold ممنوع
* ❌ AppBar ممنوع
* ✅ فقط Body
* ✅ Back فقط با AppState
* ✅ mounted check بعد از async

SubPage باید اگر TextField یا InkWell دارد → Material داشته باشد.

---

# TYPE D — Detail Route (Navigator.push)

مثال:

* PlayDateSchedulingPage
* AddDogPage
* DogDetailsPage

قوانین:

* ✅ Scaffold دارد
* ✅ AppBar دارد
* ❌ BottomNav ندارد
* ✅ Navigator.push مجاز

---

# 🟣 Business Architecture (Official Pattern)

از این لحظه به بعد:

هیچ state اختصاصی برای Vet یا Adoption ساخته نمی‌شود.

---

## Business Data Contract

تمام Businessها باید به این مدل تبدیل شوند:

```
BusinessCardData
```

هیچ Widget جدید با data اختصاصی نساز.

VetCardData فقط:

```
class VetCardData extends BusinessCardData
```

است و state جدید ندارد.

---

## Business State Contract (AppState)

تنها state مجاز برای Business:

```
BusinessSubPage
BusinessCardData? activeBusiness
BusinessCardData? businessAppointment
```

متدهای مجاز:

```
openBusinessDetails()
closeBusinessDetails()
openBusinessAppointment()
closeBusinessAppointment()
```

🚫 VetSubPage ممنوع
🚫 activeVet ممنوع
🚫 openVetAppointment ممنوع

---

## Business Overlay Flow (Official)

```
BusinessCard tap
    ↓
openBusinessDetails()
    ↓
BusinessDetailOverlay
    ↓
openBusinessAppointment()
    ↓
BusinessSubPage.appointment
```

هیچ Navigator.push در این Flow وجود ندارد.

---

## Business Tab Implementation Pattern

هر Tab که Business دارد باید این الگو را رعایت کند:

1. اگر SubPage فعال است → SubPage را نشان بده
2. در غیر این صورت لیست را نشان بده
3. اگر activeBusiness != null → Overlay را نشان بده

هیچ Route push نباید در Tab اتفاق بیفتد.

---

# 🔵 Notification & Overlay Interaction Rule

* تغییر Tab → همه Overlayها بسته شوند
* Overlay هرگز Tab را تغییر نمی‌دهد
* Notification Tap → فقط AppState را تغییر می‌دهد

UI هیچ تصمیم Navigation نمی‌گیرد.

---

# 🔵 Playdate Flow Rule

Playdate فقط از طریق:

```
activePlaydatePark
selectedRequesterDogId
```

مدیریت می‌شود.

هیچ state ثانویه ایجاد نکن.

---

# 🔵 Profile SubPage Rule

تنها SubPage رسمی Profile:

```
ProfileSubPage
```

Back فقط:

```
closeProfileSubPage()
```

---

# 🔵 AppState Ownership Rule

AppState تنها منبع حقیقت است برای:

* Navigation state
* Overlay state
* SubPage state
* Business state
* Playdate flow
* Lost/Found detail
* Notification routing

هیچ Widget نباید state navigation داخلی نگه دارد.

---

# Golden Rules (Expanded)

1. AppBar و BottomNav فقط در BarkyScaffold
2. هیچ TabPage نباید Scaffold بسازد
3. Overlay فقط UI است
4. Business state فقط generic است
5. هیچ Vet-specific navigation وجود ندارد
6. هیچ SubPage route push نمی‌کند
7. AppState تنها منبع navigation truth است
8. Tab switch → Overlay بسته می‌شود
9. Async submit → قبل از close بررسی mounted

---

# Anti-Patterns (ممنوع مطلق)

❌ Scaffold داخل VetPage
❌ Navigator.push برای Appointment
❌ VetSubPage enum
❌ AdoptionSubPage enum
❌ activeVet
❌ openVetDetails
❌ Business-specific state duplication
❌ Overlay که route push کند

---

# Business Expansion Rule (Future Proof)

برای اضافه کردن Business جدید:

1. مدل آن را به BusinessCardData map کن
2. از BusinessCard استفاده کن
3. از BusinessDetailOverlay استفاده کن
4. از BusinessSubPage.appointment استفاده کن

هیچ state جدید ساخته نشود.

---

# Checklist قبل از Merge

* [ ] صفحه جدید یکی از Typeهاست؟
* [ ] Scaffold در Tab وجود ندارد؟
* [ ] Overlay فقط state-driven است؟
* [ ] SubPage Navigator.push ندارد؟
* [ ] Business state فقط generic است؟
* [ ] Tab switch overlay را می‌بندد؟
* [ ] mounted بعد از async بررسی شده؟

---

# نتیجه این استاندارد

* هیچ unmounted context crash
* هیچ duplicate navigation state
* هیچ Business refactor آینده
* اضافه شدن Adoption بدون تغییر AppState
* اضافه شدن Groomer بدون تغییر Overlay

---


