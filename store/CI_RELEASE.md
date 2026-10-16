# Store releases from GitHub Actions

`.github/workflows/store-release.yml` builds signed releases and uploads them:
iOS to App Store Connect (TestFlight), Android to a Google Play track. The
repo is public, so the workflow holds only secret *names*; every Team ID, key
and password is an encrypted secret of a protected GitHub environment.

## How personal data stays out

- **Secrets live in the `store-release` environment**, not in the repo and not
  as repository-wide secrets, so no other workflow (including the pull-request
  preview) can read them.
- **Only you can run it**: the environment requires your approval and only
  accepts the `main` branch. Workflows started from forks never receive
  secrets.
- **Public logs stay clean**: GitHub masks secret values in logs, and the
  workflow never echoes them.
- **No artifacts**: the signed `.ipa` and `.aab` go straight to the stores.
  Artifacts of a public repo can be downloaded by anyone, and a signed iOS
  build embeds the Team ID.
- **Key files are temporary**: they are written to the runner's temp folder,
  deleted at the end of the job, and the GitHub-hosted runner is discarded.

The published app itself still carries your Team ID, as every App Store app
does; Apple puts it in the signature.

## One-time setup

### 1. Create the environment

Settings → Environments → **New environment** → `store-release`:

- **Required reviewers**: yourself.
- **Deployment branches and tags**: *Selected branches* → `main`.

### 2. Apple secrets

Create an App Store Connect API key: App Store Connect → Users and Access →
Integrations → App Store Connect API → **Team Keys** → generate one with the
**Admin** role (automatic signing on a fresh runner needs it to create the
distribution certificate and profile). Download the `.p8` file; Apple lets you
download it only once.

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Your Team ID (developer.apple.com → Membership details) |
| `ASC_KEY_ID` | The key's Key ID |
| `ASC_ISSUER_ID` | The Issuer ID shown above the keys list |
| `ASC_KEY_P8` | The full text of `AuthKey_<KeyID>.p8`, including the BEGIN/END lines |

### 3. Google Play secrets

Use the same upload keystore as for local builds (`store/README.md`).

For the API: Google Cloud console → a project → **IAM & Admin → Service
accounts** → create one and add a JSON key. Enable the **Google Play Android
Developer API** for that project. Then Play Console → **Users and permissions**
→ invite the service account's e-mail, grant it access to fPaint with the
*Release* permissions.

| Secret | Value |
|---|---|
| `PLAY_UPLOAD_KEYSTORE_BASE64` | `base64 -i fpaint-upload-keystore.jks` |
| `PLAY_UPLOAD_KEYSTORE_PASSWORD` | Keystore password |
| `PLAY_UPLOAD_KEY_ALIAS` | Key alias (`upload`) |
| `PLAY_UPLOAD_KEY_PASSWORD` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | The service account's JSON key file contents |

### Setting them without leaving traces

`gh` reads the value from a prompt or a file, so it never lands in your shell
history:

```sh
gh secret set APPLE_TEAM_ID --env store-release            # paste at the prompt
gh secret set ASC_KEY_P8 --env store-release < ~/keys/AuthKey_XXXXXXXXXX.p8
base64 -i ~/keys/fpaint-upload-keystore.jks | gh secret set PLAY_UPLOAD_KEYSTORE_BASE64 --env store-release
gh secret set PLAY_SERVICE_ACCOUNT_JSON --env store-release < ~/keys/play-service-account.json
```

Keep the key files outside the repo folder (for example `~/keys/`).

### 4. Before the first automated run

- **Google Play**: the API can only update an app that exists. Create it in
  Play Console and upload the very first bundle by hand
  (`tool/build_play.sh`). Until the app has been published once, run the
  workflow with `play_status: draft`.
- **App Store Connect**: the app record for `com.vteam.fpaint` must exist under
  your team.

## Releasing

Actions → **Store Release** → *Run workflow*, or:

```sh
gh workflow run store-release.yml -f platform=both -f build_number=2 \
  -f play_track=internal -f play_status=draft
```

Approve the deployment when GitHub asks. `build_number` must be higher than
every build either store has seen; the version name comes from `pubspec.yaml`.
TestFlight builds then appear in App Store Connect after processing (about
10–30 minutes); submitting a version for review stays a manual step.
