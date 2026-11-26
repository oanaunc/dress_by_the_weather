# Android edition

Native Kotlin / Jetpack Compose implementation of the shipping SwiftUI app. The five main tabs, outfit details, hourly and daily forecasts, free packing, saved looks, preferences, widgets and four Pro Studio tools have matching content and styling. Native system UI differs by platform. Apple-only fonts and SF Symbols are replaced with licensed Source Serif 4 / Inter and original or Material icons.

## Build

Requires JDK 21 and Android SDK 36. Set `ANDROID_HOME` or create an ignored `local.properties` containing `sdk.dir=/your/Android/sdk`.

```sh
cd Android
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

Debug installs alongside production with the `.debug` application ID suffix. Unit tests exercise 9,360 reference outputs produced by the shipping Swift engine, plus weather parsing, time zones, wardrobe/capsules, persistence and RSA verification. Instrumented tests cover free and Pro flows, live worldwide search, demo isolation and local persistence.

`syncIosContent` copies all 214 original approved JPEGs and the canonical lookbook directly from `App/` into generated build assets. No duplicate artwork directory is committed. After editing Swift outfit blueprints or guides, run `python3 Scripts/sync_android_content.py` from the repository root.

## Release signing

Run `python3 Scripts/build_android_release.py` from the repository root. The helper reads the private signing configuration outside this repository, checks the public billing key is present, and builds signed AAB/APK files plus release lint. `--create-key` is only for the initial private upload-key creation. Preserve a secure backup of the signing folder printed by the helper. Never commit keys, passwords or signing configuration. Google Play App Signing holds the distribution key; the local key signs uploads.

Outputs are ignored `Android/app/build/outputs/bundle/release/app-release.aab` and `Android/app/build/outputs/apk/release/app-release.apk`.

## Services and privacy

Weather: MET Norway Locationforecast over HTTPS, no paid API/key, a minimum three-hour cache with conditional requests and rate-limit backoff. Location permission is optional, approximate and foreground only. Search uses Android Geocoder with rate-limited Photon fallback and offline CC0 time zones. No analytics, ads, developer backend or photo upload. Android backup is disabled.

Pro: `dress_pro_lifetime`, purchase option `lifetime`, one-time US $19.99 with Google localized prices. Google Play Billing 9.1 verifies signed purchase proofs using the app-specific public RSA key, acknowledges purchases, restores ownership and refreshes refunds. Pending, cancelled, missing or invalid purchase proofs never grant ownership. No real paid transaction was made during local testing; a Play-installed licensed tester must validate the live Google payment sheet.

The public **sample Studio** is available from the paywall to everyone, including reviewers. It uses labelled sample forecasts, an isolated in-memory preferences model and a separate temporary photo directory. It does not change verified ownership, personal data, widgets or reminders. Exiting resets the sample. This is separate from Debug-only development launch flags, which are compiled out of release.

Published Android privacy policy: https://www.oanarinaldi.com/dressbytheweatherandroidprivacy.html

## Licenses

Weather data CC BY 4.0, OpenStreetMap attribution, CC0 tz-lookup, and OFL Source Serif / Inter credits are accessible inside the app. Font and time-zone licenses are bundled under `app/src/main/assets/`.
