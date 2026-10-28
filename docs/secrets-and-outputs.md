# Secrets and outputs

[← Home](../README.md) · [Workflows](workflows.md) · [Build a SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · **Secrets and outputs** · [Forking](forking.md) · [Troubleshooting](troubleshooting.md) · [History](history.md)

---

## Contents

- [Repository secrets](#repository-secrets)
- [Keystore for release-signed Manager builds](#keystore-for-release-signed-manager-builds)
- [Where the outputs go](#where-the-outputs-go)

## Repository secrets

Add these under **Settings** → **Secrets and variables** → **Actions**.

| Secret | Used by | Description |
| :--- | :--- | :--- |
| `TELEGRAM_BOT_TOKEN` | Telegram steps | Bot token from [@BotFather](https://t.me/botfather) |
| `TELEGRAM_CHAT_ID` | Telegram steps | Chat or channel ID, e.g. `-1001234567890` |
| `SYNC_PAT` | `sync.yml` | Personal access token with repo and workflow permissions |

To get the chat ID, message your bot and check the update log, or use [@userinfobot](https://t.me/userinfobot).

If the Telegram secrets aren't set, the Telegram steps are skipped and the build still runs. `build-custom.yml` also takes the token and chat ID as inputs, which override the secrets for that run.

## Keystore for release-signed Manager builds

Non-PR builds use the dummy keystore in `build-manager.yml`. To sign with your own key:

1. Create a keystore file.
2. Encode it: `base64 -w 0 my.keystore > encoded.txt`.
3. Add it as a secret, for example `KEYSTORE_FILE`.
4. Update `build-manager.yml` to use it.

## Where the outputs go

**Releases:** created by `release.yml`, or by `create_release` in `build.yml` and `build-custom.yml`.

**Actions artifacts:** open the run and scroll to **Artifacts**.

| Artifact | Produced by |
| :--- | :--- |
| `manager`, `manager-gradle`, `ksud-*`, `mappings` | `build-manager.yml` |
| `kernel-zip` | `automated.yml`, `kernel.yml`, `kernel_build.yml`, `Kernel_&_Manager_build.yml` |
| `kernel-raw-outputs` | `kernel_build.yml` |
| `xcalibur-xf-<device>-<variant>` | `build.yml`, `build-custom.yml` |
| `debug-<device>-<variant>` | `build.yml`, `build-custom.yml` |
| `xcalibur-xf-<device>-ksu-versions` | `build.yml`, `build-custom.yml` (`ksu` only) |
| `xcalibur-xf-<device>-<variant>-rejects` | `build.yml`, `build-custom.yml` (failed builds only) |

**Telegram:**
- The kernel zip is sent on success. A failed build sends the last 35 log lines.
- `Dispatch` sends the Manager APK in the two workflows that build it.
- `release.yml` sends no Telegram message. Its build step does.

---

[← Master script](master-script.md) · [Next: Forking →](forking.md)
