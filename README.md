# PPT Maintenance System Flutter App

`maintapp` is the Flutter client for the PPT Maintenance System v2.x. It is a private internal application used to manage authentication, user sessions, user administration, and maintenance work orders across mobile and desktop-style Flutter targets.

## Current Scope

The app currently includes:

- Login flow
- Dashboard
- My Profile
- Login session management
- User management
- Work order creation
- Work order listing for CM and PM flows

The client is API-driven and is designed to work with the corresponding maintenance system backend project.

## Tech Stack

- Flutter
- Dart `^3.9.2`
- Material 3 UI
- `http` for API calls
- `flutter_secure_storage` for local credential/session storage
- `file_picker` for PDF selection and upload
- device and platform helper packages for runtime environment handling

## Project Structure

Key folders and files:

- `lib/main.dart`: app entry point and route registration
- `lib/api/`: API controller and request handling
- `lib/model/`: app data models such as user, session, and work order
- `lib/pages/`: UI pages
- `lib/state/`: session and app state helpers
- `assets/language/`: language resources
- `assets/images/`: static images

## Main Routes

Registered routes in the app include:

- `/login`
- `/home`
- `/profile`
- `/login-sessions`
- `/work-orders`
- `/create-work-order`
- `/user-management`

## Requirements

Before running the project, make sure you have:

- Flutter SDK installed
- A supported Dart SDK matching the Flutter version in use
- Access to the maintenance system API server
- Platform-specific build tooling if you are running on iOS, Android, macOS, or Windows

Check Flutter locally with:

```bash
flutter doctor
```

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Run on a specific device:

```bash
flutter devices
flutter run -d <device_id>
```

## Assets

The project currently declares these bundled assets:

- `assets/images/login_page/login_bg.jpeg`
- `assets/language/en-us.json`
- `assets/language/zh-hk.json`

If you add more assets, update `pubspec.yaml` accordingly.

## Notes About Backend Integration

This application depends on backend APIs for:

- authentication
- session listing and revocation
- user listing and management
- work order creation and listing
- OCR-related work order flows

If backend request or response shapes change, update:

- `lib/api/api_controller.dart`
- related files in `lib/model/`
- affected UI pages in `lib/pages/`

## Development Notes

- This is a private project and `pubspec.yaml` is configured with `publish_to: "none"`.
- The current theme uses a neutral Material 3 palette rather than Flutter defaults.
- The work order module supports CM and PM handling and continues to evolve alongside the backend API.

## Recommended Next Documentation Improvements

Useful additions later if needed:

- environment and base URL configuration
- authentication flow details
- API endpoint mapping
- release/build instructions per platform
- screenshots for major pages
