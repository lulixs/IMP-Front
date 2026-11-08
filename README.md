# IMP-Front

The tablet app for IMP (Inventory Management Platform), built with Flutter. It talks to the backend in [IMP-Back](https://github.com/lulixs/IMP-Back).

**Status:** first-time setup, sign-in, and the dashboard are built. Sign-in accepts any valid email, any password, and any PIN, and lists one stub employee, Dan Finkle. The dashboard loads real data from `GET /api/dashboard`, so the backend and its database must be running (see IMP-Back's README). The sidebar and bottom bar are in place but their buttons don't do anything yet. Nothing is saved to the backend yet.

## Setup (once per computer)

1. Install Flutter (stable channel). Check it with `flutter doctor`.
2. Clone the repo and fetch the packages:
   ```
   git clone git@github.com:lulixs/IMP-Front.git
   cd IMP-Front
   flutter pub get
   ```

## Running the app

```
flutter run -d chrome                              # normal start, with first-time setup
flutter run -d chrome -t lib/dev_dashboard.dart    # skips setup and opens the dashboard
flutter run -d chrome -t lib/dev_login.dart        # skips setup and opens sign-in
```

`lib/dev_dashboard.dart` and `lib/dev_login.dart` are for debugging only. Release builds always start from `lib/main.dart`, which runs first-time setup.

While the app is running, press `r` to reload your changes, `R` to restart, and `q` to quit.

## Checks

Run both before committing:

```
flutter analyze    # should say: No issues found!
flutter test       # should say: All tests passed!
```

## Project layout

```
lib/
├── main.dart              starts the app with first-time setup
├── dev_dashboard.dart     starts the app on the dashboard (debugging only)
├── dev_login.dart         starts the app on sign-in (debugging only)
├── theme.dart             colors and text field style
├── validators.dart        form checks shared by more than one screen, like the email check
├── api/                   ApiClient and ApiException, for talking to the backend
├── config.dart            the backend's address and request timeout
├── models/                data classes for API responses, with fromJson
├── screens/
│   ├── setup/             first-time setup: Master account, tablet name, first employee, confirmation
│   ├── login/             sign-in: Master account, then employee name and PIN
│   └── dashboard/         dashboard page and category cards
└── widgets/
    ├── app_shell.dart     sidebar and bottom bar around the main pages
    └── common.dart        small pieces shared by every screen
test/                      tests for the screens, widgets, and models
prototype/                 the old click-through app, kept as a guide for style and layout
```

## Claude prompt logs

Every prompt sent to Claude Code in this repo is saved word for word, with a timestamp, in `claude_logs/`. There is one markdown file per session, named by date, person, and session. A hook does the logging: `.claude/settings.json` runs `.claude/hooks/log_prompt.py` each time a prompt is sent, so it needs Python 3 (`python3` or `python` on your PATH). Commit the log files along with your other changes. Nobody edits or deletes them, Claude included, and Claude doesn't read them for context.

## API contracts

The shape of each API response is defined in the backend repo under `docs/api/`, for example `docs/api/dashboard.md`. If a shape needs to change, change that file first, then the code on both sides.
