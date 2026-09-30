# RentGear — Handoff (updated 2026-09-30)

Status of the Android app and web build so the next session can pick up where this one stopped.

## Current state

- `flutter analyze`: no issues. `flutter test`: 30 tests pass.
- Standalone Android app with no server. Data is saved on the phone through
  `LocalRentGearRepository` + `LocalStore` (JSON + photo files, schema version 2).
- Test phone: **REDMI 17** (HyperOS) over USB debugging, adb serial `AIFMWOTWAMMRJBPR`,
  screen 720×1600. "Install via USB" is on; accept the install pop-up on the phone.
- Specimen images pushed to the phone gallery (`/sdcard/Pictures/`):
  `rentgear_ktp_spesimen.jpg`, `rentgear_bukti_transfer_spesimen.jpg`,
  `rentgear_sepatu_trail.jpg`.
- Helper for driving the phone: `tool/adb_drive.sh <shot-name> tap X Y | text S | key K | swipe X1 Y1 X2 Y2 | wait N`
  (text uses `%s` for spaces; screenshots saved to `$SHOT_DIR` or `/tmp`).

## Done this session

- Real product photos (Wikimedia Commons, CC0/CC BY/CC BY-SA/PD) in `assets/equipment/`,
  credits in `assets/equipment/credits.json`, shown in Profil → Kredit foto.
- Photo gallery on the detail page (swipe, counter, full screen with zoom); photo thumbnails in the catalog and on rental cards.
- Shoe sizes: `Equipment.sizes` (`SizeStock`), stock and ALG-2 availability tracked per size,
  size picker on the booking screen with remaining stock per size, `Rental.size`.
- Provider: add/edit equipment (`equipment_form_screen.dart`) with photos (camera/gallery,
  set main photo, delete), per-size stock, a "show in catalog" toggle, and validation (`equipment_rules.dart`).
- UX/bug fixes: catalog search debounce with no flicker, keyboard no longer reappears by itself
  (`dismissKeyboard`), leave-confirmation on the booking and equipment forms, NIK field accepts digits only (16),
  guarantee/payment photos open full screen with zoom, payment proof preview with a "Ganti foto" option,
  bank account shown in "Cara bayar", confirmation before receiving a return, confirm button stays off until
  guarantees are verified, hint when a guarantee is rejected, right-aligned `InfoRow`, tidier `RentalCard`,
  short date ranges ("27–28 Sep 2026"), demo login chips for both providers.

## Verified on the phone (passed)

1. Customer: catalog with photos → shoe detail (swipe gallery) → booking: dates, size 42,
   KTP + **camera photo** → **replaced with a gallery photo** → submit. The leave dialog appears.
2. Provider Semeru (dewi@rentgear.id): view the KTP photo → Valid → Konfirmasi.
3. Customer: upload proof of payment from the gallery → preview → Kirim → status "Siap diambil".
4. Provider: handover (guarantee held) → receive return → return guarantee → **Selesai**. Full log shown.

## Session 2 (2026-09-25, Android emulator Pixel_10, 1080x2424)

The user asked to continue on the emulator for now. `tool/adb_drive.sh` now reads
`ADB_SERIAL` (default: the Redmi serial), e.g. `ADB_SERIAL=emulator-5554 tool/adb_drive.sh ...`.
Specimen photos were pushed to the emulator's `/sdcard/Pictures/` too.

Verified on the emulator (passed):
- Provider "Tambah alat": gallery photo, category Sepatu, sizes 40/41/42 with stock, price, deposit,
  weight → saved, shown in "Alat Saya" and in the customer catalog with photo and "Ukuran 40–42".
- Edit an item: "Jadikan foto utama" and hiding it from the catalog ("Disembunyikan" badge; the item
  no longer shows up in customer search).
- Aturan Jaminan screen; policy changes show in the booking form and in admin's provider list.
- Booking with size 41 + KTP from gallery → provider rejects the KTP (reason shown) → rejects the booking
  → status "Ditolak" with the reason and history.
- Admin: dashboard, verifying Puncak Outdoor, all transactions. Kredit foto. Reset data demo.
- Large system font (font_scale 1.3): provider tabs, Aturan Jaminan, Alat Saya, login all fit.

Fixed this session:
- Aturan Jaminan: helper text under "Batas sewa bernilai tinggi" was cut off (now 2 lines); the threshold
  field accepts digits only; the warning now lists only the hard-to-replace documents actually selected
  (it always said "Ijazah, paspor, KK, dan BPKB").
- Equipment detail: weight uses a decimal comma ("1,2 kg").
- Rental detail (provider): the booking reject button is now "Tolak booking" (two plain "Tolak" buttons were
  ambiguous); the disabled confirm button reads "Jaminan ditolak — tidak bisa dikonfirmasi".
- Admin dashboard: stat labels can wrap to 2 lines (large font cut "Penyedia menunggu").

## Session 3 (2026-09-27, real Redmi 17 with a fresh debug APK)

Built and installed with `flutter build apk --debug` + `adb install -r`. `flutter analyze` is clean and all
29 tests pass. The emulator was not running; all checks were on the Redmi.

Verified on the phone (passed):
- Catalog with photos, detail page (gallery 1/3, "3,2 kg"), booking form.
- "Keluar" asks for confirmation. Leaving a filled equipment form shows "Buang perubahan?".
- Money field "Sewa per hari" shows thousand dots while typing ("Rp 45.000").
- Provider profile shows the shop card (name, address, "Terverifikasi", BCA account).
- Full flow, invoice INV-20260927-0002 (Tenda Dome, 28-29 Sep, KTP specimen from the gallery):
  customer books (status "Menunggu konfirmasi", NIK masked) -> provider Arjuna marks the guarantee Valid and confirms
  ("Menunggu pembayaran") -> customer uploads the payment proof from the gallery ("Siap diambil") -> provider handover
  ("Sedang disewa") -> receive return ("Sudah dikembalikan") -> return guarantee ("Selesai"). Status history is complete.

Rejection path on the phone (passed), invoice INV-20260927-0003 (Tenda Dome, 29-30 Sep):
- Provider rejects the KTP with a note: guarantee shows "Ditolak" plus the note, a red hint tells the provider to reject
  the booking, and the confirm button stays off ("Jaminan ditolak — tidak bisa dikonfirmasi").
- Provider "Tolak booking" with a reason: status "Ditolak"; the reason shows on the detail card and in the status history,
  for both provider and customer.
- After the rejection the same dates (29-30 Sep) could be booked again, so the stock is released.

Admin flow on the phone (passed, `admin@rentgear.id`):
- Dashboard: 9 total transactions (matches the data), 1 active, 1 guarantee held, 1 provider waiting, Rp260.000 completed rental value.
- Penyedia: "Verifikasi Puncak Outdoor?" dialog (button on one line) -> badge changes to "Terverifikasi" and a snackbar shows.
- Transaksi: all transactions listed with the right status (Dibatalkan, Ditolak, Selesai); the detail page of a completed
  rental shows the full history and no action buttons. Profil and Kredit foto open fine.
- Not checked by hand: whether the Rp260.000 figure is the exact sum of completed rentals (sewa only, no deposit).

Large font on the phone (system `font_scale` 1.3, set with `adb shell settings put system font_scale 1.3`; the original value
1.0 was restored afterwards):
- Fits: login, catalog, equipment detail, booking form, provider tabs (Pesanan, Alat, Jaminan, Profil), Admin dashboard, Penyedia,
  Transaksi, Kredit foto, the "Keluar" dialog.
- Found and fixed: the Admin dashboard stat cards overflowed by 8.8 px ("BOTTOM OVERFLOWED BY 8.8 PIXELS") on this
  narrower screen, because the grid used a fixed aspect ratio. `lib/features/admin/admin_shell.dart` now uses
  `mainAxisExtent: 56 + 72 * textScale`. Rechecked on the phone: two-line labels fit.
- Found and fixed: the helper text "Harus sama dengan nama akun penyewa" (`lib/widgets/guarantee_widgets.dart`) was cut with an
  ellipsis; `helperMaxLines: 2` now shows it in full.
- Checked and fine: the "Serah terima", "Terima pengembalian" and "Kembalikan jaminan" dialogs.
- Found and fixed: in "Tambah Alat" the two-column rows (Sewa/Deposit, Berat/Kapasitas) cut labels to "Sewa per h…" etc.
  `lib/features/provider/equipment_form_screen.dart` now has a `_fieldPair` helper that stacks the two fields vertically
  once the system text scale is above 1.15, instead of always splitting them into two `Expanded` columns.
- `flutter analyze` clean, 30 tests pass. Verified INV values against `lib/data/seed.dart`: sewa 40.000x1x2 (sepatu) +
  90.000 (tenda) + 15.000x2x3 (sleeping bag) = Rp260.000 completed, matching the Admin dashboard.
- Demo data was reset (Profil -> "Reset data demo") after this session's tests; font_scale restored to 1.0.

Fixed after the rejection test:
- `askReason` (`lib/widgets/common.dart`, used by "Tolak KTP", "Tolak booking", "Batalkan booking") ignored "Kirim" silently when
  the reason was empty. "Kirim" is now disabled until the reason has text (spaces only do not count).
  Test: `test/ask_reason_test.dart`. Checked on the phone with "Batalkan booking" (INV-20260927-0004, status "Dibatalkan"
  with the reason shown). `flutter analyze` clean, 30 tests pass.

Observed, not fixed:
- Two dialog taps sent over adb did not register (first tap on "Serah terima", and one tap on "Terima pengembalian"
  opened the phone Settings app instead). A retry worked both times. Cause not found; probably adb or a system overlay, not the app.
- The "Kembalikan jaminan" dialog puts its confirm button on its own line ("Sudah dikembalikan"); see "Nice to have" below.
- The payment proof specimen says Rp 170.000 while the bill is Rp 190.000. The app does not compare amounts in this version.
- (Resolved) Test data was cleared with "Reset data demo" at the end of this session. Use "Reset data demo" in Profil to clear it.
- Button positions differ per dialog, so take a screenshot before tapping a dialog button through `tool/adb_drive.sh`.

## Session 4 (2026-09-27, animations)

Used the `find-animation-opportunities` skill's gate (frequency / purpose / speed / function) on the whole app, translated
to Flutter idioms (no CSS/JS in this codebase). New shared file `lib/widgets/motion.dart`:

- `AppMotion`: shared durations/curves (fast 160ms, standard 220ms, entrance 260ms, delight 500ms).
- `FadeSlideIn`: fade + 14px slide-up, once, for list items; `FadeSlideIn.stagger(i)` staggers by 35ms per item, capped
  at 8 items so a long list doesn't make the last card wait. Skips the animation when the system's reduced-motion
  setting is on.
- `StatusCrossfade`: fade+scale swap (220ms) so a status badge changes instead of teleporting.
- `CompletionDot`: a plain dot for every status-history entry, except the freshest one when it is "Selesai" — that one
  pops in with `Curves.elasticOut` over 500ms (the one delight beat).

Applied:
- `StatusPill` (`lib/widgets/common.dart`) now crossfades — covers the badge on `RentalDetailScreen` and every `RentalCard`.
- List entrance stagger on: catalog (`catalog_screen.dart`), "Sewa Saya" / provider "Pesanan" / admin "Semua Transaksi"
  (they share `RentalList` in `my_rentals_screen.dart`), provider "Alat Saya" (`provider_equipment_screen.dart`), and
  admin "Verifikasi Penyedia" (`admin_shell.dart`), which also got `StatusCrossfade` on the provider status badge.
- "Riwayat status" in `rental_detail_screen.dart` uses `CompletionDot`; the check only plays on the latest entry when
  a transaction lands on "Selesai".

Deliberately not animated (documented per the skill's rejection format):
- Bottom `NavigationBar` tab switches — core navigation, tapped 100+ times/day; Material already gives the selection
  pill its own quick animation, adding more would slow down the one interaction users repeat most.
- Dialogs (`confirmDialog`, `askReason`) and `SnackBar`s — Flutter's `Dialog`/`SnackBar` already animate; a second
  layer of motion on top would fight the framework's own timing.
- Money fields formatted live by `RibuanInputFormatter` — functional data the user is actively typing/reading; motion
  here would only make input feel laggy.
- `ChoiceChip` category selection in the catalog — Material's `ChoiceChip` already animates its own selection state.

Verified on the Redmi with this build: catalog/list entrance settles correctly (checked a mid-animation frame and the
steady state), the provider-status crossfade on "Verifikasi Penyedia", and the completion checkmark on a "Selesai"
transaction's status history. `flutter analyze` clean, 30 tests pass (had to fix `FadeSlideIn`'s reduced-motion check,
which first read `MediaQuery` in `initState` — moved to `didChangeDependencies`, since `MediaQuery.of` isn't available
before `initState` completes; this crashed `flutter test` on the very first run). Demo data reset afterwards.

## Session 5 (2026-09-27, promo video)

Built a short promo/demo video for the Laravel-server presentation, at `../promo/promo.mp4` (sibling to `rentgear_app/`,
not part of the Flutter app). No literal screen recording (declined this session) and no direct video-generation tool
exists here.

First attempt (SVG mockups -> PNG -> ffmpeg zoompan/crossfade) looked cheap: emoji-as-icon rendered as flat black
silhouettes, motion was just a mechanical per-frame zoom. Replaced it with a real HTML/CSS animation played back in an
actual browser and captured as video, so the motion (fades, stagger, spring pop) is the same kind of animation as the
app itself, not a simulated one:

- `promo/web/index.html` — the whole promo as one page, six full-screen `<section class="scene">`s (title, Katalog,
  Detail+Booking, status timeline, Admin "Verifikasi Penyedia", closing). Real inline-SVG line icons (tent/backpack/
  moon) instead of emoji, a proper phone chassis (notch, camera button, layered shadow), a soft background glow instead
  of flat color, and a motion vocabulary that mirrors `lib/widgets/motion.dart`: list cards stagger in with
  fade+translateY (`.enter`/`.stagger`), the admin badge crossfades text (`.badge-crossfade`), and the "Selesai" step
  pops in with a spring curve (`.check` / `cubic-bezier(.34,1.56,.64,1)`). Scene changes fade **and** scale slightly
  (incoming settles from 103%, outgoing recedes to 98.5%) instead of a flat opacity crossfade, which is what actually
  fixed the "double-exposed text" look a plain crossfade gave at the scene boundaries.
  Scene timing is CSS custom properties at the top of the file (`--scene-in/-hold/-out`, `--step`): **`--step` must
  equal `--scene-in + --scene-hold`**, or the next scene starts fading in before the current one starts fading out and
  both sit fully opaque at once — that was the actual bug, not the crossfade duration.
- `promo/record.mjs` (Node + Playwright, `channel: 'chrome'` so it drives the already-installed Google Chrome instead of
  downloading a browser) opens the page, **pauses every CSS animation** (`document.getAnimations().forEach(a=>a.pause())`),
  then scrubs `currentTime` frame by frame (25fps) and takes a lossless PNG screenshot at each step — 600 frames for this
  timeline. ffmpeg then assembles them into `promo/promo.mp4` (H.264, crf 16, 1920x1080, 25fps, 24s, ~1.9MB, silent).
  First version used Playwright's built-in video recorder instead (`recordVideo`); that encodes to VP8 at a low, fixed
  bitrate meant for test artifacts, not presentation footage, and came out blocky/blurry on the UI text ("resolusi
  pecah") even though the container reported 1920x1080. Frame-by-frame PNG capture sidesteps that entirely.
- Installed for this: `ffmpeg` (Homebrew) and the `playwright` npm package. Neither was on this machine before.
- Re-running after editing the page: `node promo/record.mjs` (from `promo/`) — it deletes and recreates `frames/`,
  calls ffmpeg itself, and leaves only `promo.mp4` plus the (regeneratable) `frames/` directory, which the next run clears.
- Checked by sampling frames with `ffmpeg -vf fps=1,tile=5x5` into one contact-sheet image — faster to review than
  scrubbing the video, and how the earlier double-exposure transition bug was confirmed fixed.

Also this session: pushed the current build to the phone for sharing — `flutter build apk --release` (58.8MB, much
smaller than the 188MB debug build) copied to `/sdcard/Download/RentGear.apk` on the Redmi via `adb push`.

## Session 6 (2026-09-29/30, web build and responsive layouts)

Web support came back (commits `17a7247`, `8ee7fa4`, `3607b1d`, all pushed to `origin/master`,
github.com/DinarAziz/rentgear):

- `LocalStore` is split by platform through a conditional export: `local_store_io.dart` (mobile/desktop, same as before)
  and `local_store_web.dart` (browser `localStorage`). Before the split, `dart:io`/`path_provider` crashed the web app
  on load.
- `../webapp/` holds a compiled release build that can be served as-is (see `../webapp/README.md`, e.g. Termux
  `python -m http.server`). `../rentgear-web.zip` is the same build zipped for sharing. The zip is not tracked in git.
- The old 480px phone-only frame in `app.dart` is gone. Every layout now picks one of three widths from
  `lib/core/responsive.dart` (`FormFactor`: phone < 600, tablet < 1024, desktop from 1024 up):
  - `AdaptiveShell` (used by the customer, provider and admin shells): bottom `NavigationBar` on a phone, an icon
    `NavigationRail` with labels on a tablet, and an extended rail with the RentGear logo on a desktop.
  - Catalog: the phone list stays the same. Tablet and desktop get a grid of photo cards (`_EquipmentTile`) with
    2–5 columns (about 220px minimum per card).
  - `ResponsiveCardList` shows 1/2/3 columns of variable-height cards. It is used by Sewa Saya, provider Pesanan,
    Alat Saya, admin Transaksi and Verifikasi Penyedia.
  - `ReadableListView`/`ReadableWidth` center booking, rental detail (including its action bar), the equipment form,
    Aturan Jaminan, Profil and Kredit foto at a max width of 760px (Profil 640). The side margins still scroll with
    the mouse wheel.
  - Login: phone as before; tablet puts the form in a card; desktop splits the screen into a green brand panel and
    the form.
  - Equipment detail from 900px wide: gallery on the left, info plus the "Sewa Sekarang" button on the right.
  - Admin dashboard: 2 columns on a phone, 3 on a tablet, all 5 stats in one row on a desktop.
- Checked in Chrome (Playwright screenshots at 390x844, 820x1180 and 1440x900): login, catalog, equipment detail,
  admin dashboard, Transaksi, Penyedia and Profil all render as planned. The web version has not been tested on
  a real phone browser, and none of these changes were rechecked on the Android build.
- Rebuilding the web release: `flutter build web --release` in `rentgear_app/`, then
  `rsync -a --delete --exclude README.md build/web/ ../webapp/`. Many older files are not `dart format`ted on
  purpose, so format only the files you touch and never the whole `lib/`.

## Next (resume here)

1. The real-phone check on this build is complete: happy path, rejection path, Admin flow, and large font (including the
   handover/return/guarantee-return dialogs and the equipment form). Demo data is back to its initial state on the phone.
2. Not checked yet on the phone: the Puncak Outdoor rejection flow ("Tolak" on a pending provider) and admin's provider
   "Tolak" button — neither was exercised this session.
2. Polish done in session 2 (checked on the emulator): money fields (price, deposit, guarantee
   threshold) show thousand dots while typing via `RibuanInputFormatter` in `lib/core/format.dart`
   (tests in `test/format_test.dart`); provider profile shows the shop card (name, address, status, bank account);
   "Keluar" and admin "Verifikasi"/"Tolak" ask for confirmation first.
3. Nice to have: a confirmation dialog whose action labels do not wrap to two lines.
4. Web: try the responsive layouts on a real phone and tablet browser (e.g. `webapp/` served from Termux), and run
   the Android build once to confirm the phone layout still matches earlier sessions.
5. Desktop admin dashboard is mostly empty below the stat row; a recent-transactions list could fill it.

## Notes

- Web is supported again (see Session 6). Mobile target platforms: Android (tested on the Redmi) and, per the user's
  2026-09-27 request, **iOS too** — full mobile, one Flutter codebase for both. `ios/` already exists (Flutter's default
  scaffold) and this Mac has Xcode 27.0 + CocoaPods 1.16.2, so a build is possible, but `flutter doctor` flags the iOS
  27.0 Simulator runtime as not installed (Xcode > Settings > Components) — needed before `flutter run`/`build ios` can
  target a simulator; a real device build needs an Apple ID + signing team in Xcode instead. Nothing iOS-specific has
  been built, run, or tested yet — sessions 1-5 were Android/Redmi only and session 6 was web only. No `dart:io` usage is known to be
  Android-only, but that hasn't been audited for iOS yet either.
- The Laravel backend is on hold per the user's request.
