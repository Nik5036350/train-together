# Train Together — iOS

The native app: SwiftUI, iOS 26+. It works **offline-first**: every workout
lives in an on-device SQLite database (GRDB), and changes sync to the Rust
server's `/api/v2` so nothing is lost.

## Layout

```
project.yml                  XcodeGen spec (the .xcodeproj is generated, not checked in)
Config/                      Base.xcconfig + your gitignored Signing.xcconfig
Packages/TrainTogetherKit/   core logic, testable on the Mac with `swift test`
  TrainTogetherCore          records, enums, formatting (no dependencies; the widget links it)
  TrainTogetherKit           GRDB database, WorkoutEngine (workout rules), SyncEngine
TrainTogether/               the app: App/, DesignSystem/, Features/, Services/, Resources/
TrainTogetherWidgets/        Live Activity (rest timer on Lock Screen / Dynamic Island)
Shared/                      ActivityAttributes compiled into app + widget
TrainTogetherTests/          app unit tests
TrainTogetherUITests/        end-to-end flow against a local backend
```

## Setup

```bash
brew install xcodegen
cp Config/Signing.xcconfig.example Config/Signing.xcconfig   # set DEVELOPMENT_TEAM
xcodegen generate
open TrainTogether.xcodeproj
```

Simulator builds work without a team.

### Installing on an iPhone with a free Apple ID

1. In Xcode, go to Settings → Accounts and add your Apple ID. Put the Personal Team id in `Config/Signing.xcconfig`.
2. On the iPhone, turn on Settings → Privacy & Security → Developer Mode.
3. Run the `TrainTogether` scheme on the phone. The first time, trust the developer under Settings → General → VPN & Device Management.
4. **Free builds expire after 7 days.**
   - Settings shows the expiry date, and a banner appears when fewer than 48 hours are left.
   - To renew, run the app from Xcode again. Installing over the existing app keeps its data, and the server holds a copy anyway.
5. Free-account limits:
   - 3 sideloaded apps per device.
   - 10 App IDs per 7 days. This app uses 2: the app and its widget.
   - No push notifications. The Live Activity updates locally.

## Commands

```bash
cd Packages/TrainTogetherKit && swift test          # engine, sync, fixture contract (fast, on the Mac)
xcodebuild -scheme TrainTogether -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

End-to-end test (restore → workout → history → sync) against a local backend:

```bash
cd ../backend && SYNC_TOKEN=e2e-token-0123456789abcdefghijklmnop cargo run &
curl -X POST -H "Authorization: Bearer e2e-token-0123456789abcdefghijklmnop" \
  "http://localhost:8080/api/v2/admin/import-legacy?source=db&replace=true"
cd ../ios && xcodebuild -scheme TrainTogetherE2E -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## How the data works

- **The engine owns the rules.** `WorkoutEngine` is a port of the old server services: turns, set numbering, rest timers, skips and substitutions.
  - Every mutation runs in one SQLite transaction.
  - Screens observe snapshots through `WorkoutStore`. They never touch GRDB directly.
- **Every write is queued for sync.** SQLite triggers on each synced table write the change to `sync_outbox`.
  - `SyncEngine` pushes shortly after each change. It also pushes on finish, when the app becomes active, and when the network comes back.
  - Each change is stamped with a monotonic clock. The server applies last-writer-wins.
  - If the server's `storeId` changes, or its counter goes backwards, the server has lost data. The engine then uploads everything again.
- **Restore replaces the phone's data with the server's.** It is used when setting up a new phone and for the one-time migration from the web app.
- **The sync contract** is the camelCase JSON of each record in `TrainTogetherCore/Records.swift`.
  - The server's legacy importer produces the same shapes.
  - `backend/tests/fixtures/seed-records.json` pins them. Both test suites check against it.
  - New fields must be optional or have a default.

Adding a column to a synced table takes a new GRDB migration that ends with `SyncTriggers.install(db)`.
