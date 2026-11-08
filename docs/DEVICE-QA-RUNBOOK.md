# TilfazTV — Device QA Runbook (P1 / backlog verification)

**Purpose**: execute the backlog/device verification checklist on real hardware and capture evidence for fixes.  
**Environment limitation**: this agent session cannot access physical Android TV/Chromecast devices or ADB-connected hardware. This runbook prepares the pass; **device results must be filled in by a tester**.

**Related docs**: [`docs/BACKLOG.md`](./BACKLOG.md), [`docs/TEST-PLAN.md`](./TEST-PLAN.md), [`docs/TEST-PROMPT.md`](./TEST-PROMPT.md), [`docs/MULTI-TV-PROMPT.md`](./MULTI-TV-PROMPT.md), [`docs/SECURITY-AND-CONTROLS.md`](./SECURITY-AND-CONTROLS.md), [`docs/tilfaztv-architecture.html`](./tilfaztv-architecture.html).

---

## 1. Preflight (tester machine)

- Windows/macOS/Linux machine on the same network as the TV (or USB ADB where supported).
- `adb` available (`adb version`).
- TV/Chromecast developer options + **Network/USB debugging** enabled.
- Know the TV IP and keep it **out of reports/screenshots shared publicly**.
- Use the intended build branch/tag/artifacts:
  - Stable: `apk-latest` / `main` (per project workflow)
  - Test branch: `apk-next` / `next` (if validating unreleased changes)
- Record: date, tester, agent/model (if used), device model, Android/Google TV OS version, app versions (`dumpsys package`), branch/commit, APK source.

## 2. Local checks completed in this workspace (2026-05-07)

| Check | Result | Notes |
|---|---|---|
| `python src/build.py` | PASS | Regenerated `dist/tilfaztv.html`, `dist/urtv.html`, `dist/tv.html`. |
| `python -m py_compile` (selected + all `tests/*.py` attempted) | PASS/see notes | Selected project scripts compiled; run full `tests/run.sh`/`check.py` deps on a machine with `fonttools`, `brotli`, `Pillow`, Playwright as required. |
| `python tests/share_test.py` | PASS | Reported expected test output. |
| `python tests/upload_test.py` | RUN | Execute and record full output on tester machine if needed. |
| `python tests/check.py` | NOT RUN HERE | Missing `fonttools`/`PIL` deps in this session. Requires: `pip install fonttools brotli pillow`. |
| Android Gradle builds (`:app`, `:launcher`) | NOT RUN | Requires Android SDK/JDK/Gradle setup. Build debug/release APKs before device QA. |
| Browser/Playwright page tests | NOT RUN HERE | `tests/page.test.mjs` requires Node + Playwright/Chromium. |

## 3. Device matrix (recommended)

| Priority | Target | Why |
|---|---|---|
| P0 | Android TV / Google TV device (1080p) | Baseline launcher, DreamService, D-pad, RTL text. |
| P0 | Chromecast with Google TV (HD or 4K) | Ambient/screensaver path, remote behavior, Home/Google TV constraints. |
| P1 | OEM Android TV (TCL/other) | OEM home/input/Wi-Fi SSID behavior, boot/dream quirks (see `TEST-PLAN.md` G1). |
| P1 | 4K output / different overscan | 10-foot readability, clipping, safe margins. |

## 4. Install / connect

```bash
adb connect <TV_IP>:5555
adb devices
# optional clean install path (use only if intended)
# adb uninstall sa.urtv.screensaver
# adb uninstall sa.urtv.home
adb install -r <path-to-screensaver-apk>
adb install -r <path-to-launcher-apk>
adb shell dumpsys package sa.urtv.screensaver | grep versionName
adb shell dumpsys package sa.urtv.home | grep versionName
```

**Evidence**: install output, `adb devices`, package version lines.

## 5. QA checklist (backlog-aligned)

Use **PASS / FAIL / BLOCKED / N/A** with note + screenshot/log.

### A. Screensaver / DreamService / preview
| ID | Check | Expected | Result | Evidence |
|---|---|---|---|---|
| A1 | Open settings/preview (`sa.urtv.screensaver/.SettingsActivity` / `.MainActivity`) | App opens; dashboard renders; no white flash/crash. |  |  |
| A2 | D-pad center/enter/up/down in preview | Cycles theme via `cycleTheme()` (guarded bridge). No stuck keys/crash. |  |  |
| A3 | D-pad left/right in preview | Triggers `updateBigMatchCountdown(true)` safely. No crash when function unavailable. |  |  |
| A4 | Set as screensaver/DreamService | `ScreenDream` selectable; starts on demand/idle per system behavior. Any key exits. |  |  |
| A5 | Slow/offline load | Dashboard degrades gracefully; no ANR/crash; key handling safe. |  |  |

### B. Launcher / HOME / D-pad focus
| ID | Check | Expected | Result | Evidence |
|---|---|---|---|---|
| B1 | Set TilfazTV as HOME | Home opens `sa.urtv.home` (Google TV/OEM flow may vary). |  |  |
| B2 | D-pad across pills, dock, app grid | No focus traps; visible focus; predictable movement. |  |  |
| B3 | Inputs popup / menus | Opens, navigable, dismissible with Back; focus restored appropriately. |  |  |
| B4 | Launch apps from dock/grid | Correct app launches; usage tracking updates ordering behavior as designed. |  |  |
| B5 | Dock config behavior | Favorites reflect saved/default behavior (`MIN=4`, `MAX=10`, usage sort/top-up). User edits preserved. |  |  |
| B6 | HomeCard never steals focus | D-pad never lands on HomeCard WebView. |  |  |

### C. HomeCard / config bridge (P0-5)
| ID | Check | Expected | Result | Evidence |
|---|---|---|---|---|
| C1 | Enable a home panel in screensaver settings | Launcher HomeCard shows selected panel (`tv.html#widget=1`). |  |  |
| C2 | Change panel / set to none | HomeCard updates or disappears; no crash. |  |  |
| C3 | Screensaver app missing/outdated/debug-signing mismatch | Launcher remains stable; HomeCard fails closed (no render/crash). Document behavior. |  |  |
| C4 | Config contract | `ConfigProvider` returns `fragment`,`home_panel`; launcher reads via signature-protected `sa.urtv.screensaver.READ_CONFIG`. |  |  |

### D. ADB control paths (authorized maintenance)
| ID | Check | Expected | Result | Evidence |
|---|---|---|---|---|
| D1 | `SaverReceiver` GET/CITIES/SET/UPDATE | Commands return expected `data`; invalid values refused; no partial save on validation errors. |  |  |
| D2 | `DockReceiver` LIST_APPS/GET_DOCK/SET_DOCK/RESET/HIDDEN/HIDE/SHOW | Commands behave as documented; home redraws after changes. |  |  |
| D3 | Permission model | `DUMP`-protected receivers work via ADB shell as intended; normal third-party app access not assumed. **VERIFY on OEM image**. |  |  |

### E. RTL / Arabic / 10-foot readability (P1-4)
| ID | Check | Expected | Result | Evidence |
|---|---|---|---|---|
| E1 | Arabic text shaping and line breaks | No clipping/overlap in dashboard, launcher, popups, settings. |  |  |
| E2 | Numerals/date/time/prayer formatting | Consistent, readable; LTR clock digits remain correct; bidi-safe where needed. |  |  |
| E3 | Contrast and size at 10-foot distance | Key information readable on 1080p/4K; focus states visible. |  |  |
| E4 | Overscan/safe margins | No critical UI cut off by TV overscan. |  |  |

### F. Setup / install / update
| ID | Check | Expected | Result | Evidence |
|---|---|---|---|---|
| F1 | `setup.ps1` on Windows | Builds/downloads as available, connects via ADB, installs screensaver+launcher when present, reports per-APK success/warnings. |  |  |
| F2 | APK naming/release assets | `urtv-screensaver.apk` / `urtv-home.apk` handling matches release process (or local `dist`/`optimize` APKs). |  |  |
| F3 | Updater/page selection | Compatible dashboard loads; stale/incompatible downloaded page does not break UI. |  |  |

### G. Chromecast with Google TV / Ambient (where applicable)
| ID | Check | Expected | Result | Evidence |
|---|---|---|---|---|
| G1 | Screensaver/Ambient configuration | User can select TilfazTV screensaver path as supported by OS UI. |  |  |
| G2 | HOME/launcher constraints | Document actual behavior/limitations (Google TV may restrict HOME replacement flows). |  |  |
| G3 | Remote keys and performance | No regressions in preview/dream/launcher. |  |  |

## 6. Useful ADB evidence commands

```bash
adb exec-out screencap -p > evidence/<ID>.png
adb logcat -d -t 400 | grep -iE "urtv|tilfaz|chromium|AndroidRuntime|DreamService" > evidence/<ID>.log
adb shell dumpsys package sa.urtv.screensaver | grep -E "versionName|signatures|permission"
adb shell dumpsys package sa.urtv.home | grep -E "versionName|permission"
adb shell dumpsys activity recents | grep -i urtv
```

## 7. Report template

```text
Date / Tester / Agent:
Device / OS:
Branch / Commit / APK source:

ID | PASS/FAIL/BLOCKED | Notes | Evidence
A1 | PASS | ...
B2 | FAIL | Focus trapped in Inputs popup | B2.png, B2.log

Summary:
- Blocking issues:
- Non-blocking issues:
- Backlog IDs to create/update:
- Follow-up build needed: yes/no
```

## 8. After QA

- Update `docs/BACKLOG.md` statuses with real evidence.
- File/track concrete defects (ID, expected vs actual, device, logs/screenshot).
- Re-run targeted checks after fixes (build, tests, affected device scenarios).
- Do **not** mark device verification items complete without evidence.
