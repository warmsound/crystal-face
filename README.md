# Crystal
A Garmin Connect IQ watch face.

## Description
**If you enjoy this maintained version of Crystal with Tesla integration, you can support my work with a small donation:**
https://bit.ly/sylvainga

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


## Below is what has been added by me (SylvainGa).

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

#### 2.10.2
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
- Better handling of errors and can now refresh an access token through… 

### 2.6.0
- Added a Tesla battery level as an indicator which is activated by choosing the indicator 'Tesla Info'. If the vehicle is awake, it will display the battery charge level as a percentage, followed by a '+' sign if it's being actively charged. It will also cycle to P on/off for the Preconditioning Status, S on/off for Sentry Status and the vehicle's inside temperature. If the car is asleep, a 's' will be displayed after the battery level and it will only cycle between that and P on/off. If an error is received from the car, it will be displayed in pink instead of the battery level. Scan interval is the standard 5 minutes so give it at least 15 minutes at start to get the access to the car and poll its status.

  You'll need to generate at least a refresh token and enter it in the watch face parameter to give access to your vehicle status. You can get a token through online services or phone apps like Tesla Token. If you give it also an access token, the refresh time before capturing data will be decreased by 5 minutes. Make sure your vehicle is awake for at least 15 minutes when you first launch the watch with the token set so it can connect to it. It will NOT wake the vehicle to retrieve any of the info and it does NOT prevent the vehicle from falling asleep.

### 2.5.x
- Added PulseOx as a data field

See https://apps.garmin.com/en-US/apps/9fd04d09-8c80-4c81-9257-17cfa0f0081b for previous changes made by Pixel Pathos
