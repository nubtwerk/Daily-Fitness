# DailyFitness — TestFlight submission & on-device QA (US-120)

Phase F ships the code; submitting a build and running the core loop on a **physical device** must be done
by a human with the signing identity and hardware. This runbook is the handoff.

## 0. One-time prerequisites

- **Apple Developer Program** membership and **App Store Connect** access.
- An App Store Connect **app record** for bundle id `app.dailybase.dailyfitness`.
- Register the App Group `group.app.dailybase.dailyfitness` and enable, on the App ID:
  **Sign in with Apple**, **App Groups**, and **Push Notifications** (Live Activities use the local
  ActivityKit path today, but the push capability is needed if you later push updates).
- Set the signing team. In `project.yml` under `settings.base`, set `DEVELOPMENT_TEAM` to your Team ID
  (currently empty), then `xcodegen generate`. Set the same `teamID` in `ExportOptions.plist`.
- Create `Config/Secrets.xcconfig` from `Config/Secrets.example.xcconfig` with REAL values:
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY`. (Placeholders compile but auth/sync/IAP
  will not work on device.)
- StoreKit sandbox: create a **Sandbox Apple Account** and the **Pro** subscription products in
  App Store Connect so the paywall can be exercised.

## 1. Build, archive, export, upload

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Archive (real signing, device build)
xcodebuild -project DailyFitness.xcodeproj -scheme DailyFitness \
  -destination 'generic/platform=iOS' \
  -archivePath build/DailyFitness.xcarchive archive

# Export for App Store Connect
xcodebuild -exportArchive \
  -archivePath build/DailyFitness.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export

# Upload (either of these)
xcrun altool --upload-app -f build/export/DailyFitness.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
# …or open build/DailyFitness.xcarchive in Xcode > Organizer > Distribute App.
```

Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` for each upload.

## 2. On-device core-loop QA gate (US-120 acceptance criteria)

Run on a **real iPhone** (Live Activity, Dynamic Island, and haptics do not exist in the Simulator).

- [ ] **Onboarding → program → log workout → view history** completes end to end.
- [ ] Start a suggested program; start today's session from Home.
- [ ] Live workout: enter weight/reps, complete a set, rest timer ring appears and depletes (sage, no red).
- [ ] **Lock Screen Live Activity** shows the session; **Dynamic Island** shows it on a 14 Pro+.
- [ ] Live Activity intents work: complete set / +30s rest / end workout from the Lock Screen.
- [ ] **Haptics** fire on set completion / PR.
- [ ] Finish workout → summary → appears in **History**.
- [ ] **StoreKit sandbox**: paywall purchase + restore unlocks Pro (progression on 3+ strength lifts).
- [ ] Sign in with Apple; sign out; delete account.
- [ ] Kill/relaunch mid-workout: session and pending sync survive (offline-first).
- [ ] **Profile → Send feedback** opens Mail prefilled with app version + iOS version.
- [ ] **Crash-free ≥99%**: watch App Store Connect → TestFlight → Crashes after the beta cohort runs;
      MetricKit crash/hang diagnostics are logged (`CrashDiagnosticsService`, subsystem
      `app.dailybase.dailyfitness`, category `app`) — inspect with Console.app / `log collect`.

## 3. Accessibility spot-check on device (US-122)

- [ ] VoiceOver: each set row announces "Set N", then weight/reps/RIR with units and "empty" when blank;
      the complete button reads "Complete set N … not completed/completed".
- [ ] The rest-timer ring is one element reading "Rest timer, N seconds remaining".
- [ ] PR earns a spoken "New personal record!" announcement even though the toast auto-dismisses.
- [ ] Dynamic Type at the largest accessibility size: set rows reflow to a vertical layout; nothing clips;
      the 44pt complete target stays on screen.
- [ ] Calm Strength contrast holds in light and dark (palette is WCAG-AA per `.context/phase-f/contrast.json`).

## 4. Final visual sign-off

Run the gstack `ios-qa` (behavior) and `ios-design-review` (visual) skills against the TestFlight build on
hardware — that is the Phase F QA gate.
