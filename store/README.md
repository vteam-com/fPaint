# Store submission

Everything needed to publish fPaint to the Apple App Store and Google Play:
listing text, graphics, screenshots, and the answers to each console's
questionnaires. The folders follow the fastlane `deliver` / `supply` layouts,
so they can be uploaded by hand or with fastlane.

| Item | App Store | Google Play |
| --- | --- | --- |
| Identifier | `com.vteam.fpaint` | `com.vteam.fpaint` |
| Version | `pubspec.yaml` → `2.1.1`, build `1` | same (`versionCode` 1) |
| Category | Graphics & Design (secondary: Productivity) | Art & Design |
| Price | Free, no in-app purchases | Free, no ads, no in-app purchases |
| Rating | 4+ | Everyone (IARC) |
| Privacy policy | <https://paint.vteam.com/privacy/> | same |
| Support | <https://github.com/vteam-com/fPaint/issues> | same |
| Languages | en-US, es-ES, fr-FR | en-US, es-ES, fr-FR |

```text
store/
├── app_store/                     fastlane deliver --metadata_path
│   ├── <locale>/                  name, subtitle, description, keywords,
│   │                              promotional_text, release_notes, *_url
│   ├── screenshots/<locale>/      iPhone 6.9" + iPad 13" (generated)
│   ├── review_information/notes.txt
│   └── copyright.txt, primary_category.txt, secondary_category.txt
└── google_play/                   fastlane supply --metadata_path
    └── <locale>/
        ├── title.txt, short_description.txt, full_description.txt
        ├── changelogs/<versionCode>.txt
        └── images/                icon.png (512), featureGraphic.png (1024×500),
                                   phoneScreenshots/, tenInchScreenshots/
```

The App Store description never names other mobile platforms (App Review
guideline 2.3.10), and the Play description leaves out the iOS-only "edit in
place from the Files app" bullet.

## Regenerating assets

- **Screenshots**: `tool/store_screenshots.sh` renders the real app UI with the
  Alpenglow showcase painting (`test/output/final.ora`, produced by the
  painting scenario test) at each store's exact pixel size, in all three
  languages.
- **Play feature graphic**: built from `test/output/final.png` and the app icon
  with ImageMagick; redo it by hand if the artwork changes.
- **Launcher icons**: `dart run flutter_launcher_icons` (the Android adaptive
  icon settings are in `pubspec.yaml`).

## Before the first submission

### Both stores

- [ ] Deploy the web build so <https://paint.vteam.com/privacy/> is live:
      `flutter build web && firebase deploy --only hosting`. Both consoles
      reject a privacy policy URL that does not load. The app's About box links
      to it too (App Review guideline 5.1.1).
- [ ] Bump `version:` in `pubspec.yaml` for each release; the build number
      after `+` must grow with every upload to either store.

### Apple App Store

- [ ] **Signing team**: copy `ios/Flutter/Signing.xcconfig.example` to
      `ios/Flutter/Signing.xcconfig` (git-ignored) and set your Team ID. Xcode
      signs with it and `tool/build_testflight.sh` exports with it, so the
      public repo carries no personal Team ID. The App Store Connect record
      for `com.vteam.fpaint` must belong to that team.
- [ ] App Store Connect → the app → **App Information**: name, subtitle,
      categories, content rights ("does not contain third-party content").
- [ ] **App Privacy**: "Data Not Collected". Matches `ios/Runner/PrivacyInfo.xcprivacy`
      (no tracking, no collected data; FileTimestamp reasons C617.1 and 3B52.1
      for the recent-files list and save backups).
- [ ] **Age Rating**: answer "None" or "No" to every item, including
      "Unrestricted Web Access" (links open in Safari, not in the app) → 4+.
- [ ] **Export compliance**: already answered in `Info.plist`
      (`ITSAppUsesNonExemptEncryption` = false); no form needed.
- [ ] **Pricing and Availability**: Free, all territories.
- [ ] Version page: paste the listing text from `app_store/<locale>/`, upload
      the screenshots (iPhone 6.9" and iPad 13" sets; App Store Connect scales
      them down for smaller devices), and paste `review_information/notes.txt`
      into App Review notes. No sign-in is needed, so leave the demo account
      empty.
- [ ] Build and upload: `tool/build_testflight.sh <build-number>`, then
      Transporter. Select the build on the version page and submit.
- [ ] **After approval**: put the numeric Apple ID into the Platforms page
      (`lib/pages/platforms_page.dart`, `_urlIOSApp`), which points at the info
      page until then.

### Google Play

- [ ] **Create the upload key** (once; back it up somewhere safe — losing it
      means asking Google to reset it):

      ```sh
      keytool -genkey -v -keystore ~/keys/fpaint-upload-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias upload
      cp android/key.properties.example android/key.properties   # then fill it in
      ```

- [ ] Play Console → **Create app**: name "fPaint - Draw & Paint", default
      language English (United States), App, Free. Enrol in **Play App
      Signing** (the default); Google keeps the app signing key and you upload
      with the key above.
- [ ] **New personal developer accounts** (created after November 2023) must
      run a closed test with at least 12 testers for 14 consecutive days before
      production access is granted. Start the closed-testing track first if
      that applies.
- [ ] **App content** declarations:
  - Privacy policy: <https://paint.vteam.com/privacy/>
  - Ads: No
  - App access: All functionality is available without special access
  - Content rating (IARC questionnaire): category "All Other App Types";
    answer No to violence, sexuality, language, controlled substances,
    gambling; "Users can interact or exchange content": No; "Shares
    location": No; "Digital purchases": No → Everyone / PEGI 3
  - Target audience: 13 and over (choosing younger ages enrols the app in the
    Families policy, which fPaint would meet, but needs extra review)
  - Data safety: "Does your app collect or share any of the required user
    data types?" **No**. Nothing is transmitted off the device.
  - Government apps, financial features, health, news: No
- [ ] **Store listing**: paste the text from `google_play/<locale>/`, upload
      `images/icon.png`, `images/featureGraphic.png`, phone and 10" tablet
      screenshots. Category Art & Design; contact e-mail is required (it is
      shown publicly).
- [ ] Build and upload: `tool/build_play.sh <build-number>` →
      `build/app/outputs/bundle/release/app-release.aab`, then create a release
      on the track and paste `changelogs/<versionCode>.txt` as release notes.

## Uploading listing text with fastlane (optional)

```sh
fastlane deliver --skip_binary_upload --metadata_path store/app_store \
  --screenshots_path store/app_store/screenshots --app_identifier com.vteam.fpaint
fastlane supply --skip_upload_apk --skip_upload_aab --metadata_path store/google_play \
  --package_name com.vteam.fpaint --json_key <play-service-account.json>
```

## Toolchain notes

Flutter 3.47 warns that support for Android Gradle Plugin 8.11 and Kotlin 2.2
will be dropped soon. Neither blocks publishing today; plan the AGP 9 /
Kotlin 2.3 upgrade separately because AGP 9 changes the Gradle DSL.
