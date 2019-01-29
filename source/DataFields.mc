using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Activity as Activity;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;

using Toybox.Time;
using Toybox.Time.Gregorian;

enum /* FIELD_TYPES */ {
	// Pseudo-fields.	
	FIELD_TYPE_SUNRISE = -1,	
	//FIELD_TYPE_SUNSET = -2,

	// Real fields (used by properties).
	FIELD_TYPE_HEART_RATE = 0,
	FIELD_TYPE_BATTERY,
	FIELD_TYPE_NOTIFICATIONS,
	FIELD_TYPE_CALORIES,
	FIELD_TYPE_DISTANCE,
	FIELD_TYPE_ALARMS,
	FIELD_TYPE_ALTITUDE,
	FIELD_TYPE_TEMPERATURE,
	FIELD_TYPE_BATTERY_HIDE_PERCENT,
	FIELD_TYPE_HR_LIVE_5S,
	FIELD_TYPE_SUNRISE_SUNSET,
	FIELD_TYPE_WEATHER,
	FIELD_TYPE_PRESSURE,
	FIELD_TYPE_HUMIDITY
}

class DataFields extends Ui.Drawable {

	private var mLeft;
	private var mRight;
	private var mTop;
	private var mBottom;

	private var mWeatherIconsFont;
	private var mWeatherIconsSubset = null; // null, "d" for day subset, "n" for night subset.

	private var mFieldCount;
	private var mFieldTypes = new [3]; // Cache values to optimise partial update path.
	private var mHasLiveHR = false; // Is a live HR field currently being shown?
	private var mWasHRAvailable = false; // HR availability at last full draw (in high power mode).
	private var mMaxFieldLength; // Maximum number of characters per field.

	// private const CM_PER_KM = 100000;
	// private const MI_PER_KM = 0.621371;
	// private const FT_PER_M = 3.28084;

	function initialize(params) {
		Drawable.initialize(params);

		mLeft = params[:left];
		mRight = params[:right];
		mTop = params[:top];
		mBottom = params[:bottom];

		// Initialise mFieldCount and mMaxFieldLength.
		onSettingsChanged();
	}

	// Cache FieldCount setting, and determine appropriate maximum field length.
	function onSettingsChanged() {
		mFieldCount = App.getApp().getProperty("FieldCount");

		/* switch (mFieldCount) {
			case 3:
				mMaxFieldLength = 4;
				break;
			case 2:
				mMaxFieldLength = 6;
				break;
			case 1:
				mMaxFieldLength = 8;
				break;
		} */
		mMaxFieldLength = [8, 6, 4][mFieldCount - 1];

		mFieldTypes[0] = App.getApp().getProperty("Field1Type");
		mFieldTypes[1] = App.getApp().getProperty("Field2Type");
		mFieldTypes[2] = App.getApp().getProperty("Field3Type");

		mHasLiveHR = hasField(FIELD_TYPE_HR_LIVE_5S);

		if (!hasField(FIELD_TYPE_WEATHER)) {
			mWeatherIconsFont = null;
			mWeatherIconsSubset = null;
		}
	}

	function hasField(fieldType) {
		return ((mFieldTypes[0] == fieldType) ||
			(mFieldTypes[1] == fieldType) ||
			(mFieldTypes[2] == fieldType));
	}

	function draw(dc) {
		update(dc, /* isPartialUpdate */ false);
	}

	function update(dc, isPartialUpdate) {
		if (isPartialUpdate && !mHasLiveHR) {
			return;
		}

		switch (mFieldCount) {
			case 3:
				drawDataField(dc, isPartialUpdate, mFieldTypes[0], mLeft);
				drawDataField(dc, isPartialUpdate, mFieldTypes[1], (mRight + mLeft) / 2);
				drawDataField(dc, isPartialUpdate, mFieldTypes[2], mRight);
				break;
			case 2:
				drawDataField(dc, isPartialUpdate, mFieldTypes[0], mLeft + ((mRight - mLeft) * 0.15));
				drawDataField(dc, isPartialUpdate, mFieldTypes[1], mLeft + ((mRight - mLeft) * 0.85));
				break;
			case 1:
				drawDataField(dc, isPartialUpdate, mFieldTypes[0], (mRight + mLeft) / 2);
				break;
			case 0:
				break;
		}
	}

	// Both regular and small icon fonts use same spot size for easier optimisation.
	//private const LIVE_HR_SPOT_RADIUS = 3;

	private function drawDataField(dc, isPartialUpdate, fieldType, x) {		

		// Assume we're only drawing live HR spot every 5 seconds; skip all other partial updates.
		var isLiveHeartRate = (fieldType == FIELD_TYPE_HR_LIVE_5S);
		var seconds = Sys.getClockTime().sec;
		if (isPartialUpdate && (!isLiveHeartRate || (seconds % 5))) {
			return;
		}

		// Decide whether spot should be shown or not, based on current seconds.
		var showLiveHRSpot = false;
		var isHeartRate = ((fieldType == FIELD_TYPE_HEART_RATE) || isLiveHeartRate);
		if (isHeartRate) {

			// High power mode: 0 on, 1 off, 2 on, etc.
			if (!App.getApp().getView().isSleeping()) {
				showLiveHRSpot = ((seconds % 2) == 0);

			// Low power mode:
			} else {

				// Live HR: 0-4 on, 5-9 off, 10-14 on, etc.
				if (isLiveHeartRate) {
					showLiveHRSpot = (((seconds / 5) % 2) == 0);

				// Normal HR: turn off spot when entering sleep.
				} else {
					showLiveHRSpot = false;
				}
			}
		}

		// 1. Value: draw first, as top of text overlaps icon.
		var result = getValueForFieldType(fieldType);
		var value = result["value"];

		// Optimisation: if live HR remains unavailable, skip the rest of this partial update.
		var isHRAvailable = isHeartRate && (value.length() != 0);
		if (isPartialUpdate && !isHRAvailable && !mWasHRAvailable) {
			return;
		}

		// #34 Clip live HR value.
		// Optimisation: hard-code clip rect dimensions. Possible, as all watches use same label font.
		dc.setColor(gMonoLightColour, gBackgroundColour);

		if (isPartialUpdate) {
			dc.setClip(
				x - 11,
				mBottom - 4,
				25,
				12);
			
			dc.clear();
		}
		
		dc.drawText(
			x,
			mBottom,
			gNormalFont,
			value,
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// 2. Icon.

		// Grey out icon if no value was retrieved.
		// #37 Do not grey out battery icon (getValueForFieldType() returns empty string).
		var colour;
		if (value.length() == 0) {
			colour = gMeterBackgroundColour;
		} else {
			colour = gThemeColour;
		}

		// Battery.
		if ((fieldType == FIELD_TYPE_BATTERY) || (fieldType == FIELD_TYPE_BATTERY_HIDE_PERCENT)) {

			if (Sys.getDeviceSettings().screenShape == Sys.SCREEN_SHAPE_ROUND) {
				drawBatteryMeter(dc, x, mTop, 28, 14);
			} else {
				drawBatteryMeter(dc, x, mTop, 24, 12);
			}

		// #34 Live HR in low power mode.
		} else if (isLiveHeartRate && isPartialUpdate) {

			// If HR availability changes while in low power mode, then we unfortunately have to draw the full heart.
			// HR availability was recorded during the last high power draw cycle.
			if (isHRAvailable != mWasHRAvailable) {
				mWasHRAvailable = isHRAvailable;

				// Clip full heart, then draw.
				var heartDims = dc.getTextDimensions("3", gIconsFont); // getIconFontCharForField(FIELD_TYPE_HR_LIVE_5S)
				dc.setClip(
					x - (heartDims[0] / 2),
					mTop - (heartDims[1] / 2),
					heartDims[0] + 1,
					heartDims[1] + 1);
				dc.setColor(colour, gBackgroundColour);
				dc.drawText(
					x,
					mTop,
					gIconsFont,
					"3", // getIconFontCharForField(FIELD_TYPE_HR_LIVE_5S)
					Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			// Clip spot.
			dc.setClip(
				x - 3 /* LIVE_HR_SPOT_RADIUS */,
				mTop - 3 /* LIVE_HR_SPOT_RADIUS */,
				7, // (2 * LIVE_HR_SPOT_RADIUS) + 1
				7); // (2 * LIVE_HR_SPOT_RADIUS) + 1

			// Draw spot, if it should be shown.
			// fillCircle() does not anti-aliase, so use font instead.
			var spotChar;
			if (showLiveHRSpot && (Activity.getActivityInfo().currentHeartRate != null)) {
				dc.setColor(gBackgroundColour, Graphics.COLOR_TRANSPARENT);
				spotChar = "="; // getIconFontCharForField(LIVE_HR_SPOT)

			// Otherwise, fill in spot by drawing heart.
			} else {
				dc.setColor(colour, gBackgroundColour);
				spotChar = "3"; // getIconFontCharForField(FIELD_TYPE_HR_LIVE_5S)
			}
			dc.drawText(
				x,
				mTop,
				gIconsFont,
				spotChar,
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

		// Other icons.
		} else {

			// #19 Show sunrise icon instead of default sunset icon, if sunrise is next.
			if ((fieldType == FIELD_TYPE_SUNRISE_SUNSET) && (result["isSunriseNext"] == true)) {
				fieldType = FIELD_TYPE_SUNRISE;
			}

			var font;
			var icon;
			if (fieldType == FIELD_TYPE_WEATHER) {

				// #83 Dynamic loading/unloading of day/night weather icons font, to save memory.
				// If subset has changed since last draw, save new subset, and load appropriate font for it.
				var weatherIconsSubset = result["weatherIcon"].substring(2, 3);
				if (!weatherIconsSubset.equals(mWeatherIconsSubset)) {
					mWeatherIconsSubset = weatherIconsSubset;
					if (mWeatherIconsSubset.equals("d")) {
						mWeatherIconsFont = Ui.loadResource(Rez.Fonts.WeatherIconsFontDay);
					} else {
						mWeatherIconsFont = Ui.loadResource(Rez.Fonts.WeatherIconsFontNight);
					}
				}
				font = mWeatherIconsFont;

				// Map weather icon code --> Unicode --> Char --> String.
				// See https://openweathermap.org/weather-conditions.
				icon = {
					// Day icon     Night icon         Description
					"01d" => 61453, "01n" => 61486, // clear sky
					"02d" => 61452, "02n" => 61569, // few clouds
					"03d" => 61442, "03n" => 61574, // scattered clouds
					"04d" => 61459, "04n" => 61459, // broken clouds: day and night use same icon
					"09d" => 61449, "09n" => 61481, // shower rain
					"10d" => 61448, "10n" => 61480, // rain
					"11d" => 61445, "11n" => 61477, // thunderstorm
					"13d" => 61450, "13n" => 61482, // snow
					"50d" => 61441, "50n" => 61475, // mist
				}[result["weatherIcon"]].toChar().toString();

			} else {
				font = gIconsFont;

				// Map fieldType to icon font char.
				icon = {
					FIELD_TYPE_SUNRISE => ">",
					// FIELD_TYPE_SUNSET => "?",

					FIELD_TYPE_HEART_RATE => "3",
					FIELD_TYPE_HR_LIVE_5S => "3",
					// FIELD_TYPE_BATTERY => "4",
					// FIELD_TYPE_BATTERY_HIDE_PERCENT => "4",
					FIELD_TYPE_NOTIFICATIONS => "5",
					FIELD_TYPE_CALORIES => "6",
					FIELD_TYPE_DISTANCE => "7",
					FIELD_TYPE_ALARMS => ":",
					FIELD_TYPE_ALTITUDE => ";",
					FIELD_TYPE_TEMPERATURE => "<",
					// FIELD_TYPE_WEATHER => "<",
					// LIVE_HR_SPOT => "=",

					FIELD_TYPE_SUNRISE_SUNSET => "?",
					FIELD_TYPE_PRESSURE => "@",
					FIELD_TYPE_HUMIDITY => "A",
				}[fieldType];
			}

			dc.setColor(colour, gBackgroundColour);
			dc.drawText(
				x,
				mTop,
				font,
				icon,
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

			if (isHeartRate) {

				// #34 Save whether HR was available during this high power draw cycle.
				mWasHRAvailable = isHRAvailable;

				// #34 Live HR in high power mode.
				if (showLiveHRSpot && (Activity.getActivityInfo().currentHeartRate != null)) {
					dc.setColor(gBackgroundColour, Graphics.COLOR_TRANSPARENT);
					dc.drawText(
						x,
						mTop,
						gIconsFont,
						"=", // getIconFontCharForField(LIVE_HR_SPOT)
						Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
					);
				}
			}
		}
	}

	// Return empty result["value"] string if value cannot be retrieved (e.g. unavailable, or unsupported).
	// result["isSunriseNext"] indicates that sunrise icon should be shown for FIELD_TYPE_SUNRISE_SUNSET, rather than default
	// sunset icon.
	private function getValueForFieldType(type) {
		var result = {};
		var value = "";

		var settings = Sys.getDeviceSettings();

		var activityInfo;
		var sample;	
		var altitude;
		var pressure = null; // May never be initialised if no support for pressure (CIQ 1.x devices).
		var temperature;
		var humidity;
		var sunTimes;
		var unit;

		switch (type) {
			case FIELD_TYPE_HEART_RATE:
			case FIELD_TYPE_HR_LIVE_5S:
				// #34 Try to retrieve live HR from Activity::Info, before falling back to historical HR from ActivityMonitor.
				activityInfo = Activity.getActivityInfo();
				sample = activityInfo.currentHeartRate;
				if (sample != null) {
					value = sample.format(INTEGER_FORMAT);
				} else if (ActivityMonitor has :getHeartRateHistory) {
					sample = ActivityMonitor.getHeartRateHistory(1, /* newestFirst */ true)
						.next();
					if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
						value = sample.heartRate.format(INTEGER_FORMAT);
					}
				}
				break;

			case FIELD_TYPE_BATTERY:
				// #8: battery returned as float. Use floor() to match native. Must match drawBatteryMeter().
				value = Math.floor(Sys.getSystemStats().battery);
				value = value.format(INTEGER_FORMAT) + "%";
				break;

			// #37 Return empty string. updateDataField() has special case so that battery icon is not greyed out.
			// case FIELD_TYPE_BATTERY_HIDE_PERCENT:
				// break;

			case FIELD_TYPE_NOTIFICATIONS:
				if (settings.notificationCount > 0) {
					value = settings.notificationCount.format(INTEGER_FORMAT);
				}
				break;

			case FIELD_TYPE_CALORIES:
				activityInfo = ActivityMonitor.getInfo();
				value = activityInfo.calories.format(INTEGER_FORMAT);
				break;

			case FIELD_TYPE_DISTANCE:
				activityInfo = ActivityMonitor.getInfo();
				value = activityInfo.distance.toFloat() / /* CM_PER_KM */ 100000; // #11: Ensure floating point division!

				if (settings.distanceUnits == System.UNIT_METRIC) {
					unit = "km";					
				} else {
					value *= /* MI_PER_KM */ 0.621371;
					unit = "mi";
				}

				value = value.format("%.1f");

				// Show unit only if value plus unit fits within maximum field length.
				if ((value.length() + unit.length()) <= mMaxFieldLength) {
					value += unit;
				}
				
				break;

			case FIELD_TYPE_ALARMS:
				if (settings.alarmCount > 0) {
					value = settings.alarmCount.format(INTEGER_FORMAT);
				}
				break;

			case FIELD_TYPE_ALTITUDE:
				// #67 Try to retrieve altitude from current activity, before falling back on elevation history.
				// Note that Activity::Info.altitude is supported by CIQ 1.x, but elevation history only on select CIQ 2.x
				// devices.
				activityInfo = Activity.getActivityInfo();
				altitude = activityInfo.altitude;
				if ((altitude == null) && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory)) {
					sample = SensorHistory.getElevationHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST })
						.next();
					if ((sample != null) && (sample.data != null)) {
						altitude = sample.data;
					}
				}
				if (altitude != null) {

					// Metres (no conversion necessary).
					if (settings.elevationUnits == System.UNIT_METRIC) {
						unit = "m";

					// Feet.
					} else {
						altitude *= /* FT_PER_M */ 3.28084;
						unit = "ft";
					}

					value = altitude.format(INTEGER_FORMAT);

					// Show unit only if value plus unit fits within maximum field length.
					if ((value.length() + unit.length()) <= mMaxFieldLength) {
						value += unit;
					}
				}
				break;

			case FIELD_TYPE_TEMPERATURE:
				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getTemperatureHistory)) {
					sample = SensorHistory.getTemperatureHistory(null).next();
					if ((sample != null) && (sample.data != null)) {
						temperature = sample.data;

						if (settings.temperatureUnits == System.UNIT_STATUTE) {
							temperature = (temperature * (9.0 / 5)) + 32; // Convert to Farenheit: ensure floating point division.
						}

						value = temperature.format(INTEGER_FORMAT) + "°";
					}
				}
				break;

			case FIELD_TYPE_SUNRISE_SUNSET:
			
				if (gLocationLat != -360.0) { // -360.0 is a special value, meaning "unitialised". Can't have null float property.
					var nextSunEvent = 0;
					var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

					// Convert to same format as sunTimes, for easier comparison. Add a minute, so that e.g. if sun rises at
					// 07:38:17, then 07:38 is already consided daytime (seconds not shown to user).
					now = now.hour + ((now.min + 1) / 60.0);
					//Sys.println(now);

					// Get today's sunrise/sunset times in current time zone.
					sunTimes = App.getApp().getView().getSunTimes(gLocationLat, gLocationLng, null, /* tomorrow */ false);
					//Sys.println(sunTimes);

					// If sunrise/sunset happens today.
					var sunriseSunsetToday = ((sunTimes[0] != null) && (sunTimes[1] != null));
					if (sunriseSunsetToday) {

						// Before sunrise today: today's sunrise is next.
						if (now < sunTimes[0]) {
							nextSunEvent = sunTimes[0];
							result["isSunriseNext"] = true;

						// After sunrise today, before sunset today: today's sunset is next.
						} else if (now < sunTimes[1]) {
							nextSunEvent = sunTimes[1];

						// After sunset today: tomorrow's sunrise (if any) is next.
						} else {
							sunTimes = App.getApp().getView().getSunTimes(gLocationLat, gLocationLng, null, /* tomorrow */ true);
							nextSunEvent = sunTimes[0];
							result["isSunriseNext"] = true;
						}
					}

					// Sun never rises/sets today.
					if (!sunriseSunsetToday) {
						value = "---";

						// Sun never rises: sunrise is next, but more than a day from now.
						if (sunTimes[0] == null) {
							result["isSunriseNext"] = true;
						}

					// We have a sunrise/sunset time.
					} else {
						var hour = Math.floor(nextSunEvent).toLong() % 24;
						var min = Math.floor((nextSunEvent - Math.floor(nextSunEvent)) * 60); // Math.floor(fractional_part * 60)
						value = App.getApp().getView().getFormattedTime(hour, min);
						value = value[:hour] + ":" + value[:min] + value[:amPm]; 
					}

				// Waiting for location.
				} else {
					value = "gps?";
				}

				break;

			case FIELD_TYPE_WEATHER:

				// Default = sunshine!
				result["weatherIcon"] = "01d";

				if (App has :Storage) {
					var weather = App.Storage.getValue("OpenWeatherMapCurrent");

					// Awaiting location.
					if (gLocationLat == -360.0) { // -360.0 is a special value, meaning "unitialised". Can't have null float property.
						value = "gps?";

					// Stored weather data available.
					} else if ((weather != null) && (weather["temp"] != null)) {
						temperature = weather["temp"]; // Celcius.

						if (settings.temperatureUnits == System.UNIT_STATUTE) {
							temperature = (temperature * (9.0 / 5)) + 32; // Convert to Farenheit: ensure floating point division.
						}

						value = temperature.format(INTEGER_FORMAT) + "°";
						result["weatherIcon"] = weather["icon"];

					// Awaiting response.
					} else if (App.Storage.getValue("PendingWebRequests")["OpenWeatherMapCurrent"]) {
						value = "...";
					}
				}
				break;

			case FIELD_TYPE_HUMIDITY:

				if (App has :Storage) {
					var weather = App.Storage.getValue("OpenWeatherMapCurrent");

					// Awaiting location.
					if (gLocationLat == -360.0) { // -360.0 is a special value, meaning "unitialised". Can't have null float property.
						value = "gps?";

					// Stored weather data available.
					} else if ((weather != null) && (weather["humidity"] != null)) {
						humidity = weather["humidity"];

						value = humidity.format(INTEGER_FORMAT) + "%";

					// Awaiting response.
					} else if (App.Storage.getValue("PendingWebRequests")["OpenWeatherMapCurrent"]) {
						value = "...";
					}
				}
				break;

			case FIELD_TYPE_PRESSURE:

				// Avoid using ActivityInfo.ambientPressure, as this bypasses any manual pressure calibration e.g. on Fenix
				// 5. Pressure is unlikely to change frequently, so there isn't the same concern with getting a "live" value,
				// compared with HR. Use SensorHistory only.
				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getPressureHistory)) {
					sample = SensorHistory.getPressureHistory(null).next();
					if ((sample != null) && (sample.data != null)) {
						pressure = sample.data;
					}
				}

				if (pressure != null) {
					unit = "mb";
					pressure = pressure / 100; // Pa --> mbar;
					value = pressure.format("%.1f");
					
					// If single decimal place doesn't fit, truncate to integer.
					if (value.length() > mMaxFieldLength) {
						value = pressure.format(INTEGER_FORMAT);

					// Otherwise, if unit fits as well, add it.
					} else if (value.length() + unit.length() <= mMaxFieldLength) {
						value = value + unit;
					}
				}
				break;
		}

		result["value"] = value;
		return result;
	}
}
