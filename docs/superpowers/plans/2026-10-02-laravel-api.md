# RentGear Laravel API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [x]`) syntax for tracking. The owner asked for a short plan and native execution, so tasks
> list files, interfaces and tests instead of full code.

**Goal:** A Laravel server that stores RentGear data and enforces the same rules as the Flutter app, plus a Flutter
repository that talks to it.

**Architecture:** REST JSON under `/api/v1`, one endpoint per `RentGearRepository` operation. Business rules live in
plain PHP classes under `app/Domain/`, ported from the tested Dart files. Controllers stay thin; services own database
transactions. The Flutter app picks local or server data at build time.

**Tech Stack:** PHP 8.5, Laravel (latest stable), Sanctum, MySQL for running, SQLite in memory for tests, PHPUnit.
Flutter side: `http` package.

**Spec:** `docs/superpowers/specs/2026-10-01-laravel-api-design.md`

## Global Constraints

- Code lives in `rentgear_api/` in this repo.
- JSON keys are camelCase and match the Dart field names in `rentgear_app/lib/domain/models.dart`.
- Ids are strings. Seed rows keep the Dart ids (`u-budi`, `p-arjuna`, `e-dome4`, `r-1`); new rows get ULIDs.
- Errors: `{ "success": false, "error": { "code": "...", "message": "..." } }`, same codes and Indonesian messages as
  `AppException` in the Dart repository. HTTP status: 401 `AUTH_FAILED`/unauthenticated, 403 `FORBIDDEN` and
  `BLACKLISTED`, 404 `NOT_FOUND`, 409 `INVALID_TRANSITION`, `INVALID_STATE`, `SLOT_UNAVAILABLE`,
  `ALREADY_REVIEWED`, `DAMAGE_REVIEW_PENDING`, 422 for the rest.
- Success: `{ "success": true, "data": ... }`.
- Dates of a rental are calendar dates (`YYYY-MM-DD`). Timestamps are ISO 8601.
- Guarantee document numbers are stored encrypted; the API only returns the masked form.
- Money is computed on the server. The client never sends prices.

## Review Focus

1. Two bookings for the last unit at the same time: exactly one succeeds (`SLOT_UNAVAILABLE` for the other).
2. A provider calling an action on another store's rental gets 403, never a state change.
3. A repeated `POST rentals` with the same `Idempotency-Key` returns the first booking and creates nothing.
4. A guarantee photo or payment proof requested by a user who is not the renter, the store owner or an admin: 403.
5. Late fee uses the server's calendar date, so a client with a wrong clock cannot change it.

---

### Task 1: Project, database and seed

**Files:** create `rentgear_api/` (Laravel skeleton), `database/migrations/*`, `app/Models/*`,
`database/seeders/DemoSeeder.php`, `tests/Feature/SeedTest.php`.

**Produces:** tables `users`, `providers`, `categories`, `equipment`, `equipment_sizes`, `equipment_photos`,
`rentals`, `rental_status_logs`, `guarantees`, `reviews`, `follows`, `blacklist_entries`, `idempotency_keys`,
`personal_access_tokens` (string `tokenable_id`). Eloquent models with string keys.

- [x] Create the project with Composer, install Sanctum API scaffolding, point `.env` at MySQL `rentgear`.
- [x] Write `SeedTest`: after seeding there are 6 users, 3 providers, 6 categories, 9 equipment rows, 6 rentals,
      6 reviews, 1 follow. Run it, see it fail.
- [x] Write migrations, models and `DemoSeeder` (same data as `rentgear_app/lib/data/seed.dart`, photos copied from
      `rentgear_app/assets/equipment/` into the public disk). Run the test, see it pass.

### Task 2: Domain rules

**Files:** `app/Domain/Availability/AvailabilityService.php`, `app/Domain/Rental/RentalStatus.php`,
`app/Domain/Rental/RentalStateMachine.php`, `app/Domain/Rental/PriceCalculator.php`,
`app/Domain/Fines/FineCalculator.php`, `app/Domain/Fines/BlacklistPolicy.php`,
`app/Domain/Guarantee/GuaranteeType.php`, `app/Domain/Guarantee/GuaranteePolicy.php`, `app/Domain/DomainException.php`,
tests in `tests/Unit/Domain/`.

**Produces:**
- `AvailabilityService::peakOccupancy(array $ranges, string $start, string $end): int` and
  `::available(int $stock, array $ranges, string $start, string $end): int`; a range is `[start, end, qty]`.
- `RentalStateMachine::guardError(RentalStatus $from, RentalStatus $to, ?string $actorRole, array $guaranteeStatuses): ?string`
  and `RentalStateMachine::LOCKING`.
- `FineCalculator::lateDays`, `::lateFee`, `::damageFeeError`, `::needsAdminReview`.
- `BlacklistPolicy::shouldAutoBlacklist(int $violations, int $baseline): bool`.
- `GuaranteePolicy::validate(array $drafts, float $rentalValue, string $renterName): array` and `::mask(string): string`.

- [x] Port the Dart test cases from `test/domain_test.dart` and the formula group of `test/fines_test.dart` to
      PHPUnit. Run, see them fail.
- [x] Port the classes. Run, see them pass.

### Task 3: Auth, catalog and stores

**Files:** `routes/api.php`, `app/Http/Controllers/Api/V1/{Auth,Catalog,Store}Controller.php`,
`app/Http/Resources/*`, `app/Support/ApiResponse.php`, `bootstrap/app.php` (JSON error rendering),
`tests/Feature/{Auth,Catalog,Store}Test.php`.

**Produces:** `POST auth/login`, `POST auth/logout`, `GET auth/me`, `GET categories`, `GET equipment`,
`GET equipment/{id}`, `GET equipment/{id}/availability`, `GET providers`, `GET providers/{id}`,
`GET providers/{id}/equipment`, `GET providers/{id}/reviews`, `PUT|DELETE providers/{id}/follow`, `GET me/follows`.

- [x] Feature tests first: login success and failure, hidden gear (inactive or unverified store) is not listed,
      availability uses peak occupancy, store rating equals the review average, follow is idempotent and customer-only.
- [x] Implement, run tests.

### Task 4: Booking and the rental flow

**Files:** `app/Services/BookingService.php`, `app/Services/RentalFlowService.php`,
`app/Http/Controllers/Api/V1/{Rental,File}Controller.php`, `tests/Feature/{Booking,RentalFlow,Access}Test.php`.

**Produces:** `POST rentals`, `GET rentals`, `GET rentals/{id}`, guarantee review, confirm, reject, cancel, payment,
handover, return, complete, `GET files/guarantees/{gid}`, `GET files/payments/{rentalId}`.

- [x] Feature tests first: full lifecycle, booking without a guarantee refused, high-value booking needs two
      documents, idempotency key, double booking blocked, another provider gets 403, file access rules, size rules.
- [x] Implement with a DB transaction and `lockForUpdate` on the equipment row. Run tests.

### Task 5: Fines, blacklist, reviews, provider and admin actions

**Files:** extend `RentalFlowService`, add `app/Services/{Blacklist,Store}Service.php`,
`app/Http/Controllers/Api/V1/{Admin,ProviderEquipment}Controller.php`, `tests/Feature/{Fines,Blacklist,Review,Equipment}Test.php`.

**Produces:** return with condition and damage fee, `damage-objection`, `damage-decision`, `rentals/{id}/review`,
`GET customers`, `PUT|DELETE customers/{id}/blacklist`, `GET me/blacklist`, `PUT providers/{id}/status`,
`POST equipment`, `POST equipment/{id}`, `PUT provider/guarantee-policy`.

- [x] Feature tests first, mirroring `test/fines_test.dart` and `test/store_test.dart`.
- [x] Implement, run tests.

### Task 6: Scheduled jobs

**Files:** `app/Console/Commands/RunRentalJobs.php`, `routes/console.php`, `tests/Feature/JobsTest.php`.

- [x] Test first: with the clock moved forward, pending becomes expired, awaiting payment becomes cancelled, paid
      becomes no-show, picked up becomes overdue, and a second run changes nothing.
- [x] Implement `rentgear:run-jobs`, schedule it every ten minutes. Run tests.

### Task 7: Flutter HTTP repository

**Files:** `rentgear_app/lib/data/http_repository.dart`, `rentgear_app/lib/data/api_codec.dart`,
`rentgear_app/lib/core/config.dart`, `rentgear_app/lib/domain/models.dart` (`NetworkPhoto`),
`rentgear_app/lib/widgets/photo_widgets.dart`, `rentgear_app/lib/main.dart`, `rentgear_app/test/http_repository_test.dart`.

- [x] Tests first with `MockClient`: JSON to model mapping for a rental, error envelope becomes `AppException` with
      the same code, network failure becomes `AppException('NETWORK', ...)`, token header is sent after login.
- [x] Implement. `--dart-define=API_URL=...` selects the HTTP repository; without it the app stays local.
- [x] `flutter analyze` and `flutter test` stay green.

### Task 8: End to end

- [x] Start MySQL and `php artisan serve`, seed, run the Flutter web build against it in Chrome as a customer and as
      a provider, complete one booking through confirmation and payment. Record the result in `HANDOFF.md`.
