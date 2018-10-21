using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Activity as Activity;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;

using Toybox.Time;
using Toybox.Time.Gregorian;

class DataFields extends Ui.Drawable {

	private var mLeft;
	private var mRight;
	private var mTop;
	private var mBottom;

	private var mBatteryWidth;
	private var mBatteryHeight;

	private var mIconsFont;
	private var mLabelFont;

	private var mFieldCount;
	private var mFieldTypes = new [3]; // Cache values to optimise partial update path.
	private var mHasLiveHR = false; // Is a live HR field currently being shown?
	private var mWasHRAvailable = false; // HR availability at last full draw (in high power mode).
	private var mMaxFieldLength; // Maximum number of characters per field.

	private var FIELD_TYPES = [
		:FIELD_TYPE_HEART_RATE,
		:FIELD_TYPE_BATTERY,
		:FIELD_TYPE_NOTIFICATIONS,
		:FIELD_TYPE_CALORIES,
		:FIELD_TYPE_DISTANCE,
		:FIELD_TYPE_ALARMS,
		:FIELD_TYPE_ALTITUDE,
		:FIELD_TYPE_TEMPERATURE,
		:FIELD_TYPE_BATTERY_HIDE_PERCENT,
		:FIELD_TYPE_HR_LIVE_5S,
		:FIELD_TYPE_SUNRISE_SUNSET
	];

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
		mBatteryHeight = params[:batteryHeight];

		// Initialise mFieldCount and mMaxFieldLength.
		onSettingsChanged();
	}

	function setFonts(iconsFont, labelFont) {
		mIconsFont = iconsFont;
		mLabelFont = labelFont;
	}

	// Cache FieldCount setting, and determine appropriate maximum field length.
	function onSettingsChanged() {
		mFieldCount = App.getApp().getProperty("FieldCount");

		switch (mFieldCount) {
			case 3:
				mMaxFieldLength = 4;
				break;
			case 2:
				mMaxFieldLength = 6;
				break;
			case 1:
				mMaxFieldLength = 8;
				break;
		}

		mFieldTypes[0] = App.getApp().getProperty("Field1Type");
		mFieldTypes[1] = App.getApp().getProperty("Field2Type");
		mFieldTypes[2] = App.getApp().getProperty("Field3Type");

		if ((FIELD_TYPES[mFieldTypes[0]] == :FIELD_TYPE_HR_LIVE_5S) ||
			(FIELD_TYPES[mFieldTypes[1]] == :FIELD_TYPE_HR_LIVE_5S) ||
			(FIELD_TYPES[mFieldTypes[2]] == :FIELD_TYPE_HR_LIVE_5S)) {
				
			mHasLiveHR = true;
		} else {
			mHasLiveHR = false;
		}
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
	private const LIVE_HR_SPOT_RADIUS = 3;

	// "fieldType" parameter is raw property value (it's converted to symbol below).
	private function drawDataField(dc, isPartialUpdate, rawFieldType, x) {
		var isBattery = false;
		var isHeartRate = false;
		var isLiveHeartRate = false;

		switch (FIELD_TYPES[rawFieldType]) {
			case :FIELD_TYPE_BATTERY:
			case :FIELD_TYPE_BATTERY_HIDE_PERCENT:
				isBattery = true;
				break;

			case :FIELD_TYPE_HR_LIVE_5S:
				isLiveHeartRate = true;
				isHeartRate = true;
				break;

			case :FIELD_TYPE_HEART_RATE:			
				isHeartRate = true;
				break;
		}

		// Assume we're only drawing live HR spot every 5 seconds; skip all other partial updates.
		var seconds = Sys.getClockTime().sec;
		if (isPartialUpdate && (!isLiveHeartRate || (seconds % 5))) {
			return;
		}

		// Decide whether spot should be shown or not, based on current seconds.
		var showLiveHRSpot = false;
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
		var result = getValueForFieldType(rawFieldType);
		var value = result["value"];

		// Optimisation: if live HR remains unavailable, skip the rest of this partial update.
		var isHRAvailable = isHeartRate && (value.length() != 0);
		if (isPartialUpdate && !isHRAvailable && !mWasHRAvailable) {
			return;
		}

		// #34 Clip live HR value.
		// Optimisation: hard-code clip rect dimensions. Possible, as all watches use same label font.
		var backgroundColour = App.getApp().getProperty("BackgroundColour");
		dc.setColor(App.getApp().getProperty("MonoLightColour"), backgroundColour);

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
			mLabelFont,
			value,
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// 2. Icon.

		// Grey out icon if no value was retrieved.
		// #37 Do not grey out battery icon (getValueForFieldType() returns empty string).
		var colour;
		if ((value.length() == 0) && (FIELD_TYPES[rawFieldType] != :FIELD_TYPE_BATTERY_HIDE_PERCENT)) {
			colour = App.getApp().getProperty("MeterBackgroundColour");
		} else {
			colour = App.getApp().getProperty("ThemeColour");
		}

		// Battery.
		if (isBattery) {

			App.getApp().getView().drawBatteryMeter(dc, x, mTop, mBatteryWidth, mBatteryHeight);

		// #34 Live HR in low power mode.
		} else if (isLiveHeartRate && isPartialUpdate) {

			// If HR availability changes while in low power mode, then we unfortunately have to draw the full heart.
			// HR availability was recorded during the last high power draw cycle.
			if (isHRAvailable != mWasHRAvailable) {
				mWasHRAvailable = isHRAvailable;

				// Clip full heart, then draw.
				var heartDims = dc.getTextDimensions("3", mIconsFont); // App.getApp().getView().getIconFontChar(:FIELD_TYPE_HR_LIVE_5S)
				dc.setClip(
					x - (heartDims[0] / 2),
					mTop - (heartDims[1] / 2),
					heartDims[0] + 1,
					heartDims[1] + 1);
				dc.setColor(colour, backgroundColour);
				dc.drawText(
					x,
					mTop,
					mIconsFont,
					"3", // App.getApp().getView().getIconFontChar(:FIELD_TYPE_HR_LIVE_5S)
					Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			// Clip spot.
			dc.setClip(
				x - LIVE_HR_SPOT_RADIUS,
				mTop - LIVE_HR_SPOT_RADIUS,
				(2 * LIVE_HR_SPOT_RADIUS) + 1,
				(2 * LIVE_HR_SPOT_RADIUS) + 1);

			// Draw spot, if it should be shown.
			// fillCircle() does not anti-aliase, so use font instead.
			if (showLiveHRSpot && (Activity.getActivityInfo().currentHeartRate != null)) {
				dc.setColor(backgroundColour, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x,
					mTop,
					mIconsFont,
					"=", // App.getApp().getView().getIconFontChar(:LIVE_HR_SPOT)
					Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
				);

			// Otherwise, fill in spot by drawing heart.
			} else {
				dc.setColor(colour, backgroundColour);
				dc.drawText(
					x,
					mTop,
					mIconsFont,
					"3", // App.getApp().getView().getIconFontChar(:FIELD_TYPE_HR_LIVE_5S)
					Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

		// Other icons.
		} else {
			var fieldType = FIELD_TYPES[rawFieldType];

			// #19 Show sunrise icon instead of default sunset icon, if sunrise is next.
			if ((fieldType == :FIELD_TYPE_SUNRISE_SUNSET) && (result["isSunriseNext"] == true)) {
				fieldType = :FIELD_TYPE_SUNRISE;
			}

			dc.setColor(colour, backgroundColour);
			dc.drawText(
				x,
				mTop,
				mIconsFont,
				App.getApp().getView().getIconFontChar(fieldType),
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

			if (isHeartRate) {

				// #34 Save whether HR was available during this high power draw cycle.
				mWasHRAvailable = isHRAvailable;

				// #34 Live HR in high power mode.
				if (showLiveHRSpot && (Activity.getActivityInfo().currentHeartRate != null)) {
					dc.setColor(backgroundColour, Graphics.COLOR_TRANSPARENT);
					dc.drawText(
						x,
						mTop,
						mIconsFont,
						"=", // App.getApp().getView().getIconFontChar(:LIVE_HR_SPOT)
						Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
					);
				}
			}
		}
	}

	// "type" parameter is raw property value (it's converted to symbol below).
	// Return empty result["value"] string if value cannot be retrieved (e.g. unavailable, or unsupported).
	// result["isSunriseNext"] indicates that sunrise icon should be shown for :FIELD_TYPE_SUNRISE_SUNSET, rather than default
	// sunset icon.
	private function getValueForFieldType(type) {
		var result = {};
		var value = "";

		var activityInfo;
		var iterator;
		var sample;
		var battery;
		var settings;
		var distance;
		var altitude;
		var temperature;
		var location;
		var lat;
		var lng;
		var sunTimes;
		var format;
		var unit;

		switch (FIELD_TYPES[type]) {
			case :FIELD_TYPE_HEART_RATE:
			case :FIELD_TYPE_HR_LIVE_5S:
				// #34 Try to retrieve live HR from Activity::Info, before falling back to historical HR from ActivityMonitor.
				activityInfo = Activity.getActivityInfo();
				sample = activityInfo.currentHeartRate;
				if (sample != null) {
					value = sample.format(INTEGER_FORMAT);
				} else if (ActivityMonitor has :getHeartRateHistory) {
					iterator = ActivityMonitor.getHeartRateHistory(1, /* newestFirst */ true);
					sample = iterator.next();
					if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
						value = sample.heartRate.format(INTEGER_FORMAT);
					}
				}
				break;

			case :FIELD_TYPE_BATTERY:
				// #8: battery returned as float. Use floor() to match native. Must match drawBatteryMeter().
				battery = Math.floor(Sys.getSystemStats().battery);
				value = battery.format(INTEGER_FORMAT) + "%";
				break;

			case :FIELD_TYPE_BATTERY_HIDE_PERCENT:
				// #37 Return empty string. updateDataField() has special case so that battery icon is not greyed out.
				break;

			case :FIELD_TYPE_NOTIFICATIONS:
				settings = Sys.getDeviceSettings();
				if (settings.notificationCount > 0) {
					value = settings.notificationCount.format(INTEGER_FORMAT);
				}
				break;

			case :FIELD_TYPE_CALORIES:
				activityInfo = ActivityMonitor.getInfo();
				value = activityInfo.calories.format(INTEGER_FORMAT);
				break;

			case :FIELD_TYPE_DISTANCE:
				settings = Sys.getDeviceSettings();
				activityInfo = ActivityMonitor.getInfo();
				distance = activityInfo.distance.toFloat() / /* CM_PER_KM */ 100000; // #11: Ensure floating point division!

				if (settings.distanceUnits == System.UNIT_METRIC) {
					unit = "km";					
				} else {
					distance *= /* MI_PER_KM */ 0.621371;
					unit = "mi";
				}

				value = distance.format("%.1f");

				// Show unit only if value plus unit fits within maximum field length.
				if ((value.length() + unit.length()) <= mMaxFieldLength) {
					value += unit;
				}
				
				break;

			case :FIELD_TYPE_ALARMS:
				settings = Sys.getDeviceSettings();
				if (settings.alarmCount > 0) {
					value = settings.alarmCount.format(INTEGER_FORMAT);
				}
				break;

			case :FIELD_TYPE_ALTITUDE:
				// #67 Try to retrieve altitude from current activity, before falling back on elevation history.
				// Note that Activity::Info.altitude is supported by CIQ 1.x, but elevation history only on select CIQ 2.x
				// devices.
				activityInfo = Activity.getActivityInfo();
				altitude = activityInfo.altitude;
				if ((altitude == null) && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory)) {
					iterator = SensorHistory.getElevationHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
					sample = iterator.next();
					if ((sample != null) && (sample.data != null)) {
						altitude = sample.data;
					}
				}
				if (altitude != null) {
					settings = Sys.getDeviceSettings();

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

			case :FIELD_TYPE_TEMPERATURE:
				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getTemperatureHistory)) {
					iterator = SensorHistory.getTemperatureHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
					sample = iterator.next();
					if ((sample != null) && (sample.data != null)) {
						temperature = sample.data;

						settings = Sys.getDeviceSettings();
						if (settings.temperatureUnits == System.UNIT_METRIC) {
							unit = "°C";
						} else {
							temperature = (temperature * (9.0 / 5)) + 32; // Ensure floating point division.
							unit = "°F";
						}

						value = temperature.format(INTEGER_FORMAT);

						// Show unit only if value plus unit fits within maximum field length.
						if ((value.length() + unit.length()) <= mMaxFieldLength) {
							value += unit;
						}
					}
				}
				break;

			case :FIELD_TYPE_SUNRISE_SUNSET:
				// #19 Check if location is available from current activity, before falling back on last location from settings.
				activityInfo = Activity.getActivityInfo();
				location = activityInfo.currentLocation;
				if (location != null) {
					location = location.toDegrees();
					lat = location[0];
					lng = location[1];

					// Save current location, in case it goes "stale" and can not longer be retrieved from current activity.
					App.getApp().setProperty("LastLocationLat", lat.toLong());
					App.getApp().setProperty("LastLocationLng", lng.toLong());
				} else {
					lat = App.getApp().getProperty("LastLocationLat");
					if (lat == -360.0) { // -360 is a special value, meaning "unitialised". Can't have null float property.
						lat = null;
					}

					lng = App.getApp().getProperty("LastLocationLng");
					if (lng == -360.0) { // -360 is a special value, meaning "unitialised". Can't have null float property.
						lng = null;
					}
				}

				if ((lat != null) and (lng != null)) {
					// Get sunrise/sunset times in current time zone.
					sunTimes = App.getApp().getView().getSunTimes(lat, lng, null);
					//Sys.println(sunTimes);

					// Sun never rises/sets.
					if ((sunTimes[0] == null) || (sunTimes[1] == null)) {
						value = "---";

						// Sun never rises: sunrise is next, but more than a day from now.
						if (sunTimes[0] == null) {
							result["isSunriseNext"] = true;
						}
					} else {
						var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

						// Convert to same format as sunTimes, for easier comparison. Compare down to minutes only, as seconds not
						// shown to user.
						now = now.hour + (now.min / 60.0);
						//Sys.println(now);

						var nextSunEvent;

						// Daytime: sunset is next.
						if (now > sunTimes[0] && now < sunTimes[1]) {
							nextSunEvent = sunTimes[1];

						// Nighttime: sunrise is next.
						} else {
							nextSunEvent = sunTimes[0];
							result["isSunriseNext"] = true;
						}

						var hour = Math.floor(nextSunEvent).toLong() % 24;
						var min = Math.floor((nextSunEvent - Math.floor(nextSunEvent)) * 60); // Math.floor(fractional_part * 60)
						value = App.getApp().getView().getFormattedTime(hour, min);
					}

				// Waiting for location.
				} else {
					value = "...";
				}

				break;
		}

		result["value"] = value;
		return result;
	}
}
