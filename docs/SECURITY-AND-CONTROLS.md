# TilfazTV — Security & Control Surface Review (P0-2)

**Date**: 2026-05-07  
**Scope**: static manifest/code review of exported Android components, permissions, and ADB control paths in `android/app` (`sa.urtv.screensaver`) and `android/launcher` (`sa.urtv.home`).  
**Status**: review notes only. This is **not** a penetration test, Play Protect assessment, or device-verified proof. Validate on target Android TV/Google TV/Chromecast builds and your ADB tooling before relying on these controls operationally.

---

## Summary

The project intentionally exposes a small control surface for Android TV operation and maintenance:

- **System integrations**: DreamService (screensaver), boot/package-replaced receiver, HOME launcher activity.
- **Cross-app config bridge**: `ConfigProvider` is exported but protected by a **signature-level** read permission (`sa.urtv.screensaver.READ_CONFIG`).
- **ADB/script control**: `SaverReceiver` and `DockReceiver` are exported but protected by `android.permission.DUMP`, intended for **ADB shell / maintenance tooling** (not normal third-party apps).

The main risks to manage are: misconfiguration of signing (breaking or weakening the cross-app contract), accidental widening of exported surfaces, and trusting ADB control paths only in environments where shell/ADB access is already authorized.

---

## Permission inventory

### `sa.urtv.screensaver` (Android app)

| Permission | Type/use | Notes |
|---|---|---|
| `android.permission.INTERNET` | network | dashboard assets/APIs/updates as implemented by WebView/updater code. |
| `android.permission.ACCESS_NETWORK_STATE` | network state | connectivity-aware behavior. |
| `android.permission.RECEIVE_BOOT_COMPLETED` | boot receiver | re-arms update/job after boot/package replacement events declared in manifest. |
| `android.permission.WRITE_SETTINGS` | privileged/system setting write | manifest declares it; code uses it only for specific flows (e.g., idle/screensaver timeout) when allowed by platform/app grant (`Prefs.canWriteSettings`). **VERIFY** actual runtime behavior and user/owner grant path on target TVs. |
| `sa.urtv.screensaver.READ_CONFIG` | **custom, signature** | declared by app; protects reads of `ConfigProvider` for same-signed clients (launcher). |

### `sa.urtv.home` (launcher)

| Permission | Type/use | Notes |
|---|---|---|
| `android.permission.INTERNET` | network | wallpapers/optional card/web assets. |
| `android.permission.ACCESS_WIFI_STATE` | Wi-Fi info | status/pill display. |
| `android.permission.ACCESS_NETWORK_STATE` | network state | connectivity checks. |
| `android.permission.ACCESS_FINE_LOCATION` | location (Android 11 TV SSID constraints noted in code) | requested in manifest; Wi-Fi SSID readability on modern Android/TV may still depend on OS policy and grants. **VERIFY** behavior; keep only if needed. |
| `sa.urtv.screensaver.READ_CONFIG` | uses custom signature permission | required to query screensaver config provider. Works as intended only when both apps are signed compatibly with the app declaring the permission. |

---

## Exported component review

### `sa.urtv.screensaver`

| Component | Manifest | Protection / intent | Intended use | Review notes |
|---|---|---|---|---|
| `SettingsActivity` | exported `true`, `MAIN` + `LAUNCHER` + `LEANBACK_LAUNCHER` | normal launcher entry | user opens settings/app entry | Expected. Keep UI safe; avoid exposing sensitive debug actions. |
| `MainActivity` | exported `true` | no explicit permission in reviewed manifest | interactive preview/full-screen dashboard | Exported for explicit launch/preview scenarios. Confirm no sensitive intent extras are trusted unsafely. |
| `ScreenDream` (`DreamService`) | exported `true`, `BIND_DREAM_SERVICE` | bound by system DreamService contract | Android/Google TV screensaver/Ambient integration | Correct integration pattern. Service is non-interactive (`setInteractive(false)`), loads dashboard via `ScreenView`. |
| `UpdateJob` (`JobService`) | exported `false`, `BIND_JOB_SERVICE` | system job binding only | scheduled update work | Good (not app-exported). |
| `BootReceiver` | exported `true`, boot/package-replaced actions | receives selected system broadcasts | reschedule jobs / warm process on some TVs | Minimal implementation (`UpdateJob.schedule`). Do not add intent-controlled destructive behavior. |
| `SaverReceiver` | exported `true`, `android.permission.DUMP` | **DUMP-protected** ADB/shell control | read/apply selected screensaver settings, list cities, trigger update | Intended for shell tooling. Validates/normalizes inputs (city/teams/theme/panel/rating/photos/idle/genres/langs), checks before save. Returns data in broadcast result. **VERIFY** DUMP protection on target Android versions/OEM images. |
| `ConfigProvider` | exported `true`, `readPermission=sa.urtv.screensaver.READ_CONFIG` | **signature-protected read** | gives launcher fragment/home panel config for HomeCard | Read-only provider (`query` only). Returns settings needed for launcher card. Keep payload minimal; do not expose secrets/tokens. |

### `sa.urtv.home`

| Component | Manifest | Protection / intent | Intended use | Review notes |
|---|---|---|---|---|
| `MainActivity` | exported `true`, `HOME` + `DEFAULT`, `singleTask` | HOME launcher resolution | TV home screen replacement | Expected for a launcher. Back/Home behavior should remain safe/non-trapping (separately covered by P1-3). |
| `DockActivity` | exported `true` | no explicit permission in reviewed manifest | favorites/dock management UI; can be opened by screensaver/settings tooling | Reasonable for maintenance flow. Ensure no dangerous side effects from malformed intents. |
| `DockReceiver` | exported `true`, `android.permission.DUMP` | **DUMP-protected** ADB/shell control | get/list/set/reset dock, list hidden apps, hide/show packages | Intended for shell tooling. Uses `Dock` APIs; `SET_DOCK` skips unknown/hidden/over-limit apps and reports skipped entries. **VERIFY** DUMP protection and real-world ADB usage. |

---

## Intended ADB / maintenance control paths

> These commands are for authorized device maintenance/debugging. They depend on ADB access, app installation state, package/component names, and Android/OEM behavior.

### Screensaver settings (`SaverReceiver`, DUMP-protected)

Primary code: `android/app/src/main/java/sa/urtv/screensaver/SaverReceiver.java`  
Wrapper script: `optimize/saver.sh`

```bash
# Read current settings
adb shell am broadcast -n sa.urtv.screensaver/.SaverReceiver -a sa.urtv.screensaver.GET

# List supported cities
adb shell am broadcast -n sa.urtv.screensaver/.SaverReceiver -a sa.urtv.screensaver.CITIES

# Set selected options (examples from code/docs)
adb shell am broadcast -n sa.urtv.screensaver/.SaverReceiver -a sa.urtv.screensaver.SET \
  --es city 'الدوحة'
adb shell am broadcast -n sa.urtv.screensaver/.SaverReceiver -a sa.urtv.screensaver.SET \
  --es panel prayers --es home_panel none --es minrating 7 --es photos 30

# Trigger update check
adb shell am broadcast -n sa.urtv.screensaver/.SaverReceiver -a sa.urtv.screensaver.UPDATE
```

Notes:
- `idle` may require `WRITE_SETTINGS` or shell/system-side handling depending on TV policy; `SaverReceiver` reports when the app cannot change it.
- Treat `am broadcast` result `data` as the command response.

### Launcher dock control (`DockReceiver`, DUMP-protected)

Primary code: `android/launcher/src/main/java/sa/urtv/home/DockReceiver.java`  
Wrapper script: `optimize/dock.sh`

```bash
# List launchable apps known to launcher catalog
adb shell am broadcast -n sa.urtv.home/.DockReceiver -a sa.urtv.home.LIST_APPS

# Get effective dock
adb shell am broadcast -n sa.urtv.home/.DockReceiver -a sa.urtv.home.GET_DOCK

# Set dock (installed/visible apps only)
adb shell am broadcast -n sa.urtv.home/.DockReceiver -a sa.urtv.home.SET_DOCK --es apps pkg1,pkg2,pkg3

# Reset to defaults
adb shell am broadcast -n sa.urtv.home/.DockReceiver -a sa.urtv.home.RESET_DOCK

# Inspect hidden/left-out apps and reasons
adb shell am broadcast -n sa.urtv.home/.DockReceiver -a sa.urtv.home.HIDDEN

# Hide/show apps
adb shell am broadcast -n sa.urtv.home/.DockReceiver -a sa.urtv.home.HIDE --es apps pkg1,pkg2
adb shell am broadcast -n sa.urtv.home/.DockReceiver -a sa.urtv.home.SHOW --es apps pkg1,pkg2
```

### HomeCard config bridge (signature-protected)

Primary code: `ConfigProvider.java` (app) and `HomeCard.java` (launcher).  
Not an ADB command path; launcher reads via:

```text
content://sa.urtv.screensaver.config
columns: fragment, home_panel
permission: sa.urtv.screensaver.READ_CONFIG (signature)
```

Debug note: both apps must be signed compatibly for the signature permission to grant as intended. Debug builds from different environments may not satisfy production assumptions.

---

## Recommendations

1. **Keep control receivers narrow**: do not add file paths, arbitrary URLs, shell-like commands, or privileged mutations to `SaverReceiver`/`DockReceiver` intents.
2. **Preserve least privilege**: keep `UpdateJob` non-exported; keep provider read-only; revisit `ACCESS_FINE_LOCATION`/`WRITE_SETTINGS` if runtime evidence shows they are unnecessary on supported targets.
3. **Document signing/debug behavior**: `ConfigProvider` + `READ_CONFIG` depends on compatible signing; `setup.ps1`/release installs should make this explicit for troubleshooting HomeCard.
4. **Validate on real targets**: confirm `DUMP` enforcement, DreamService registration, boot receiver delivery, and idle-timeout settings behavior on Android TV and Chromecast with Google TV.
5. **Operational hygiene**: treat ADB access as privileged maintenance access. Do not expose equivalent unauthenticated controls over network endpoints.
6. **Future change trigger**: re-run this review whenever adding new exported components, intent extras, WebView JS interfaces, update URLs, or cross-app IPC.

---

## Backlog mapping

- Addresses **P0-2** (review/exported-component/permissions notes and ADB control paths).
- Supports **P0-5** verification context (signature-protected config bridge).
- Follow-up implementation/testing remains: device verification, README/ops docs alignment, and any code changes only if a concrete issue is found.
