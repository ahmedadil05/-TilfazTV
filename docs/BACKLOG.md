# TilfazTV — Prioritized Fix & Edit Backlog

**Date**: 2026-05-07  
**Scope**: `D:\ahmed\DevOps\2_High_Potential_Products\TilfazTV` (current working tree)  
**Artifacts**: architecture diagram at [`docs/tilfaztv-architecture.html`](./tilfaztv-architecture.html)  
**Method**: static repo audit (README, build, Android app/launcher manifests+sources, template/dashboard integration points, setup script, workflows, tests). Items marked **VERIFY** require device/emulator/runtime confirmation before code changes that could regress behavior.

## Status update (implemented in working tree)

| ID | Status | Notes |
|---|---|---|
| P0-2 | **Documented** | Exported components/permissions reviewed; ADB control paths and signature config bridge documented in [`docs/SECURITY-AND-CONTROLS.md`](./SECURITY-AND-CONTROLS.md). No code changes. **VERIFY** `DUMP`/signature behavior on target devices/OEM builds. |
| P0-3 | **Partially fixed** | `setup.ps1` now ensures `dist/` exists, checks `build.py` exit code, attempts download of both `urtv-screensaver.apk` and `urtv-home.apk` when no local APKs are found, uses `adb -s <ip>:5555 install -r`, reports per-APK success/warnings, and only reports full install success when installs actually succeeded. **VERIFY** on a Windows machine with ADB + Android TV/Chromecast. |
| P0-4 | **Partially fixed** | `android/app/.../MainActivity.java` routes dashboard JS calls through `evalDashboardJs()` with a null/`RuntimeException` guard; JS function presence checks remain. **VERIFY** with screensaver preview/remote keys on device. |
| P0-5 | **Reviewed, no code change yet** | `HomeCard`/`ConfigProvider` contract looks aligned (fixed 2-column cursor, fragment sanitization, fail-closed null handling). Needs device verification with both apps signed compatibly and with missing/outdated screensaver app. |
| P1-1 | **Partially fixed** | README EN+AR dock claims aligned to actual behavior (configurable favorites dock, 4–10 apps, usage-based ordering; regional defaults when installed). Other README claims (countdown/Chromecast/setup/screenshots) still need runtime verification. |
| P1-2 | **Documented/aligned** | Preserved current semantics (`Dock.MIN=4`, `MAX=10`, usage-sorted, top-up, configurable via long-press/«ترتيب المفضلة»/ADB). No code change. Alternative (not chosen): strict 4-app UX by changing `Dock.MAX`/defaults/copy. **VERIFY** on TV. |
| P1-3 | **In progress (targeted fixes)** | Dashboard `template.html` theme pill now has `:focus-visible` ring (removed focus outline suppression only for keyboard focus path). Screensaver app D-pad JS bridge hardened (P0-4). Native launcher focus wiring already explicit (`nextFocus*`, popup row focus, focus restore) — needs device walkthrough. | **VERIFY** D-pad traversal on Android TV/Google TV/Chromecast. |
| P1-4 | **In progress (targeted fixes)** | `template.html` already uses `lang="ar" dir="rtl"` and LTR clock formatting. Launcher manifest now declares `android:supportsRtl="true"`. Small launcher cleanup removed duplicate gravity assignment. Full RTL/bidi numerals, truncation, and 10-foot contrast still need device/visual review. | **VERIFY** Arabic rendering, numerals, truncation, and contrast on 1080p/4K TV. |

---

## Priority legend

| Priority | Meaning | Exit criteria |
|---|---|---|
| **P0** | Correctness, installability, data loss/security exposure, or broken core TV flow | Reproduced/fixed, regression checked on target device/build |
| **P1** | UX/RTL/accessibility, platform compatibility, maintainability, release reliability | Implemented with acceptance checks; docs updated |
| **P2** | Polish, consistency, performance tuning, observability, future-proofing | Scheduled after P0/P1; evidence-based |

---

## P0 — Correctness & safety

| ID | Area | Issue / task | Evidence / targets | Action | Acceptance |
|---|---|---|---|---|---|
| P0-1 | Release/install identity | Confirm **package IDs, signing key continuity, and APK artifact names** before any rename. Legacy `sa.urtv.*` and `urtv-*.apk` names remain; user-facing brand is TilfazTV. | `android/app/build.gradle`, `android/launcher/build.gradle`, manifests (`sa.urtv.screensaver`, `sa.urtv.home`), `setup.ps1`, release workflow assumptions | **Do not rename applicationId** in a routine fix. Create a deliberate migration plan only if renaming is required; keep user-facing strings/README accurate in the meantime. | No accidental update/install breakage; release builds install/upgrade as intended. |
| P0-2 | Exported components | Review exported Android components for least privilege and intended use. | `app` manifest exports `SettingsActivity`, `MainActivity`, `ScreenDream` (permission-bound), `BootReceiver`, `SaverReceiver` (`android.permission.DUMP`), `ConfigProvider` (signature read permission). `launcher` exports HOME activity, `DockActivity`, `DockReceiver` (`DUMP`). | Validated each exported surface is required; confirm `DUMP`/signature protections behave as expected; ensure ADB/agent tooling still works (`optimize/*`/docs references if present). Add threat notes to docs. | **Reviewed/documented** in [`docs/SECURITY-AND-CONTROLS.md`](./SECURITY-AND-CONTROLS.md). No code changes made. **VERIFY** on device/ADB/OEM behavior. |
| P0-3 | Setup/install flow | `setup.ps1` downloads `urtv-screensaver.apk` from GitHub latest release and installs any APKs found in `dist`/`optimize`; launcher install path is not explicit. | `setup.ps1:114-137`, README quick setup | Make artifact handling explicit: detect/install **screensaver and launcher** APKs as required, use current names/paths, fail loudly on missing ADB/device/auth, and keep UTF-8/Arabic console output readable. | Fresh Windows + TV/Chromecast setup succeeds or gives actionable errors. **VERIFY** end-to-end. |
| P0-4 | WebView/native JS contract | Screensaver `MainActivity` dispatches D-pad to `cycleTheme()` and left/right to `updateBigMatchCountdown(true)`. | `android/app/.../MainActivity.java:41-52`, `src/template.html` has `cycleTheme` (~524) and `updateBigMatchCountdown` (~1015) | Add safe guards/no-op behavior when functions are unavailable (e.g., widget/alternate modes or load failures). Keep key handling from consuming events incorrectly. | No JS errors/crashes; remote keys behave predictably in preview/screensaver modes. **VERIFY** on TV WebView. |
| P0-5 | Config provider contract | Launcher `HomeCard` reads screensaver config via `content://sa.urtv.screensaver.config` (signature permission) and loads `file:///android_asset/web/tv.html#...&widget=1`. | `launcher/.../HomeCard.java`, `app/.../ConfigProvider.java`, `app/.../Prefs.java`, `launcher/build.gradle` `copyWeb` task | Verify query columns/order, null handling, fragment sanitization, and font interception for packaged/offline use. Document/debug caveat: both apps must be signed compatibly to read protected config. | HomeCard renders selected panel when enabled; fails closed (no crash) when screensaver/config unavailable. **VERIFY**. |
| P0-6 | Updater/page selection | `Prefs.dashboardUrl()` prefers downloaded page only when `autoUpdate` and file is newer than app `lastUpdateTime`; otherwise uses `file:///android_asset/tv.html`. | `app/.../Prefs.java:167-177`, `ScreenView`, `Updater/UpdateJob` | Confirm update source trust, rollback behavior, and stale/broken download handling. Avoid serving incompatible cached pages across app upgrades. | Screensaver always loads a compatible dashboard; update failures don’t brick UI. **VERIFY**. |

---

## P1 — UX, RTL, TV platform, and maintainability

| ID | Area | Issue / task | Evidence / targets | Action | Acceptance |
|---|---|---|---|---|---|
| P1-1 | README/feature alignment | README claimed “4-app smart dock” while implementation is configurable/usage-sorted (`Dock.MIN=4`, `MAX=10`, defaults >4 in `config.xml`). | `README.md`, `launcher/res/values/config.xml`, `Dock.java`, `template.html` | **Decision (implemented):** align docs to actual behavior (keep configurable favorites dock, 4–10 apps, usage-based ordering; regional defaults when installed). Updated EN+AR dock sections in README. Alternative if desired: enforce strict 4-app UX by changing `Dock.MAX`/defaults/UI copy. | **Partially fixed** (dock claims aligned). Remaining README items (match countdown/Chromecast/setup screenshots/behavior) still need runtime verification. |
| P1-2 | Dock semantics & defaults | “Smart 4-App Dock” vs actual dock capacity/sorting (`MIN`/`MAX`/shown/top-up/hidden rules). | `Dock.java`, `DockActivity`, `DockReceiver`, `config.xml`, launcher `MainActivity` | **Decision (documented):** preserve current semantics (usage-sorted favorites, min 4/top-up, max 10, customizable via long-press/«ترتيب المفضلة»/ADB). README now reflects this. Only change code if product chooses strict 4-app mode. | **Documented/aligned**. **VERIFY** behavior on TV; preserve user-saved `dock` pref. |
| P1-3 | 10-foot focus & D-pad UX | Native launcher has explicit focus wiring; popups/menus/cards must remain fully remote-navigable. Web dashboard in WebView has limited remote mapping. | `launcher/.../MainActivity.java` (`wireFocus`, popups, key handling), `app/.../MainActivity.java`, `template.html` | Test and fix focus traps, missing `nextFocus` targets, scroll-to-row behavior, and popup dismissal. Ensure HomeCard never steals focus. | All primary actions reachable by D-pad/Back/Home. **VERIFY** on Google TV/Chromecast + OEM skin if possible. |
| P1-4 | Arabic RTL / bidi quality | Arabic-first UI across native TextViews and WebView; numerals/time/prayer/match labels must render consistently. | `template.html`, `build.py` text processing, `HomeCard`/`ScreenView` WebView, launcher strings/layouts, settings UI | Apply `arabic-rtl-typography` + `impeccable`/`ui-ux-pro-max`: verify `dir`/alignment, Arabic-Indic vs Latin numeral policy, truncation/line-height, font loading (Thmanyah/Noto), and bidi isolates where needed. | Legible, consistent Arabic/RTL at 10-foot distance; no clipping/overlap. **VERIFY** on 1080p/4K. |
| P1-5 | Visual/theme coherence | Qatar Al-Adaam, Royal Amiri, Noor themes exist in dashboard; launcher/native surfaces have their own styling. Branding should feel coherent without forcing identical UI paradigms. | `template.html` themes, launcher drawables/colors/styles, README branding, `DESIGN.md` absent | Define/record a small design token set (colors, type, radii/shape rules for TV, focus states). Use `design-md` if formalizing; `impeccable` for critique/polish. | Coherent TilfazTV identity across screensaver, launcher, settings, docs. |
| P1-6 | Dashboard performance & resilience | Large standalone HTML bundles exist; Android path uses `dist/tv.html`. WebView performance, network calls, and timers affect TV smoothness. | `dist/tv.html` vs `tilfaztv.html`/`urtv.html`, `ScreenView` cache mode, `PhotoCache`/`Updater`, template JS intervals/APIs | Profile on low-end TV if possible. Keep Android using packaged `tv.html`; handle offline/API errors with calm fallbacks; avoid excessive reflows/timers. | Smooth ambient display; graceful offline behavior. **VERIFY**. |
| P1-7 | Build determinism & inputs | `build.py` reads shared JSON/assets and emits bundles; missing files may warn/skip (e.g., backgrounds). | `src/build.py`, `assets/shared/*`, `assets/backgrounds/*` | Add clear preflight checks/messages for required inputs; document local build prerequisites; ensure CI/local parity where practical. | `python src/build.py` produces expected bundles or actionable errors. |
| P1-8 | Test coverage & runnable checks | Tests exist (`tests/*.py`, `tests/page.test.mjs`, Java/team search tests) but coverage/CI integration is unclear from audit. | `tests/`, `.github/workflows/checks.yml` (not fully audited) | Inventory existing tests, run locally where feasible, fix broken tests, and add focused tests for build/config contract regressions. | Reproducible checks for core non-device logic. |

---

## P2 — Polish, ops, and evolution

| ID | Area | Issue / task | Evidence / targets | Action | Acceptance |
|---|---|---|---|---|---|
| P2-1 | Diagrams & docs hygiene | Architecture now documented; other flows (update, HomeCard config, dock rules) may deserve focused diagrams. | `docs/tilfaztv-architecture.html`, `docs/OPTIMIZE.md`, `docs/TVS.md`, `docs/TEST-PLAN.md` | Add targeted diagrams only where they reduce ambiguity (data flow, deployment/install, state map for dashboard card modes). Keep style/profile decision documented (`.diagram-design` if customized later). | Docs help onboarding/debugging without duplication. |
| P2-2 | Accessibility & clarity | TV has different accessibility constraints than mobile/web; still benefit from contrast, readable sizes, clear labels, and non-color-only meaning. | Dashboard panels, launcher icons/labels, settings | Use `ui-ux-pro-max` accessibility rules pragmatically for 10-foot UI; validate contrast/focus states. | Improved readability and reduced ambiguity. |
| P2-3 | Observability/debuggability | ADB receivers and optimize scripts exist; runtime failures on TV can be opaque. | `SaverReceiver`, `DockReceiver`, `PhotoCache`, updater/log paths (if any) | Standardize debug logging behind safe flags/build variants; document ADB commands for support. | Faster diagnosis on real devices. |
| P2-4 | Branding migration plan | Long-term move from UrTV identifiers/names to TilfazTV (if desired) needs staged plan. | package IDs, repo URLs, release assets, updater endpoints, docs | Write migration RFC/checklist covering IDs, signing, upgrades, data migration, store/distribution constraints. | Future rename can happen safely. |
| P2-5 | Security hardening pass | WebView file access/CORS settings, external fetches, exported receivers/providers, and update channels deserve periodic review. | `ScreenView`, `HomeCard`, manifests, updater/network code | Run a targeted review when changing network/update behavior; avoid adding broad permissions. Consider `find-security-vulnerabilities-in-code` skill only for a scoped security audit. | No new risky exposures; decisions documented. |

---

## Skills / agents to apply during implementation

| Need | Skill / agent | How to use |
|---|---|---|
| Architecture/flow diagrams | `diagram-design` | Generate/iterate HTML diagrams in `docs/`; set `.diagram-design` profile if brand skin is customized. |
| Arabic RTL/bidi typography | `arabic-rtl-typography` | Review dashboard, launcher, settings, setup/docs copy for RTL, numerals, line-height, font pairing. |
| UI critique & polish | `impeccable` | Audit/polish web dashboard and native Android screens; preserve product truth. |
| UI/UX checklist & data UI | `ui-ux-pro-max` | Accessibility, interaction, responsive/TV readability, color/typography, loading/error states. |
| Design tokens/design system doc | `design-md` / `design-system` | Capture TilfazTV tokens once visual decisions stabilize. |
| Public web/docs page styling | `design-taste-frontend` | Use only for marketing/docs/share pages, not TV ambient/HOME internals. |
| Copy cleanup | `stop-slop` | After factual fixes to README/docs/UI strings. |
| Fast codebase search | `subagent` `explore` | Locate usages, manifest/resource references, test harnesses. |
| Parallel implementation/research | `subagent` `general` | Split independent tracks (docs, build, Android modules) after baseline agreement. |

---

## Recommended execution order

1. **P0-2/P0-5/P0-4** contract & exported-component review (low code churn, high leverage). *(done/reviewed/partially fixed; verify on device)*
2. **P0-3** `setup.ps1` reliability + explicit APK handling. *(partially fixed; verify on device)*
3. **P1-1/P1-2** align README and dock behavior (decide product intent first). *(docs aligned; verify on device)*
4. **Device QA pass** using [`docs/DEVICE-QA-RUNBOOK.md`](./DEVICE-QA-RUNBOOK.md) and [`docs/TEST-PLAN.md`](./TEST-PLAN.md). *(prepared; blocked on physical Android TV/Chromecast hardware in this session)*
5. **P1-3/P1-4/P1-6** TV/RTL/performance pass with device evidence, then **P1-7/P1-8** build/test reliability and P2 improvements.

## Verification checklist (before closing a fix batch)

```text
[ ] python src/build.py succeeds and emits expected dist/ bundles
[ ] Android debug builds succeed for :app and :launcher (local SDK/Java configured)
[ ] Relevant tests in tests/ pass (or failures triaged with evidence)
[ ] Screensaver preview loads dashboard; remote D-pad actions behave safely
[ ] DreamService/screen saver selectable on Android TV / Google TV
[ ] Launcher set as HOME; dock/app grid/inputs/popup focus fully D-pad navigable
[ ] HomeCard shows selected panel when enabled; no crash when config unavailable
[ ] setup.ps1 installs intended APKs on a test device or reports actionable errors
[ ] README/docs match actual behavior and artifact names
```