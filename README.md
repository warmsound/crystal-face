# Crystal
A Garmin Connect IQ watch face.

## Description
**If you enjoy using Crystal, you can support my work with a small donation:**
https://goo.gl/vFCE4T

**FAQs, including how to change watch face settings:**
https://github.com/warmsound/crystal-face/wiki/FAQ

A crystal clear watch face, with LCD-like goal meter segments, written while snow crystals were falling during an unusually cold spell of weather here in England.

Features (depending on watch support):
- Big time digits right in the middle, with hours in bold. Leading zero and seconds can be hidden. Hours and minutes colours can be set independently.
- Up to 3 customisable data fields: HR (historical/live), battery, notifications, calories, distance, alarms, altitude, thermometer, sunrise/sunset, weather (OpenWeatherMap).
- Up to 3 customisable indicators: Bluetooth, alarms, notifications, Bluetooth/notifications, battery.
- 2 customisable meters: steps, floors climbed, active minutes (weekly), battery, calories (custom goal). The meters have auto-scaling segments and current/target value display.
- Move bar.
- 12 colour themes.

The techie bit: to save your watch battery, the goal meters and move bar are drawn from a palette-restricted back buffer, for improved drawing performance, with minimal memory penalty.

This is my first ever Connect IQ watch face (please be kind!), so I look forward to your feedback, improving the watch face, and bringing it to more devices.

Reviews:
- Video review in Spanish, by Sergio: https://www.youtube.com/watch?v=TZFhnm_y1MM.

## What's New

### 2.3.0
- Increase time font size and revise layouts for all watches.
- Single line time for vívoactive® HR.

### 2.2.6
- Add "Humidity" data field (uses OpenWeatherMap). Many thanks to jrmcsoftware for implementing this.
- Technical update to CIQ 3.0.8 SDK.

### 2.2.5
- "Pressure" data field should use historical data, to respect manual pressure calibration on fēnix® 5 watches (thanks to Allalin72 for help with this).

### 2.2.4
- Fix issue with move bar not clearing in "Show Filled Segments" mode (thanks to BrettL for reproduction steps).
- Add "Corn Yellow (Dark)" and "Dayglo Orange (Light)" themes.
- Add "Pressure" data field.
- Technical update to CIQ 3.0.7 SDK.

### 2.2.3
- Remove need to enter OpenWeatherMap key.
- Technical update to CIQ 3.0.6 SDK.

### 2.2.2
- Fix issue with stuck "key!" if weather key is used before it has been activated.

### 2.2.1
- Fix intermittent crash after receiving weather data.

### 2.2.0
- Add "Weather" data field: CIQ 2.x devices only, requires free OpenWeatherMap API key (https://openweathermap.org/).

### 2.1.0
- Add "Sunrise/Sunset" data field.
- Read altitude from more up-to-date source, and enable for all watches.
- Add Croatian date translation (thanks to Kristijan).
- Russian translation updates, and string fixes (thanks to xgsa).
- German translation for settings screen (thanks to dragonito).
- Technical update to CIQ 3.0.4 SDK.

### 2.0.1
- Fix crash when changing settings.

### 2.0.0
- Russian translation for watch face and settings screen (thanks to xgsa).
- Display of additional time zone: specify city in settings (CIQ 2.x devices only, in beta). See FAQ.
- Re-enable support for Approach® S60.
- Technical update to CIQ 3.0.3 SDK.

### 1.8.1
- Added "Heart Rate (Live 5s)" data field.
- Read HR from more up-to-date source.
- Improved clarity of battery indicator.
- "Hide Hours Leading Zero" now setting applies to both 12- and 24-hour modes.
- Technical update to CIQ 2.4.9 SDK, to add support for D2™ Delta, D2™ Delta PX, D2™ Delta S.

### 1.8.0
- Added setting to control number of data fields (0-3).
- Added setting to control number of indicators (0-3): Bluetooth, alarms, notifications, bluetooth/notifications.
- Improved memory efficiency.
- Layout adjustments.
- Technical update to CIQ 2.4.8 SDK.

### 1.7.4
- Polish translation for settings screen (thanks to Flugcojt).
- Swedish translation for settings screen (thanks to hasselrot).

### 1.7.3
- Update to CIQ 2.4.7 SDK, to add support for fēnix® 5 Plus, fēnix® 5S Plus, fēnix® 5X Plus, vívoactive® 3 Music.
- Fixed issue with "ft" altitude units displaying incorrectly (thanks to Matt Reiser).

### 1.7.2
- Altitude units now obey statue/metric setting (thanks to Rick Gorham).
- Added "Battery (Hide Percentage)" data field (thanks to Paolo Avezzano).
- Corrected number of move bar segments to 5 (thanks to Viorel).
- Technical update to CIQ 2.4.6 SDK.

### 1.7.1
- Re-enabled Forerunner® 920XT, following non-anti-aliased custom font workaround provided by Coleman at Garmin.
- Corrected French translation (thanks to Ju Neusch).

### 1.7.0
- Added temperature data field option.
- Added vivid yellow dark theme.
- Added meter style setting.
- Added move bar style setting.
- Corrected German translations (thanks to Christoph Heymann for help with this).
- Temporarily removed support for Approach® S60 and Forerunner® 920XT, pending fixes from Garmin - many thanks for your patience.
- Technical update to CIQ 2.4.5 SDK.

### 1.6.1
- Added barometric altitude for supported CIQ 2.x devices.
- Show midnight as "12" instead of "00" in 12-hour mode.
- Fixed incorrect default settings for vívoactive®.

### 1.6.0
- Added blue, red and green light themes.
- Allow colour of hours and minutes to be overridden independently.
- Allow hiding of hours leading zero in 12 hr mode.
- Prevent overlapping goal numbers on semi-round watches (thanks to G_stijn for reporting this).

### 1.5.3
- Fix crash if floors or active minutes goal is set to 0: show disabled meter instead.

### 1.5.2
- Technical update to CIQ 2.4.4 SDK.

### 1.5.1
- Added alarms data field option.
- Rollout to CIQ 1.x devices, part 2: Forerunner® 230, Forerunner® 235, Forerunner® 630, Forerunner® 920XT, vívoactive®.

### 1.5.0
- Rollout to CIQ 1.x devices, part 1: D2™ Bravo, D2™ Bravo Titanium, fēnix® 3, fēnix® 3 HR.

### 1.4.3
- Meters can now show a custom calories goal, specified in settings.
- Fixed issue with wrong strings or crash when changing settings via Garmin Express in non-English locales (thanks to Ezio Pillan for reporting this bug).
- Added app version to settings page.

### 1.4.2
- Allow hiding of seconds.

### 1.4.1
- Reduce battery drain, part 2: optimise per-minute updates (cache drawable references).
- Allow meters to display battery level.

### 1.4.0
- Reduce battery drain, part 1: reduce per-second update time from ~13ms to ~5ms (measured on Approach® S60, simulator).
- Added Red (Dark) and Mono (Dark) themes.
- Added support for vívoactive® HR.

### 1.3.0
- Added support for fēnix® 5S, fēnix® Chronos, Forerunner® 735XT.
- Added Dayglo Orange theme.

### 1.2.1 
- Fixed issue with distance value being too low (thanks to catana.remulus for reporting and assisting with this bug). 

### 1.2.0
- Added support for Approach® S60, D2™ Charlie, Descent™ Mk1, Forerunner® 645, Forerunner® 645 Music, Forerunner® 935, fēnix® 5, fēnix® 5X.
- Added Cornflower Blue and Lemon Cream themes for better visibility.

**N.B. Due to a vívoactive® 3 firmware bug, this watch face will be stuck on the language that was active at the time of the 3.30-3.40 firmware upgrade. Hopefully Garmin will fix this in a future firmware.**

### 1.1.0
- Internationalisation: added support for Chinese (Simplified/Traditional), Czech, Danish, Dutch, Finnish, French, German, Hungarian, Italian, Norwegian, Polish, Portugese, Slovak, Slovenian, Spanish, Swedish.
- Force language to English for unsupported locales, to prevent garbled characters.
- Fixed issue with battery meter not showing low/critical warning colours soon enough.

### 1.0.1
- Fixed issue with showing noon as AM, rather than PM (with thanks to JACalvo for reporting this bug).
- Fixed issue with move bar not updating correctly.

### 1.0.0
- Initial public release for vívoactive® 3 only.

## Credits
Icons:
- "[Distance](https://thenounproject.com/term/distance/1514833/)" icon by Becris from [the Noun Project](https://thenounproject.com).
- "[Fire](https://thenounproject.com/term/fire/24187/)" icon by Jenny Amer from [the Noun Project](https://thenounproject.com).
- "[Steps](https://thenounproject.com/term/steps/87667/)" icon by Eugen Belyakoff from [the Noun Project](https://thenounproject.com).
- "[Upstairs](https://thenounproject.com/term/upstairs/304907/)" icon by Arthur Shlain from [the Noun Project](https://thenounproject.com).
- "[Stopwatch](https://thenounproject.com/term/stopwatch/319102/)" icon by Rohith M S from [the Noun Project](https://thenounproject.com).
- "[Mountains](https://thenounproject.com/term/mountains/1468194/)" icon by Deemak Daksina from [the Noun Project](https://thenounproject.com).
- "[Humidity](https://thenounproject.com/term/humidity/1554816/)" icon by Akriti Bhusal from [the Noun Project](https://thenounproject.com).
