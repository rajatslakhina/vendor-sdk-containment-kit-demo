# VendorContainment Demo

**Watch a poisoned vendor SDK crash an app twice and then get contained, with no release, no vendor fix, and no lost analytics.** This is the companion iOS app for [**VendorContainment**](https://github.com/rajatslakhina/vendor-sdk-containment-kit). It consumes that library the way a real app would, as a remote Swift package resolved from GitHub at a released version (the 1.x line, at least 1.0.1).

[![CI](https://github.com/rajatslakhina/vendor-sdk-containment-kit-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/rajatslakhina/vendor-sdk-containment-kit-demo/actions/workflows/ci.yml)

## Why this matters

On 28 September 2026, a vendor-side config change made a widely used analytics SDK crash apps at launch for over two hours ([postmortem](https://firebase.blog/posts/2026/10/firebase-analytics-outage)). In that incident each device crashed once before the SDK fell back. The worse case, a crash on every cold start, is what this app models. The question a lead has to answer isn't "how do I fix that SDK". It's **"what in our app stops any vendor from doing this to us, without waiting for a release or for the vendor?"** This app makes the answer something you can tap through.

## What you'll see

One screen, the **SDK Containment** console, with three wrapped vendor SDKs (`analytics`, `attribution`, `messaging`). Each **Launch app** tap is a *cold start*: a fresh runtime against the same persistent store. Only the store survives a simulated crash, just like on a device.

The default state is modelled on that incident, in its worst-case form: `attribution`'s remote config ships a **null flag name**, the SDK crashes on it every time, and payload validation is **off** (as it would be for config the SDK fetches internally, where you can't validate it). Tap **Replay ×4**:

| Launch | What happens | Why |
|---|---|---|
| 1 | 💥 crashed in `attribution.start()` | `analytics` was still on probation, so this is only a *probable* attribution: a provisional strike (1), and both vendors run isolated next time |
| 2 | 💥 crashed again, this time with `attribution` running alone | the second strike was earned in isolation, so it's unambiguous |
| 3 | ✅ app up, **attribution contained** | quarantined; `analytics` and `messaging` start normally |
| 4 | ✅ app up | still contained; `attribution`'s events are buffered, not lost |

Then try the other controls:

- **Release** on the quarantined vendor bumps its `quarantineEpoch` in a new policy version ("the vendor shipped a fix"). On the next launch it starts, and every buffered `app_open` replays in order.
- **Ship new build**: a quarantined vendor gets *one isolated probe*. If it's still broken, it crashes once more and goes back in with a doubled cooldown.
- **App kill switch**: your own control plane, not the vendor's. `messaging` is configured to *drop* (privacy kill), and the others *buffer* (operational pause).
- **Validate vendor payloads**: turn it on and the same poisoned config is rejected before the SDK ever sees it. Zero crashes.
- **Crash when another SDK starts**: a contention bug. The SDK that happens to be starting at the moment of death is never quarantined for it.
- **Send event**: shows, per vendor, whether the event was sent, buffered or dropped.

## Screenshots

**There are no screenshots in this repo, because the app has not been run on a Simulator yet.** See "Verification" for exactly why. No image here is a mockup or a description passed off as a capture.

## How to run it

```bash
git clone https://github.com/rajatslakhina/vendor-sdk-containment-kit-demo.git
cd vendor-sdk-containment-kit-demo
open Demo.xcodeproj
```

1. Xcode resolves `VendorContainment` from GitHub automatically (requirement: *up to next major* from **1.0.1**).
2. Select the **Demo** scheme and any iPhone Simulator.
3. Build & Run (⌘R), then tap **Replay ×4**.

Requires Xcode 16+ and iOS 17+.

To run the library's test suite (89 XCTest cases, including the ones that pin the table above):

```bash
git clone https://github.com/rajatslakhina/vendor-sdk-containment-kit.git
cd vendor-sdk-containment-kit && swift test   # macOS; see that README for the Linux flag
```

## How it's wired

- `Demo/DemoApp.swift` owns what a product team owns: the vendor roster and each vendor's startup stage, the **compiled-in policy** (version 0, used before your control plane has ever answered), and the containment configuration (10 s stability window, strike threshold 2, 1 h base cooldown). The console view and model come from `VendorContainmentUI`. Everything that makes decisions is in `VendorContainment`.
- `Demo.xcodeproj` references the library as an `XCRemoteSwiftPackageReference` to `https://github.com/rajatslakhina/vendor-sdk-containment-kit`, requirement `upToNextMajorVersion` from `1.0.1`. It's not a local path and not a branch, so every clone builds against a released, tagged version.
  *Trade-off:* it's a semver range, not an exact pin. No `Package.resolved` is committed, so a future 1.x patch is picked up on a fresh clone. That's the usual choice for an app tracking a library its own team owns. Switch to `exactVersion` (or commit `Package.resolved`) if you need bit-for-bit reproducibility.
- The library repo deliberately contains **no app target**. The runnable app lives only here.

## Verification

What actually happened, stated separately:

- **Builds for the iOS Simulator: yes, in CI.** This repo's [Actions workflow](https://github.com/rajatslakhina/vendor-sdk-containment-kit-demo/actions) runs on `macos-15`, and its first run passed both steps:
  - `xcodebuild -resolvePackageDependencies` resolved `VendorContainment` from GitHub. With the requirement "up to next major from 1.0.1", the only satisfying tag is `v1.0.1`.
  - `xcodebuild build -scheme Demo -destination 'generic/platform=iOS Simulator'` compiled the app against it.

  That proves the project opens, the remote package resolves, and the app compiles. It does not prove the app runs.
- **Ran on a Simulator: no.** The run was attempted from an unattended session. Computer-use access was granted, but Xcode can only be controlled at "click" tier, which refuses menu commands and keyboard input. Xcode also launched with no window open, so there was nothing to click that could open this project. The session has no macOS shell (no `xcodebuild` / `simctl`). The app has therefore **not** been launched, interacted with, or screenshotted. "It builds for a Simulator" is not the same claim, and isn't made as one.
- **The behaviour in the table above is tested, not assumed.** Two library tests cover it:
  - `ContainmentConsoleModelTests.testDefaultReplayShowsCrashesThenContainment` drives the same view model with this app's default scenario. It asserts the crash sequence, the provisional strike recorded for launch 1, `analytics` clearing its window alone in launch 2, the unambiguous second strike, and the "attribution contained" headline.
  - `IncidentReplayTests.testPoisonedPayloadCrashesTwiceThenIsContained` checks the same at the runtime level.

  Both pass in the library's CI on the `v1.0.1` commit (Linux and macOS jobs).

## License

MIT
