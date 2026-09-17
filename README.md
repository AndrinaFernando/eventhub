# EventHub

A Flutter application for discovering events, booking tickets, and managing events.

## Student details

- Name: Andrina Fernando
- Student ID: IM/2022/135
- Module: Cross-Platform App Development

## Features

- Account registration, login, logout, and profile editing.
- Event search and category filters.
- Event details and available-seat checking.
- Booking confirmation and cancellation.
- Current, previous, and cancelled bookings.
- Organizer event creation, editing, removal, and booking lists.
- Favourite events stored locally.
- List and responsive grid layouts.
- Android local notifications for booking confirmation and cancellation.

## Technologies

- Flutter and Dart.
- Supabase Authentication and PostgreSQL.
- Supabase REST API through the Supabase Flutter SDK.
- Shared Preferences for local favourites.
- Flutter Local Notifications for Android notifications.

## Requirements

- Flutter SDK.
- Android SDK for Android builds.
- Chrome for the web preview.
- A Supabase project.
- Internet access.

## Database setup

SQL setup files are in `lib/supabase`.

For a new Supabase project, run these files once, in order, using
the Supabase SQL Editor:

1. `001_profiles.sql`
2. `002_events.sql`
3. `003_bookings.sql`
4. `004_booking_history.sql`
5. `005_remove_event.sql`

These files create the application tables, access policies,
triggers, and database functions.

## Supabase configuration

1. Set your project URL and publishable key in `lib/main.dart`.
2. For the Chrome preview, set the Authentication Site URL to
   `http://localhost:3000`.
3. Register accounts through the app.
4. To create an organizer account, an administrator must change
   that account's `role` in the `profiles` table to `organizer`.
   Other accounts remain `attendee`.
5. Event forms accept HTTPS image URLs. To host images in Supabase,
   create a public `event-images` storage bucket, upload images
   through the dashboard, and use their public URLs.

Only a client publishable key belongs in the app.
Do not add database passwords or Supabase secret/service-role keys.

## Run the application

Install dependencies:

```bash
flutter pub get
```

Run the Chrome preview:

```bash
flutter run -d chrome --web-port 3000
```

For Android, connect a phone with USB debugging enabled:

```bash
flutter devices
flutter run -d YOUR_DEVICE_ID
```

Replace `YOUR_DEVICE_ID` with the ID shown by `flutter devices`.

## Checks and Android build

```bash
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at:

`build/app/outputs/flutter-apk/app-debug.apk`

## Verification status

- Browser workflows have been checked manually.
- Flutter analysis, the existing widget test, and a debug Android
  APK build passed during development.
- Physical Android device testing is pending.
- Android notification delivery is pending device verification.

The automated test suite is limited and does not cover every workflow.
Android local notifications are not demonstrated by the Chrome preview.