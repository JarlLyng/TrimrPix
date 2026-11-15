# Sentry: anonymous crash reports and counts

TrimrPix sends anonymous crash reports, crash-free sessions, Apple's MetricKit diagnostics
and two feature counts to the Sentry project `trimrpix-macos` (#106). Your images never leave
the Mac, and nothing sent identifies you or your Mac. The code is
`TrimrPix/Services/Telemetry.swift`.

## What is sent, and what isn't

Anonymous is a recipe, not Sentry's default. Out of the box sentry-cocoa sends a random
installation ID as the user, as every session's `did` and on every metric, plus
`device_app_hash`, a hash of the vendor ID, on every event. `Telemetry.swift` stops all of it:

- **One shared user, `anonymous`,** set right after `SentrySDK.start`, before any event or
  metric, and again on every event in `beforeSend`, which also covers MetricKit diagnostics.
- **No device IDs:** `beforeSend` drops `contexts.app.device_app_hash` and `contexts.device.id`.
- **Sessions without an ID:** sentry-cocoa sets a session's `did` from the `INSTALLATION` file
  in its cache directory, and there's no option to change it. The app writes `anonymous` into
  that file before the SDK starts, so every install reports the same `did`. This relies on SDK
  internals, so **check it after every sentry-cocoa upgrade** (below).
- **No file names, paths or image content:**
  - Paths and file URLs in an event's message, its exceptions and its breadcrumbs become `<path>`.
  - Breadcrumbs carry no data.
  - The app's own location in the loaded images and stack frames keeps its path but loses the
    user's name (`/Users/<user>/...`).
- **Two feature counts,** each with one attribute, `format`, from a fixed list (`jpeg`, `png`,
  `gif`, `avif`, `heic`, `pdf` or `other`):
  - `image.optimized`: a count of 1 per image optimized, in the window or by Watch Folder;
  - `image.saved`: the kilobytes it saved, rounded to whole kilobytes and never below 0.

  `beforeSendMetric` keeps only the SDK's coarse facts (SDK, release, environment, OS, device
  model) and `format`, and drops everything else, `user.id` included.
- **Off:**
  - `sendDefaultPii`;
  - all performance tracing (`tracesSampleRate` 0, and no auto, file I/O or Core Data tracing,
    since file I/O spans would carry paths);
  - network breadcrumbs and failed-request capture.

  Screenshots and the view hierarchy don't exist in sentry-cocoa on macOS.
- **Environment:**
  - `debug` for a Debug build;
  - `testflight` for a sandbox receipt;
  - `production` for a Mac App Store receipt;
  - `local` for a Release build with no receipt, such as one run from Xcode.
- **Not under XCTest,** where it would only send the test harness's noise.

The `iamjarl` Sentry organisation also strips `user.id`, `contexts.device.id` and
`contexts.app.device_app_hash` server-side and stores no IP addresses, as a safety net.

`MetricsService` still subscribes to MetricKit and logs the reports on the Mac, which helps when
reading a problem locally. Sentry's own MetricKit integration (`enableMetricKit`) is what sends
them.

### Checking the envelopes (after every sentry-cocoa upgrade)

Point a Debug build at a local stand-in for Sentry and read what it sends.

1. **Run a stand-in:** a tiny HTTP server on `127.0.0.1:8969` that saves each POST body,
   gunzipped if `Content-Encoding: gzip`.
2. **Seed an old ID:** write a fake ID to
   `~/Library/Caches/com.iamjarl.trimrpix.sentry/INSTALLATION`, to stand in for an existing
   install.
3. **Build without the sandbox,** so the capture mode can read a folder:
   `xcodebuild -configuration Debug ENABLE_APP_SANDBOX=NO CODE_SIGN_ENTITLEMENTS= build`.
4. **Run it from a folder under your home,** so its path has a user name in it:

   ```sh
   SENTRY_DSN="http://0123456789abcdef0123456789abcdef@127.0.0.1:8969/1" \
     TrimrPix.app/Contents/MacOS/TrimrPix -screenshotFolder <a copy of a few photos> -screenshotOptimize YES
   ```
5. **Crash it, for the breadcrumbs:** the Debug test event is sent before the app is active,
   so it carries none of the SDK's own breadcrumbs. Bring the app to the front (`open
   TrimrPix.app`), send it `kill -SEGV <pid>`, and run step 4 again: the crash report it
   sends carries the SDK's `app.lifecycle` breadcrumb, which sentry-cocoa always gives a
   `state` in its data.

**It passes when:**
- the `session` items' `did` is `anonymous`;
- every `event` item's `user` is `{"id": "anonymous"}`, with no `device_app_hash`, no
  `contexts.device.id` and no `server_name`;
- no breadcrumb has a `data` key, the crash report's `app.lifecycle` breadcrumb included;
- the `trace_metric` items carry no `user.*` attribute;
- the fake ID, the photos' names and your user name appear nowhere.

**Last checked with sentry-cocoa 9.34.0 on 2026-11-16: passed.**

## The DSN

The app reads the DSN in this order:
1. the environment variable `SENTRY_DSN`, for a run from Xcode or the test above;
2. the Info.plist key `SentryDSN`. `TrimrPix-Info.plist`, merged into the generated Info.plist,
   sets it to `$(SENTRY_DSN)`. It can't be an `INFOPLIST_KEY_SentryDSN` build setting: Xcode only
   generates the keys Apple lists, and silently ignores the rest, so the app would ship without
   a DSN (found by WODrounds #229).

`TrimrPix.xcconfig`, committed and the app target's base configuration, includes
`Sentry.xcconfig` if it's there.

- **Locally:** copy `Sentry.xcconfig.example` to `Sentry.xcconfig`, which is gitignored, and paste
  the DSN from Sentry → Settings → Projects → `trimrpix-macos` → Client Keys. In an xcconfig
  `//` starts a comment, so write the DSN's `//` as `/$()/`:
  `SENTRY_DSN = https:/$()/<key>@o<org>.ingest.sentry.io/<project>`. A raw `https://` is cut
  to `https:`.
- **Xcode Cloud:** add `SENTRY_DSN` to the workflow's environment as a secret.
  `ci_scripts/ci_post_clone.sh` writes `Sentry.xcconfig` from it, escaping the `//`.
- **Without a DSN,** builds and tests run with crash reporting off. **An archive is refused:**
  the app target's build phase "Refuse an archive without a Sentry DSN" stops it with an error,
  locally and on Xcode Cloud, so a release can't ship with crash reports silently off. It reads
  `SentryDSN` in the built app's Info.plist, not the build setting, and checks its shape: it
  must start with `https://` and contain `@`. So a DSN that never reached the app, or one an
  xcconfig cut to `https:`, is refused too. A Release build that isn't an archive only gets a
  warning. On every pull request, CI checks that a test DSN reaches the built Info.plist and
  that both refusals still happen.

## Symbols (dSYMs)

`ci_scripts/ci_post_xcodebuild.sh` uploads an archive's dSYMs to Sentry. It uses `sentry-cli`
3.8.2, pinned and checked against the SHA-256 GitHub publishes for it.

- **The token:** it needs a second secret on the workflow, `SENTRY_AUTH_TOKEN`, an organisation
  token with debug-file upload rights. The token never goes in the repo.
- **The slugs:** `SENTRY_ORG` and `SENTRY_PROJECT` default to `iamjarl` and `trimrpix-macos`.
- **Without the token, or if the upload fails,** the build goes on with a warning. The release is
  fine; only its stack traces are unreadable.

For a local archive, upload by hand:

```sh
sentry-cli debug-files upload --org iamjarl --project trimrpix-macos <archive>/dSYMs
```

## Privacy

The privacy policy, `TrimrPix/PrivacyInfo.xcprivacy` and the App Store label name the same
kinds of data, all not linked to the user and not used for tracking:

- **Crash Data, Performance Data and Other Diagnostic Data,** for app functionality (Other
  Diagnostic Data, as sentry-cocoa's own manifest declares it, by the owner's decision of
  2026-11-15 for every app with Sentry);
- **Product Interaction,** for analytics: the two counts.

The entitlement `com.apple.security.network.client` exists for Sentry alone. The app makes no
other connection.
