# تلفازك · TilfazTV (Qatar, Royal & Noor Editions) — Recreate Prompt

Paste everything below the line into any AI or coding assistant to recreate or extend the dashboard screen from scratch.

---

## Goal

Build ONE self-contained HTML file (no external build tools, no runtime JS framework dependencies) that runs full-screen on a 16:9 TV at 1920×1080 as an always-on screensaver and dashboard. Arabic only, right-to-left, with default localization for **Doha, State of Qatar** (`Asia/Qatar`, 25.2854° N, 51.5310° E). The visual identity combines **Qatari National Al-Adaam heritage**, **Royal Amiri Gold prestige**, and **Spiritual Noor calm** — photographic, high-contrast, edge-aligned, never cluttered.

## Architecture: Edge-Based Open Layout (1920×1080)

To showcase high-resolution national landmarks, royal portraits, and desert landscapes, the **center of the screen must remain 100% open and unobstructed**.

1. **Top Edge Bar (Right-to-Left):**
   - **Right Corner:** Dual calendar. Gregorian date under the Hijri date in authentic Arabic-Indic numerals (`١٤٤٨ هـ`).
   - **Left Corner:** Live weather (temperature in display font, condition keyword, e.g. `صافي`, `غائم جزئياً`) and quiet market ticker indicators (`تاسي`, `S&P 500`, `بيتكوين`).
   - Gold hairline dividers anchored at both corners, softly fading toward the open center.

2. **Middle Side Panel & Floating Clock:**
   - **Floating Clock:** 12-hour Arabic digits (`١٢:٤٥`) with gold colon and `ص`/`م` indicator. Centered between the side card and the edge, leaving the middle wide open. Subtitle: `بتوقيت الدوحة` (or selected city).
   - **Translucent Side Card (Left):** Blur-backed frosted glass (`backdrop-filter: blur(16px)`). Cycles through:
     - Today's verified Ayat & Hadith with Quranic brackets (`﴿ ﴾`) and honorifics (`ﷺ`).
     - Accurate 5-prayer times schedule.
     - 5-day weather forecast.
     - Live Big Match countdown and club fixtures.

3. **Bottom Edge Bar:**
   - **Right:** Next prayer countdown with Iqama timer (`الفجر ٤:٤٢ ص` · `بعد ساعتين`).
   - **Center:** Seasonal National & Spiritual Countdown:
     - **December 1–17:** Qatar National Day Countdown (`اليوم الوطني لدولة قطر 🇶🇦` · `١٨ ديسمبر`).
     - **December 18:** Full celebration banner (`مطوعين الصعايب · كل عام وقطر بخير 🇶🇦`).
     - **Rest of the year:** Ramadan Countdown & Iftar/Suhoor tracker.
   - **Left:** Big Match countdown (e.g. `السد ✕ الدحيل` or `الأهلي ✕ الريان`).

4. **Bottom App Dock (Leanback Launcher Mode):**
   - 4-app customizable dock with usage frequency learning (brings most-used apps forward).
   - Pre-configured for: Al Jazeera TV, TOD, beIN Sports, and Shahid.

---

## Visual Direction & Themes

The interface features an instant theme switcher (accessible via floating button or remote key `T`), plus a 24-hour automatic daylight lighting cycle:

1. **🇶🇦 Qatar Al-Adaam Theme (`theme-qatar`):**
   - Primary: Al-Adaam Maroon (`#580F23`), Crisp White (`#FFFFFF`), Warm Gold (`#D4AF37`).
   - Automatically activates on Qatar National Day (December 18).
2. **👑 Royal Amiri Gold Theme (`theme-royal`):**
   - Deep Midnight Obsidian (`#060B11`), Amiri Gold (`#C5A059`), Soft Amber (`#FFF9E6`).
   - Designed for royal majlis halls and palaces with automatic ambient glare reduction.
3. **🌙 Noor Spiritual Theme (`theme-noor`):**
   - Deep Emerald Green (`#041C14`), Quranic Gold (`#E0BA74`), Soft Parchment (`#FFFDF5`).
   - Emphasizes the daily Hadith from the Six Sunni Hadith Compendiums and Quranic verses.

---

## Data Providers (Free, No API Keys Required)

- **Prayer Times:** Aladhan API, **Method 8 (Gulf / Qatar Ministry of Awqaf & Islamic Affairs)**:
  `https://api.aladhan.com/v1/timings/DD-MM-YYYY?latitude=25.2854&longitude=51.5310&method=8&timezonestring=Asia/Qatar`
  Offline astronomical calculation fallback ensures 100% offline accuracy.
- **Weather:** Open-Meteo API:
  `https://api.open-meteo.com/v1/forecast?latitude=25.2854&longitude=51.5310&current=temperature_2m,weather_code&timezone=Asia/Qatar`
- **Sports & Fixtures:** TheSportsDB test key `123`:
  Qatar Stars League (QSL) clubs (Al-Sadd `136013`, Al-Rayyan `136137`, Al-Duhail, Al-Arabi) and national teams.
- **Markets:** Yahoo Finance chart endpoints (with AllOrigins fallback) and CoinGecko for crypto.

---

## Build Targets

- `dist/tilfaztv.html`: Complete standalone offline single-file dashboard with embedded Thmanyah fonts and photography.
- `dist/tv.html`: Lightweight version served by the Android TV application via local assets and disk cache.
- `android/`: Android TV screensaver (`DreamService`) and 4-app Leanback Home Launcher.
