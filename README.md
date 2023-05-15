# Crystal-Tesla
A Garmin Connect IQ watch face based on PixelPathos Crystal.

## Description
**If you enjoy this maintained version of Crystal with Tesla integration, you can support my work with a small donation:**
https://bit.ly/sylvainga

**FAQs, including how to change watch face settings:**
https://github.com/warmsound/crystal-face/wiki/FAQ

A crystal clear watch face, with LCD-like goal meter segments, written while snow crystals were falling during an unusually cold spell of weather here in England.

Features (depending on watch support):
- Big time digits right in the middle, with hours in bold. Leading zero and seconds can be hidden. Hours and minutes colours can be set independently.
- Up to 3 customisable data fields: HR (historical/live), battery, notifications, calories, distance, alarms, altitude, thermometer, sunrise/sunset, weather (OpenWeatherMap). THE FOLLOWING ADDED by SylvainGa: Garmin Weather, Recovery Time Left, Body Battery, Solar Intensity, Floors climbed and Pulse Ox.
- Up to 3 customisable indicators: Bluetooth, alarms, notifications, Bluetooth/notifications, battery, THE FOLLOWING ADDED by SylvainGa: Do Not Disturb and Tesla batterie level/status.
- 2 customisable meters: steps, floors climbed, active minutes (weekly), battery, calories (custom goal), THE FOLLOWING ADDED by SylvainGa: Body Battery. The meters have auto-scaling segments and current/target value display.
- Move bar.
- 12 colour themes, THE FOLLOWING ADDED by SylvainGa: Customizable themes.
- Complications and touch points added by SylvainGa

The techie bit: to save your watch battery, the goal meters and move bar are drawn from a palette-restricted back buffer, for improved drawing performance, with minimal memory penalty.

This is my first modification of a Connect IQ watch face (please be kind!), so I look forward to your feedback, improving the watch face, and bringing it to more devices.

Reviews:
- Video review in Spanish, by Sergio: https://www.youtube.com/watch?v=TZFhnm_y1MM.

## Below is what has been added by me (SylvainGa).

### 2.18.1
- Gave the weather station name its own line so it doesn't hide the Goals current/max fields. Local City Time will still hide these though. This is how it always was.
- Added an option in Settings (Show weather station name) to show or not the weather station name, defaults to True.
- Watches that although are at CIQ V3.2.0 and above but are still lacking Garmin Weather will display "N/A" for temperature/humidity/sunrise/sunset.
- Trying to free some more room so watches with 98KB of watch face memory doesn't crash with Out of Memory errors.
- Gave the Forerunner 55 access to the weather and humidity since it supports Garmin Weather

### 2.18.0
- Removed Watch model that are not at least at CIQ 3.3.0. This is required for the new Sunrise/Sunset and Weather library by Garmin. From the stats Garmin shows me about the watch face, none of them had downloaded the watch face anyway.
- Removed the OpenWeatherMap and rely solely on Garmin Weather. The OWN and GPS was giving too much problem.
- Added Recovery Time as Complications and Touch points.
- Added Weather and Sunrise data fields as touch point (but not read from Complications)
- The area on the screen allocated for "Local time in City" will display the current weather station name if no city was entered.
- The "Local time in City" has been redone, much simplier, doesn't require Background process anymore but will need some work on your side. The field in the setting is now a Comma Separated Value (CSV) with the first value being the city name, second the latitude of the city and third its longitude. The last two in decimal notation (with a period, not comma). You will have to enter these, which are easy to find in Google Map anyway. No type checking done, beside making sure the latitude and longitude are numbers. If invalid, '???' will be shown for the time.
- Redid the Tesla code and added the reading of the Tesla-Link Complications to get Tesla data instead of querying Tesla's servers internally. No more Token handling if using Complications and Tesla-Link. Because of the size of the data returned when the vehicle is awake, a watch with just 32KB of background space will not be able to show that data and will show error -403 instead (network response out of memory). If it's your case and your watch support Complication, check the Tesla-Link checkbox in the Settings and install the Tesla-Link widget/app. That one has just enough room to download the data and will send it to Crystal-Tesla if asked to send Complication to it.
- Added a Setting to select which Tesla vehicle to show. Defaults to 1. If you have more than one vehicle, use this field to select which vehicle to show. If Tesla data is read from Tesla-Link Complication, it's that one that will dictate which vehicle will appear on the watch face. The Settings here will be ignored, just like the tokens. Give it up to 5 minutes to update its data.

### 2.17.4
- One more attempt at fixing the crash because of the Settings change since 2.17.1

### 2.17.3
- Main change is the hardening of the Properties reading to fix a crash (crash caused by the new Complication checkbox in Settings on some watches)
- Replaced the T letter before the Tesla's battery charge in AlwaysOnDisplays to the Tesla Symbol

### 2.17.2
- Made Complications an optional item, disabled by default since some watches are not reading them properly. Settable through Settings
- Adjusted the touch points around the Fields, Indicators and Goals value.
- Increased the size of the touchpoints as the number of Fields on screen decreases (ie, smallest touchpoint boxes sizes are when three Fields are displayed side by side and the largest touchpoint box is when only one field is dislayed). Doesn't apply to Indicators, just Fields.
- Fixed a few crashes reported through the Error Reporting Application (ERA) including a crash when Theme color override was invalid. If the color stays to what the selected Theme color is, it's because your override is invalid

### 2.17.1
- Fixed a crash when Complications were received while leaving Always On Display mode
- Added Steps and Floor climbs as Complication for Goals.
- Readded the Tesla Battery display to the Always On Display mode

### 2.17.0
- Tesla-Info now support launching the main Tesla-Link App from the watch face.
- Heart rate, PulseOx, BodyBattery and Stress Level are now read through complications if available
- Complication read fields will launch their widget when long pressed. Applies to Fields, Indicators (for Tesla-Info only for now) and Goals.
- Fixed a few crashes reported through the Error Reporting Application (ERA)

### 2.16.5b
- Fixed a crash reported through the Error Reporting Application (ERA)

### 2.16.5a
- Fixed two crashes reported through the Error Reporting Application (ERA)

### 2.16.5
- Fixed a crash when entering a City in the "Add a local time in City"

### 2.16.4
- Recompiled with ConnectIQ4.2.4 since that wasn't the issue with the save settings. It was because watches with ICQ 4.2.0+ didn't support the getProperties/setProperties functions that were used throughout the app. I replaced them all with their corresponding Storage or Properties (for settings) getValue/setValue and was finally able to save the settings on my new Venu2. I was unable to reproduce on my old Venu since it was released pre 4.2.0.
- Added the MARQ® (Gen 2) Athlete / Adventurer / Captain / Golfer / Aviator watches

### 2.16.3
- Recompiled with ConnectIQ4.1.7 which will hopefully fixed the fail to save settings for everyone with the issue and not create more issues.
- Fixed the 416x416 watch font missing a '+'

### 2.16.2
Hopefully fixed the fail to save settings for everyone with the issue.

### 2.16.1
Double entry in the english string file was (not) causing Connect to fail saving settings on devices but not in simulator.

### 2.16.0
- Added a optional colon between hours and minutes
- Bug fix in the default latitude/longitude when the last activity has no GPS coordinates.
- Notice: Access to stress level is not as stable as the Garmin has access to it. To help here, if a value isn't returned, the last good one is used and the icon is greyed out to indicate the data is stale.

### 2.15.1
- Reverted to Connect IQ 4.1.7 since there are too many problem with sensors with this 4.2.x version so far. Hopefully this doesn't break the watchface on newest Forerunner 265, 265S and 965.
- Moved the line between time and date in Always On Display so it doesn't strike through the time.

### 2.15.0
- Added Stress Level as a goal meter and datafield
- Consolidated some of the watches that were missing goal meters or datafields. If you select one and get a gray icon, it means it's not available for your watch model. If there is a goal meter or datafield that your watch support but can't see it, let me know.
- Compiled with Connect IQ 4.2.2 which I hope fixes the missing Body Battery sensor some are seeing

### 2.14.2
- Added Longitude and Latitude as editable fields in the parameters to allow for a DEFAULT location for sunrise/sunset and OpenWeatherMap weather . Any activity found with GPS data will override this location. This should fix many "gps?" error, which simply means no activity with GPS have been found to locate your position, yet. Keep in mind it can take up to 5 minutes before data is retrieved from OWM or Garmin Weather.
- The weather icon will be grayed out if the request to get the weather fails for some reason (like Bluetooth off, no Internet access or bad OWM API key). If this happens, the temperature or humidity value displayed will be stale. If you create a file called CRYSTALFACE.TXT in the /GARMIN/APPS/LOGS on your watch (connect to your computer first), it will log inside that file the error code of why it failed (unless it's because BLE is Off). This could be helpful at determining the reason of the failure.
- Added BodyBattery as a datafield to the Forerunner 55
- Increased the time and date fonts for the 454x454 devices
- Fixed the missing "/" in the floor climbs datafield for 416x416 and 454x454 devices

### 2.14.1
- Compiled with Connect IQ 4.2.1 which added the Forerunner 265, 265s and 965 (first 454x454 watch)
- Added BodyBattery to the Forerunner 55

### 2.14.0
- "Hide seconds" has been changed from a checkbox to a list with three entries:
  - Show seconds
  - Hide seconds when inactive 
  - Always hide seconds
  
  Show and Hide seconds behaves like the old toggle but "Hide seconds when inactive" will not display seconds when the watchface is in low power mode (ie, inactive). "Memory-In-Pixel" watch consumes energy when a pixel is changed. Preventing the seconds to update every secondes can help reduce the energy drawn by the watchface. Has no Effect on AMOLED watches.

### 2.13.0
- Added Body Battery as a Goal Meter

### 2.12.1
- Removed troubleshooting code left by mistake

### 2.12.0
- Fixed sunrize/sunset time error when timezone has a 30 minutes offset
- Added support for Teslas in China. These needs different Tesla servers domain name than the rest of the world. These can be changed through the phone app.
  <br>The default API and AUTH servers are owner-api.teslamotors.com and auth.tesla.com respectively.
  <br>For China, they are owner-api.vn.cloud.tesla.cn and auth.tesla.cn
- Added customizable screen colors. Can be set by entering something other than 0 (or blank) in 'RGB Them override' field
  <br>The format is RRGGBB (Red Green Blue) in hexadecimal (0-F). You can use this web site to figure out the colors you want. Don't enter the leading '#' though: https://www.rapidtables.com/convert/color/rgb-to-hex.html
    <br>Checking *Light theme override* will give the watchface light background. Unchecking the field gives it a dark background (usefull for OLED display).
    <br>These are the standard Garmin color and their hexadecimal equivalent
    - WHITE	FFFFFF
    - LIGHT GRAY	AAAAAA
    - DARK GRAY	555555
    - BLACK	000000
    - RED	 FF0000
    - DARK RED	 AA0000
    - ORANGE	 FF5500
    - YELLOW	 FFAA00
    - GREEN	 00FF00
    - DARK GREEN	 00AA00
    - BLUE	 00AAFF
    - DARK BLUE	 0000FF
    - PURPLE	 AA00FF
    - PINK	 FF00FF

### 2.11.0
- Added Recovery Time Left as a data field

### 2.10.4
- Fixed AlwaysOnDisplay of Venu SQ 2 and Venu SQ 2 Music

### 2.10.3a
- Fixed Dutch translations. Thanks ChristopheMB

### 2.10.3
- Added the Enduro, Venu SQ 2 and Venu SQ 2 Music

### 2.10.2
- Fixed missing 'Û' in 280x280 font

### 2.10.1
- Added Forerunner 255, 255 Music, 255s, 255s Music

### 2.10.0
- Added Body Battery as a data field. Bug fix for Solar Intensity on 390x390 watches

### 2.9.0
- Added the Solar Intensity as a data field. Relevant only to watches that support solar.

### 2.8.2
- Added the Forerunner 955 / Solar

### 2.8.1
- Removed the following watch as they have not enough memory for watch faces to work reliably with the newer versions of this watch face: D2 Bravo, D2 Bravo Titanium, fēnix 3 / tactix Bravo / quatix 3, fēnix 3 HR, Forerunner 230, Forerunner 235, Forerunner 630, Forerunner 735xt, Forerunner 920xt, vívoactive, vívoactive HR and vivolife.

### 2.8.0
- Added the Tesla battery level to the Always On Display. To stay within the 10% of pixel on, I removed the day of the week from the date to make room for the battery level.

### 2.7.5
- Added 'Do Not Disturb' as an indicator

### 2.7.4.2
- Added Descent Mk1, Mk2 and Mk2s as supported devices

### 2.7.4.1
- Fixed the '/' in the font files missing it.

### 2.7.4
- Added Floors climbed as a data field. Some fonts do not have the '/' symbol so for now on these watches (the 416x416 resolution watches), it will be displayed as a rectangle (default for non recognized character).

### 2.7.3
- The Altitude will remain on screen, even if the watch face loses focus. Also fix a very rare occurrence of a crash when displaying seconds and the area where the seconds are to be displayed is overwritten by the move bar.

### 2.7.2
- Trying to fix the Altitude code so its value doesn't disappear when GPS is lost. Removal of Garmin Swim 2 from supported devices.

### 2.7.1
- Fixes a crash when Garmin Weather was not available

### 2.7.0
- Addition of the Garmin Weather API. If you're having issue with the OpenWeatherMap API Key and your watch supports Garmin API 3.2 or higher (see https://developer.garmin.com/connect-iq/compatible-devices/), by clearing the field "OpenWeatherMap API Key Override" in the Settings, it will use the Garmin Weather API instead. Weather Options is available for watches with a Garmin API 2.4 and higher.

### 2.6.3
- Fix sunrise showing today's time instead of tomorrow's when sunset time has been reached and it's before midnight

### 2.6.2
- Disables background services for watch that doesn't support it. Features that won't work without background services are Weather, sunrise/sunset and Tesla Info.

### 2.6.1
- Better handling of errors and can now refresh an access token through the help of the Refresh token (hopefully)

### 2.6.0
- Added a Tesla battery level as an indicator which is activated by choosing the indicator 'Tesla Info'. If the vehicle is awake, it will display the battery charge level as a percentage, followed by a '+' sign if it's being actively charged. It will also cycle to P on/off for the Preconditioning Status, S on/off for Sentry Status and the vehicle's inside temperature. If the car is asleep, a 's' will be displayed after the battery level and it will only cycle between that and P on/off. If an error is received from the car, it will be displayed in pink instead of the battery level. Scan interval is the standard 5 minutes so give it at least 15 minutes at start to get the access to the car and poll its status.

  You'll need to generate at least a refresh token and enter it in the watch face parameter to give access to your vehicle status. You can get a token through online services or phone apps like Tesla Token. If you give it also an access token, the refresh time before capturing data will be decreased by 5 minutes. Make sure your vehicle is awake for at least 15 minutes when you first launch the watch with the token set so it can connect to it. It will NOT wake the vehicle to retrieve any of the info and it does NOT prevent the vehicle from falling asleep.

### 2.5.x
- Added PulseOx as a data field

See https://apps.garmin.com/en-US/apps/9fd04d09-8c80-4c81-9257-17cfa0f0081b for previous changes made by Pixel Pathos
