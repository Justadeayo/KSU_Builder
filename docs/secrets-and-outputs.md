# Secrets and outputs

## Contents

- [Repository secrets](#repository-secrets)
- [Keystore for release-signed Manager builds](#keystore-for-release-signed-manager-builds)
- [Where the outputs go](#where-the-outputs-go)

---

## Repository secrets

Set these under *Settings → Secrets and variables → Actions*. Workflows read them directly; none of them is a workflow input.

| Secret | Used by | Needed for |
| :--- | :--- | :--- |
| `TELEGRAM_BOT_TOKEN` | `bakasu.yml`, `kernelsu.yml` | Telegram start, finish and failure messages |
| `TELEGRAM_CHAT_ID` | `bakasu.yml`, `kernelsu.yml` | The chat that receives the messages |
| `RELEASE_KEYSTORE_BASE64` | `build-manager.yml` | Base64 of the release keystore, for release-signed Manager APKs |
| `RELEASE_KEYSTORE_PASSWORD` | `build-manager.yml` | Keystore password |
| `RELEASE_KEY_ALIAS` | `build-manager.yml` | Key alias inside the keystore |
| `RELEASE_KEY_PASSWORD` | `build-manager.yml` | Key password |
| `BOT_TOKEN` | `build-manager.yml` | Checked before a step runs; set it only if that step needs it |
| `GITHUB_TOKEN` | `build-env.yml` | Provided by GitHub. Used to push the build image |

`release.yml` and `kernelsu.yml` pass secrets to called workflows with `secrets: inherit`, so the secrets above only need to be set once on the repository.

---

## Keystore for release-signed Manager builds

`build-manager.yml` decodes `RELEASE_KEYSTORE_BASE64` and needs the three other keystore secrets to sign the APK. If `RELEASE_KEYSTORE_BASE64` is missing, the build stops with an error.

To create the base64 value:

```
base64 -w0 release.keystore > release.keystore.b64
```

Paste the contents of `release.keystore.b64` into `RELEASE_KEYSTORE_BASE64`, then delete the local copies. Never commit the keystore or its base64 form.

---

## Where the outputs go

| Output | Produced by | Where it ends up |
| :--- | :--- | :--- |
| Kernel zip | `bakasu.yml`, `kernelsu.yml` | Artifact `kernel-zip` (kernelsu), `xcalibur-xf-<device>-<variant>` (bakasu), and the Telegram finish message |
| Manager APK | `build-manager.yml` | Artifact `manager`, attached to the finish message when `build_manager` is set |
| `ksud` binaries | `build-manager.yml` | Artifact `ksud-<target>` |
| Manager Gradle outputs | `build-manager.yml` | Artifact `manager-gradle` |
| Debug logs | `bakasu.yml` | Artifact `debug-<device>-<variant>` |
| Patch rejects | `bakasu.yml` | Artifact `xcalibur-xf-<device>-<variant>-rejects` |
| Version info | `bakasu.yml` | Artifact `xcalibur-xf-<device>-<variant>-versions` |
| GitHub Release | `release.yml`, and `bakasu.yml` with `create_release` | Release page, with the zip and the Manager APK |

`scripts/notify.sh` sends the Telegram messages: one start message, one finish message with the files once the build succeeds, and a failure message if it doesn't.
