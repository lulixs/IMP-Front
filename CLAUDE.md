# IMP-Front

The README covers setup, run commands, checks, and the project layout:

@README.md

**Claude never makes git commits or pushes in this repo.** Leave changes uncommitted for a person to review and commit.

`claude_logs/` is written only by the prompt-logging hook (see the README). Never read it for context, edit it, or delete it.

## Conventions

- Plain Flutter: `Navigator` for screens and `ChangeNotifier` for state. Don't add state management or routing packages.
- Targets are Android and web only.
- Two-space indentation, and lines up to about 120 characters. **Don't run `dart format` over `lib/` or `test/`.** It rewraps every file to 80 columns and buries real changes in the diff. Match the surrounding style by hand.
- `prototype/` is the old click-through app. Use its `lib/theme.dart` and `lib/widgets/common.dart` as the guide for look and layout, but don't copy features from it in bulk. Build only what the current task needs.
- API response shapes are defined in IMP-Back's `docs/api/` (for example `docs/api/dashboard.md`). Models in `lib/models/` follow those files. If a shape needs to change, change the contract first.
- Calls to the backend go through `lib/api/` (`ApiClient`, which throws `ApiException`). The backend address and timeout are in `lib/config.dart`. The address is chosen when the app is started, with `--dart-define=API_BASE_URL=...` (D-158), and defaults to `http://localhost:5000`. Never edit the address in the file to switch servers.
- Errors follow IMP-Back's `docs/api/README.md` (D-165). `ApiClient` is to handle the four error codes (`deviceNotSetUp`, `deviceExpired`, `deviceRemoved`, `sessionEnded`) for every request, before any screen sees them (D-168), and screens show the `error` sentence for every other error. Partly built: `ApiClient` uses the server's `error` sentence and keeps its `code` on `ApiException`, but doesn't act on the four codes yet.
- Tests that touch the API use a fake server, so `flutter test` doesn't need the backend running.
- Run `flutter analyze` and `flutter test` before committing. Both should pass cleanly.

## Design references

The wireframes, ERD, requirements, and decisions register are in the team's IMP docs folder, outside this repo. Check the decisions register before keeping or removing UI that the wireframes don't show.

## Writing style

In comments, docs, and UI text: no semicolons between list items, no em dashes, and say "tablet" rather than the device's brand name.
