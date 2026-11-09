# IMP-Front

The tablet app for IMP (Inventory Management Platform), built with Flutter. It talks to the backend in [IMP-Back](https://github.com/lulixs/IMP-Back).

**Status:** first-time setup, sign-in, and the dashboard are built. Sign-in accepts any valid email, any password except `wrong`, and any PIN except `000000`, and lists one stub employee, Dan Finkle. The password `wrong` and the PIN `000000` always fail, so the error box can be seen. The dashboard loads real data from `GET /api/dashboard`, so the backend and its database must be running (see IMP-Back's README). The sidebar shows the signed-in employee, with a Master tag that turns Master mode on or off after a popup (unlocking the Master-only items) and a Switch user button that returns to the PIN screen. The other sidebar items and the bottom bar buttons don't do anything yet. Nothing is saved to the backend yet. The app runs in Chrome and on the team's Android emulator, with the server address chosen by a flag when it starts (see Android emulator).

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

## Android emulator

The team tests on a tablet-sized emulator called `IMP_Tablet` (D-161). A virtual device can't be copied between computers, so everyone makes their own with the steps below.

### Making the emulator (once per computer)

1. Make sure Android Studio and the Android SDK are installed and `flutter doctor` shows no Android problems. In Android Studio, open the SDK Manager, go to SDK Tools, and check "Android SDK Command-line Tools (latest)". Then put the tools on your PATH (see the notes for your system below) and check with `avdmanager list avd`.
2. Download the system image:
   ```
   sdkmanager "system-images;android-37.0;google_apis_playstore;x86_64"
   ```
3. Create the device:
   ```
   avdmanager create avd -n IMP_Tablet -d medium_tablet -k "system-images;android-37.0;google_apis_playstore;x86_64"
   ```
4. Open `IMP_Tablet.avd/config.ini` in your `.android/avd` folder and set these lines (they already exist, only the values change):
   ```
   hw.lcd.width=1200
   hw.lcd.height=1920
   hw.lcd.density=240
   hw.keyboard=yes
   hw.gpu.enabled=yes
   ```
   If the emulator feels slow, also set `hw.ramSize=4096`.

**Linux:** the SDK is usually at `~/Android/Sdk`. Add these to `~/.bashrc`:
```
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$HOME/.android"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
```
`ANDROID_USER_HOME` matters when `XDG_CONFIG_HOME` is set (some desktops set it). Without it, `avdmanager` looks for devices in `~/.config/.android` while the emulator uses `~/.android`, and each can't see the other's devices.

**Windows:** the SDK is usually at `%LOCALAPPDATA%\Android\Sdk`, and the devices are in `%USERPROFILE%\.android\avd`. Add `cmdline-tools\latest\bin`, `emulator`, and `platform-tools` from the SDK folder to your Path. The tools are `avdmanager.bat` and `sdkmanager.bat`, but `avdmanager` and `sdkmanager` work too. The emulator needs a hypervisor: turn on "Windows Hypervisor Platform" in "Turn Windows features on or off", then restart.

**Mac with Apple silicon (M1 and later):** use `arm64-v8a` instead of `x86_64` in steps 2 and 3. The SDK is usually at `~/Library/Android/sdk`, and the devices are in `~/.android/avd`.

### Running everything (every time)

You need two terminals. The commands assume IMP-Back and IMP-Front are cloned into the same folder. On Windows or Mac, open Docker Desktop first.

**Terminal 1, the database and the API** (from the IMP-Back folder):
```
cd db
docker compose up -d
docker compose ps                  # wait until imp-mysql shows (healthy)
cd ..
dotnet run --project Imp.Api       # wait for: Now listening on: http://localhost:5000
```
Check it in a browser on your computer: http://localhost:5000/api/health/database should show `{"database":"ok"}`. Leave this terminal running.

**Terminal 2, the emulator and the app** (from the IMP-Front folder):
```
flutter emulators --launch IMP_Tablet      # wait for the tablet's home screen
adb devices                                # should show: emulator-5554   device
flutter pub get                            # only needed after pulling changes
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000
```
To skip setup and open the dashboard, add `-t lib/dev_dashboard.dart`. Inside the emulator, `localhost` means the emulator itself, and `10.0.2.2` means your computer. The server address is always chosen with this flag (D-158). Never edit it in `lib/config.dart`. Without the flag the app uses `http://localhost:5000`, which only works in Chrome.

**When you're done:** press `q` in terminal 2, `Ctrl+C` in terminal 1, and close the emulator window. To stop the database too, run `docker compose stop` in IMP-Back's `db` folder (your data is kept).

The first Android build takes several minutes. Check the emulator's name with `adb devices` if it isn't `emulator-5554`.

If the dashboard can't connect, check that the API is running and that the flag is in the command. If the emulator freezes or acts strangely, start it with `emulator -avd IMP_Tablet -no-snapshot-load` for a clean boot, or add `-wipe-data` to reset it.

To test on a real Android phone plugged in by USB, run `adb reverse tcp:5000 tcp:5000` once the phone shows in `adb devices`, then run the app without the flag. The phone's `localhost:5000` then leads to your computer.

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

Every prompt sent to Claude Code in this repo is saved word for word, with a timestamp, in `claude_logs/`, with a folder for each person (named from your git `user.name`) and one markdown file per session, named by date and session. A hook does the logging: `.claude/settings.json` runs `.claude/hooks/log_prompt.py` each time a prompt is sent, so it needs Python 3 (`python3` or `python` on your PATH). Commit the log files along with your other changes. Nobody edits or deletes them, Claude included, and Claude doesn't read them for context.

## API contracts

The shape of each API response is defined in the backend repo under `docs/api/`, for example `docs/api/dashboard.md`. If a shape needs to change, change that file first, then the code on both sides.
