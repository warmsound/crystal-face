using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Activity as Activity;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Complications;

enum /* FIELD_TYPES */ {
	// Pseudo-fields.	
	FIELD_TYPE_SUNRISE = -1,	
	//FIELD_TYPE_SUNSET = -2,

	// Real fields (used by properties).
	FIELD_TYPE_HEART_RATE = 0,
	FIELD_TYPE_BATTERY, // 1
	FIELD_TYPE_NOTIFICATIONS, // 2
	FIELD_TYPE_CALORIES, // 3
	FIELD_TYPE_DISTANCE, // 4
	FIELD_TYPE_ALARMS, // 5
	FIELD_TYPE_ALTITUDE, // 6
	FIELD_TYPE_TEMPERATURE, // 7
	FIELD_TYPE_BATTERY_HIDE_PERCENT, // 8
	FIELD_TYPE_HR_LIVE_5S, // 9
	FIELD_TYPE_SUNRISE_SUNSET, // 10
	FIELD_TYPE_WEATHER, // 11
	FIELD_TYPE_PRESSURE, // 12
	FIELD_TYPE_HUMIDITY, // 13
	FIELD_TYPE_PULSE_OX, // 14
	FIELD_FLOOR_CLIMBED, // 15
	FIELD_SOLAR_INTENSITY,  // 16
	FIELD_BODY_BATTERY, // 17
	FIELD_RECOVERY_TIME, // 18
	FIELD_STRESS_LEVEL, // 19
	FIELD_TYPE_ACTIVE_CALORIES, // 20
}

class DataFields extends Ui.Drawable {

	var mLeft;
	var mRight;
	var mTop;
	private var mBottom;

	private var mWeatherIconsFont;
	private var mWeatherIconsSubset = null; // null, "d" for day subset, "n" for night subset.

	private var mFieldCount;
	private var mHasLiveHR = false; // Is a live HR field currently being shown?
	private var mWasHRAvailable = false; // HR availability at last full draw (in high power mode).
	private var mMaxFieldLength; // Maximum number of characters per field.
	private var mBatteryWidth; // Width of battery meter.
	private var mWeather;
	// private const CM_PER_KM = 100000;
	// private const MI_PER_KM = 0.621371;
	// private const FT_PER_M = 3.28084;

	function initialize(params) {
		Drawable.initialize(params);

		mLeft = params[:left];
		mRight = params[:right];
		mTop = params[:top];
		mBottom = params[:bottom];

		mBatteryWidth = params[:batteryWidth];

		// Initialise mFieldCount and mMaxFieldLength.
		onSettingsChanged();
	}

	// Cache FieldCount setting, and determine appropriate maximum field length.
	(:noComplications)
	function onSettingsChanged() {
		var view = App.getApp().getView();

		// #123 Protect against null or unexpected type e.g. String.
		mFieldCount = $.getIntProperty("FieldCount", 3);

		// #116 Handle FieldCount = 0 correctly.
		mMaxFieldLength = [0, 8, 6, 4][mFieldCount];

		mHasLiveHR = view.hasField(FIELD_TYPE_HR_LIVE_5S);

		if (!view.hasField(FIELD_TYPE_WEATHER)) {
			mWeatherIconsFont = null;
			mWeatherIconsSubset = null;
		}
	}
	
	(:hasComplications)
	function onSettingsChanged() {
		var view = App.getApp().getView();

		// #123 Protect against null or unexpected type e.g. String.
		mFieldCount = $.getIntProperty("FieldCount", 3);

		// #116 Handle FieldCount = 0 correctly.
		mMaxFieldLength = [0, 8, 6, 4][mFieldCount];

		mHasLiveHR = view.hasField(FIELD_TYPE_HR_LIVE_5S);

		if (!view.hasField(FIELD_TYPE_WEATHER)) {
			mWeatherIconsFont = null;
			mWeatherIconsSubset = null;
		}

		if (Toybox has :Complications && view.useComplications()) {
			var complications = [{"type" => FIELD_BODY_BATTERY, "complicationType" => Complications.COMPLICATION_TYPE_BODY_BATTERY},
								 {"type" => FIELD_STRESS_LEVEL, "complicationType" => Complications.COMPLICATION_TYPE_STRESS},
								 {"type" => FIELD_FLOOR_CLIMBED, "complicationType" => Complications.COMPLICATION_TYPE_FLOORS_CLIMBED},
								 {"type" => FIELD_TYPE_PULSE_OX, "complicationType" => Complications.COMPLICATION_TYPE_PULSE_OX},
								 {"type" => FIELD_TYPE_HEART_RATE, "complicationType" => Complications.COMPLICATION_TYPE_HEART_RATE},
								 {"type" => FIELD_RECOVERY_TIME, "complicationType" => Complications.COMPLICATION_TYPE_RECOVERY_TIME},
								 {"type" => FIELD_TYPE_ALTITUDE, "complicationType" => Complications.COMPLICATION_TYPE_ALTITUDE},
								 {"type" => FIELD_TYPE_WEATHER, "complicationType" => Complications.COMPLICATION_TYPE_CURRENT_WEATHER}, // Only for onPress. We do nothing with what is returned since it's missing the temperature. Adding it would require a too big change and extra space in App class for basically no gain
								 {"type" => FIELD_TYPE_SUNRISE_SUNSET, "complicationType" => Complications.COMPLICATION_TYPE_SUNRISE}, // Only for onPress. We do nothing with what is returned since it's missing the temperature. Adding it would require a too big change and extra space in App class for basically no gain
								 {"type" => FIELD_TYPE_CALORIES, "complicationType" => Complications.COMPLICATION_TYPE_CALORIES},
								 {"type" => FIELD_TYPE_ACTIVE_CALORIES, "complicationType" => Complications.COMPLICATION_TYPE_CALORIES}
								];

			var fieldTypes = view.mFieldTypes;
			var filled = [false, false, false];
			var i;

			for (i = 0; i < complications.size(); i++) {
				if (view.hasField(complications[i].get("type"))) {
					for (var j = 0; j < mFieldCount; j++) {
						if (fieldTypes[j].get("type") == complications[i].get("type")) {
							$.updateComplications("", "Complication_F", j + 1, complications[i].get("complicationType"));
							fieldTypes[j].put("ComplicationType", complications[i].get("complicationType"));
							filled[j] = true;
						}
					}
				}
			}

			// Now delete any fields that doesn't have a Complication
			for (i = 1; i < 4; i++)	{
				if (filled[i - 1] == false) {
					Storage.deleteValue("Complication_F" + i);
				}
			}
		}
	}

	function draw(dc) {
		// I'm getting wierd crashes on AMOLED watchs as if some of the fields of the datafields drawable aren't initialized. Only thing in common is AoD.
		// Therefore added a check to make sure we aren't drawing will if are or were in burnin protection.
		if (!App.getApp().getView().burnInProtectionIsOrWasActive()) {
			update(dc, /* isPartialUpdate */ false);
		}
		else {
			/*DEBUG*/ logMessage("datafields draw Skipping because of burning protections");
		}
	}

	function update(dc, isPartialUpdate) {
		if (isPartialUpdate && !mHasLiveHR) {
			return;
		}

		var fieldTypes = App.getApp().getView().mFieldTypes;

		/*var spacingX = Sys.getDeviceSettings().screenWidth / (2 * mFieldCount);
		var spacingY = Sys.getDeviceSettings().screenHeight / 4;

		var left = mLeft;
		var right = mRight;
		var top = mTop;*/

		switch (mFieldCount) {
			case 3:
				drawDataField(dc, isPartialUpdate, fieldTypes[0].get("type"), mLeft, 0);
				drawDataField(dc, isPartialUpdate, fieldTypes[1].get("type"), (mRight + mLeft) / 2, 1);
				drawDataField(dc, isPartialUpdate, fieldTypes[2].get("type"), mRight, 2);
				// dc.drawRectangle(left - spacingX / 2, top - spacingY / 2, spacingX, spacingY);
				// dc.drawRectangle((right + left) / 2 - spacingX / 2, top - spacingY /2, spacingX, spacingY);
				// dc.drawRectangle(right - spacingX / 2, top - spacingY / 2, spacingX, spacingY);
				break;
			case 2:
				drawDataField(dc, isPartialUpdate, fieldTypes[0].get("type"), mLeft + ((mRight - mLeft) * 0.15), 0);
				drawDataField(dc, isPartialUpdate, fieldTypes[1].get("type"), mLeft + ((mRight - mLeft) * 0.85), 1);
				// dc.drawRectangle(left + ((right - left) * 0.15) - spacingX / 2, top - spacingY / 2, spacingX, spacingY);
				// dc.drawRectangle(left + ((right - left) * 0.85) - spacingX / 2, top - spacingY / 2, spacingX, spacingY);
				break;
			case 1:
				drawDataField(dc, isPartialUpdate, fieldTypes[0].get("type"), (mRight + mLeft) / 2, 0);
				// dc.drawRectangle((right + left) / 2 - spacingX / 2, top - spacingY / 2, spacingX, spacingY);
				break;
			/*
			case 0:
				break;
			*/
		}
	}

	// Both regular and small icon fonts use same spot size for easier optimisation.
	//private const LIVE_HR_SPOT_RADIUS = 3;

	private function drawDataField(dc, isPartialUpdate, fieldType, x, index) {		

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
		var result = getValueForFieldType(fieldType, index);
		var value = result["value"];
		var stale = result["stale"];

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
		var colour = (value.length() == 0 || stale) ? gMeterBackgroundColour : gThemeColour;

		// Battery.
		if ((fieldType == FIELD_TYPE_BATTERY) || (fieldType == FIELD_TYPE_BATTERY_HIDE_PERCENT)) {
			$.drawBatteryMeter(dc, x, mTop, mBatteryWidth, mBatteryWidth / 2);

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
					mWeatherIconsFont = Ui.loadResource((mWeatherIconsSubset.equals("d")) ?
						Rez.Fonts.WeatherIconsFontDay : Rez.Fonts.WeatherIconsFontNight);
				}
				font = mWeatherIconsFont;

				// #89 To avoid Unicode issues on real 735xt, rewrite char IDs as regular ASCII values, day icons starting from
				// "A", night icons starting from "a" ("I" is shared). Also makes subsetting easier in fonts.xml.
				// See https://openweathermap.org/weather-conditions.
				icon = {
					// Day icon               Night icon                Description
					"01d" => "H" /* 61453 */, "01n" => "f" /* 61486 */, // clear sky
					"02d" => "G" /* 61452 */, "02n" => "g" /* 61569 */, // few clouds
					"03d" => "B" /* 61442 */, "03n" => "h" /* 61574 */, // scattered clouds
					"04d" => "I" /* 61459 */, "04n" => "I" /* 61459 */, // broken clouds: day and night use same icon
					"09d" => "E" /* 61449 */, "09n" => "d" /* 61481 */, // shower rain
					"10d" => "D" /* 61448 */, "10n" => "c" /* 61480 */, // rain
					"11d" => "C" /* 61445 */, "11n" => "b" /* 61477 */, // thunderstorm
					"13d" => "F" /* 61450 */, "13n" => "e" /* 61482 */, // snow
					"50d" => "A" /* 61441 */, "50n" => "a" /* 61475 */, // mist
				}[result["weatherIcon"]];

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
					FIELD_TYPE_PULSE_OX => "B", // SG Addition
					FIELD_FLOOR_CLIMBED => "1", // SG Addition
					FIELD_SOLAR_INTENSITY => "D", // SG Addition
					FIELD_BODY_BATTERY => "E", // SG Addition
					FIELD_RECOVERY_TIME => "F", // SG Addition
					FIELD_STRESS_LEVEL => "G", // SG Addition
					FIELD_TYPE_ACTIVE_CALORIES => "H" // SG Addition
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
	private function getValueForFieldType(type, index) {
		var result = {};
		var value = "";
		var stale = false;

		var settings = Sys.getDeviceSettings();

		var activityInfo;
		var sample;	
		var altitude;
		var pressure = null; // May never be initialised if no support for pressure (CIQ 1.x devices).
		var temperature;
		var sunTimes;
		var unit;
		var info;
		var view = App.getApp().getView();
		var fieldTypes = view.mFieldTypes;

		switch (type) {
			// SG Addition
			case FIELD_RECOVERY_TIME:
				if (Toybox has :Complications && view.useComplications()) {
					var tmpValue = fieldTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						value = $.MinutesToTimeString(tmpValue);
					}
				}
				info = ActivityMonitor.getInfo();
				var t = (info has :timeToRecovery);
				if (value.length() == 0 && t == true) {
					var recoveryTyime = info.timeToRecovery;
					if (recoveryTyime != null) {
						value = recoveryTyime.format(INTEGER_FORMAT);
					}
				}
				break;
			// SG Addition
			case FIELD_BODY_BATTERY:
				if (Toybox has :Complications && view.useComplications()) {
					var tmpValue = fieldTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						value = tmpValue.toString();
					}
				}
				if (value.length() == 0 && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
					var bodyBattery = Toybox.SensorHistory.getBodyBatteryHistory({:period=>1});
					if (bodyBattery != null) {
						bodyBattery = bodyBattery.next();
					}
					if (bodyBattery !=null) {
						bodyBattery = bodyBattery.data;
					}
					if (bodyBattery != null && bodyBattery >= 0 && bodyBattery <= 100) {
						value = bodyBattery.format(INTEGER_FORMAT);
					}
				}
				break;
			// SG Addition
			case FIELD_STRESS_LEVEL:
				if (Toybox has :Complications && view.useComplications()) {
					var tmpValue = fieldTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						value = tmpValue.toString();
					}
				}
				if (value.length() == 0 && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory)) {
					var stressLevel = Toybox.SensorHistory.getStressHistory({:period=>1});
					if (stressLevel != null) {
						stressLevel = stressLevel.next();
					}
					if (stressLevel !=null) {
						stressLevel = stressLevel.data;
					}
					if (stressLevel != null && stressLevel >= 0 && stressLevel <= 100) {
						value = stressLevel.format(INTEGER_FORMAT);
					}
				}
				break;
			// SG Addition
			case FIELD_SOLAR_INTENSITY:
				var stats = Sys.getSystemStats();
				if (stats has :solarIntensity) {
					var solarIntensity = stats.solarIntensity;
					if (solarIntensity != null) {
						value = solarIntensity.format(INTEGER_FORMAT);
					}
				}
				break;
			// SG Addition
			case FIELD_FLOOR_CLIMBED:
 				info = ActivityMonitor.getInfo();
				if (info has :floorsClimbed) {
					var climbed = info.floorsClimbed;
					var goal = info.floorsClimbedGoal;
					if (climbed != null && goal != null) {
						value = climbed.format(INTEGER_FORMAT) + "/" + goal.format(INTEGER_FORMAT);
					}
				}
				break;
			// SG Addition
			case FIELD_TYPE_PULSE_OX:
				if (Toybox has :Complications && view.useComplications()) {
					var tmpValue = fieldTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						value = tmpValue.toString() + "%";
					}
				}
				if (value.length() == 0) {
					activityInfo = Activity.getActivityInfo();
					sample = activityInfo != null and activityInfo has :currentOxygenSaturation ? activityInfo.currentOxygenSaturation : null;
					if (sample != null) {
						value = sample.format(INTEGER_FORMAT) + "%";
					}
				}
				break;
			case FIELD_TYPE_HEART_RATE:
				if (Toybox has :Complications && view.useComplications()) {
					var tmpValue = fieldTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						value = tmpValue.toString();
					}
				}
				// Yes, no break. We flow through in case with don't have Complication. FIELD_TYPE_HEART_RATE and FIELD_TYPE_HR_LIVE_5S were doing the same thing
			case FIELD_TYPE_HR_LIVE_5S:
				// #34 Try to retrieve live HR from Activity::Info, before falling back to historical HR from ActivityMonitor.
				if (value.length() == 0) {
					activityInfo = Activity.getActivityInfo();
					sample = activityInfo.currentHeartRate;
					if (sample != null) {
						value = sample.format(INTEGER_FORMAT);
					} else if (ActivityMonitor has :getHeartRateHistory) {
						sample = ActivityMonitor.getHeartRateHistory(1, true).next();
						if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
							value = sample.heartRate.format(INTEGER_FORMAT);
						}
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

			// SG Addition
			case FIELD_TYPE_ACTIVE_CALORIES:
			case FIELD_TYPE_CALORIES:
				var fromComplication = false;
				var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);		
				var profile = UserProfile.getProfile();
				var age    = today.year - profile.birthYear;
				var weight = profile.weight / 1000.0;
				var restCalories = ((profile.gender == UserProfile.GENDER_MALE) ? 5.2 : -197.6) - 6.116 * age + 7.628 * profile.height + 12.2 * weight;
				restCalories   = Math.round((today.hour * 60 + today.min) * restCalories / 1440 ).toNumber();

				if (Toybox has :Complications && view.useComplications()) {
					var tmpValue = fieldTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						value = tmpValue;
						fromComplication = true;
					}
				}

				if (!fromComplication) {
					activityInfo = ActivityMonitor.getInfo();
					value = activityInfo.calories;
				}

				if (type == FIELD_TYPE_CALORIES) {
					if (fromComplication) {
						value += restCalories;
					}
				}
				else {
					if (!fromComplication) {
						value -= restCalories;
					}
				}

				value = value.format(INTEGER_FORMAT);

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
				if (Toybox has :Complications && view.useComplications()) { // Try Complication first
					altitude = fieldTypes[index].get("ComplicationValue");
				}
				if (altitude == null) {
					activityInfo = Activity.getActivityInfo();
					altitude = activityInfo.altitude;
				}

				if ((altitude == null) && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory)) {
					sample = SensorHistory.getElevationHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST }).next();
					if ((sample != null) && (sample.data != null)) {
						altitude = sample.data;
					}
				}

				if (altitude == null) { // If we didn't get an altitude this time, grab the saved one
					altitude = Storage.getValue("LastAltitude");
				} else { // We got altitude info, store it in case we lose it
					Storage.setValue("LastAltitude", altitude);
				}

				if (altitude != null) { // If we didn't get an altitude this time, grab the saved one
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

						value = temperature.format(INTEGER_FORMAT) + "";
					}
				}
				break;

			case FIELD_TYPE_SUNRISE_SUNSET:
				var weather = Weather.getCurrentConditions();
				if (weather != null) {
					var now = Time.now();
					var myLocation = weather.observationLocationPosition;
					if (Toybox.Weather has :getSunrise) {
						var sunrise = Weather.getSunrise(myLocation, now);
						var sunset = Weather.getSunset(myLocation, now);

						var sunriseTime = Gregorian.info(sunrise, Time.FORMAT_SHORT);
						var sunsetTime = Gregorian.info(sunset, Time.FORMAT_SHORT);

						var sinceSunrise = sunrise.compare(now);
						var sinceSunset = now.compare(sunset);

						if (sinceSunrise >= 0 || sinceSunset >= 0) {
							result["isSunriseNext"] = true;
							value = $.getFormattedTime(sunriseTime.hour, sunriseTime.min, sunriseTime.sec);
						}
						else {
							value = $.getFormattedTime(sunsetTime.hour, sunsetTime.min, sunsetTime.sec);
						}
						value = value[:hour] + ":" + value[:min] + value[:amPm];
					}
					else {
						var myLocationArray = myLocation.toDegrees();
						var nextSunEvent = 0;
						now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

						// Convert to same format as sunTimes, for easier comparison. Add a minute, so that e.g. if sun rises at
						// 07:38:17, then 07:38 is already consided daytime (seconds not shown to user).
						now = now.hour + ((now.min + 1) / 60.0);
						//logMessage(now);

						// Get today's sunrise/sunset times in current time zone.
						sunTimes = getSunTimes(myLocationArray[0], myLocationArray[1], null, /* tomorrow */ false);
						//logMessage(sunTimes);

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
								sunTimes = getSunTimes(myLocationArray[0], myLocationArray[1], null, /* tomorrow */ true);
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
							value = App.getApp().getFormattedTime(hour, min, 0);
							value = value[:hour] + ":" + value[:min] + value[:amPm]; 
						}
					}
				}
				else {
					value = "???";

					if (!settings.phoneConnected) {
						stale = true;
					}
				}
				break;

			case FIELD_TYPE_WEATHER:
			case FIELD_TYPE_HUMIDITY:

				// Default = sunshine!
				if (type == FIELD_TYPE_WEATHER) {
					result["weatherIcon"] = "01d";
				}

				// Only read that dictionnary from Storage if it has changed (or we don't have a local copy), otherwise read our stored weather data
				if (mWeather == null || Storage.getValue("NewWeatherInfo") != null) { 
					mWeather = Storage.getValue("OpenWeatherMapCurrent");
					Storage.deleteValue("NewWeatherInfo");
					/*DEBUG*/ logMessage("getValueForFieldType:new weather data: " + mWeather);
				}

				// Stored weather data available.
				if (mWeather != null && mWeather instanceof Lang.Dictionary && mWeather["cod"] == 200) {
					// FIELD_TYPE_WEATHER.
					if (type == FIELD_TYPE_WEATHER) {
						value = mWeather["temp"];
						try {
							if (settings.temperatureUnits == System.UNIT_STATUTE) {
								value = (value * (9.0 / 5)) + 32; // Convert to Farenheit: ensure floating point division.
							}

							value = value.format(INTEGER_FORMAT) + "°";
						}
						catch (e) {
							/*DEBUG*/ logMessage("getValueForFieldType: Caught exception " + e);
							value = "???";
						}
						result["weatherIcon"] = mWeather["icon"];

					// FIELD_TYPE_HUMIDITY.
					} else {
						value = mWeather["humidity"];
						value = value.format(INTEGER_FORMAT) + "%";
					}
				}
				// Didn't receive weather from Garmin
				else {
					value = "N/A";

					if (!settings.phoneConnected) {
						stale = true;
					}
				}

				/*DEBUG*/ logMessage("getValueForFieldType:Weather value is " + value + " stale is " + stale);
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
		result["stale"] = stale;
		return result;
	}
}

