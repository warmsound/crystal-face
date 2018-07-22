using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Activity as Activity;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;

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
	private var mMaxFieldLength; // Maximum number of characters per field.
	
	/* public */ var mLiveHRSpot = false; // Whether to show live HR spot: view toggles value in high power mode.
	private var mPartialUpdateCount = 0;

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
		:FIELD_TYPE_HR_LIVE_5S
	];

	private const BATTERY_LEVEL_LOW = 20;
	private const BATTERY_LEVEL_CRITICAL = 10;

	private const CM_PER_KM = 100000;
	private const MI_PER_KM = 0.621371;
	private const FT_PER_M = 3.28084;

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
	}

	function draw(dc) {
		update(dc, /* isPartialUpdate */ false);
	}

	function update(dc, isPartialUpdate) {
		if (isPartialUpdate) {
			++mPartialUpdateCount;
		}

		switch (mFieldCount) {
			case 3:
				drawDataField(dc, isPartialUpdate, App.getApp().getProperty("Field1Type"), mLeft);
				drawDataField(dc, isPartialUpdate, App.getApp().getProperty("Field2Type"), (mRight + mLeft) / 2);
				drawDataField(dc, isPartialUpdate, App.getApp().getProperty("Field3Type"), mRight);
				break;
			case 2:
				drawDataField(dc, isPartialUpdate, App.getApp().getProperty("Field1Type"), mLeft + ((mRight - mLeft) * 0.15));
				drawDataField(dc, isPartialUpdate, App.getApp().getProperty("Field2Type"), mLeft + ((mRight - mLeft) * 0.85));
				break;
			case 1:
				drawDataField(dc, isPartialUpdate, App.getApp().getProperty("Field1Type"), (mRight + mLeft) / 2);
				break;
			case 0:
				break;
		}
	}

	// Both regular and small icon fonts use same spot size for easier optimisation.
	private const LIVE_HR_SPOT_RADIUS = 3;

	// "fieldType" parameter is raw property value (it's converted to symbol below).
	private function drawDataField(dc, isPartialUpdate, fieldType, x) {
		var isBattery = false;
		var isHeartRate = false;
		var isLiveHeartRate = false;

		switch (FIELD_TYPES[fieldType]) {
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
		if (isPartialUpdate && (!isLiveHeartRate || (mPartialUpdateCount % 5))) {
			return;
		}

		var value = getValueForFieldType(fieldType);
		var backgroundColour = App.getApp().getProperty("BackgroundColour");
		var colour;

		// 1. Value: draw first, as top of text overlaps icon.

		// #34 Clip live HR value.
		// Optimisation: hard-code clip rect dimensions. Possible, as all watches use same label font.
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
		if ((value.length() == 0) && (FIELD_TYPES[fieldType] != :FIELD_TYPE_BATTERY_HIDE_PERCENT)) {
			colour = App.getApp().getProperty("MeterBackgroundColour");
		} else {
			colour = App.getApp().getProperty("ThemeColour");
		}

		// Battery.
		if (isBattery) {

			App.getApp().getView().drawBatteryMeter(dc, x, mTop, mBatteryWidth, mBatteryHeight);

		// #34 Live HR in low power mode.
		} else if (isLiveHeartRate && isPartialUpdate) {

			dc.setClip(
				x - LIVE_HR_SPOT_RADIUS,
				mTop - LIVE_HR_SPOT_RADIUS,
				(2 * LIVE_HR_SPOT_RADIUS) + 1,
				(2 * LIVE_HR_SPOT_RADIUS) + 1);

			// If pulse is high, draw spot.
			// fillCircle() does not anti-aliase, so use font instead.
			if (mLiveHRSpot && (Activity.getActivityInfo().currentHeartRate != null)) {
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

			// Toggle spot for next partial update.
			mLiveHRSpot = !mLiveHRSpot;

		} else {

			dc.setColor(colour, backgroundColour);
			dc.drawText(
				x,
				mTop,
				mIconsFont,
				App.getApp().getView().getIconFontChar(FIELD_TYPES[fieldType]),
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// #34 Live HR in high power mode.
			if (isHeartRate && mLiveHRSpot && (Activity.getActivityInfo().currentHeartRate != null)) {
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

	// "type" parameter is raw property value (it's converted to symbol below).
	// Return empty string if value cannot be retrieved (e.g. unavailable, or unsupported).
	private function getValueForFieldType(type) {
		var value = "";
		var INTEGER_FORMAT = "%d";

		var activityInfo;
		var iterator;
		var sample;
		var battery;
		var settings;
		var distance;
		var altitude;
		var temperature;
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
				distance = activityInfo.distance.toFloat() / CM_PER_KM; // #11: Ensure floating point division!

				if (settings.distanceUnits == System.UNIT_METRIC) {
					unit = "km";					
				} else {
					distance *= MI_PER_KM;
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
				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory)) {
					iterator = SensorHistory.getElevationHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
					sample = iterator.next();
					if ((sample != null) && (sample.data != null)) {
						altitude = sample.data;

						settings = Sys.getDeviceSettings();

						// Metres (no conversion necessary).
						if (settings.elevationUnits == System.UNIT_METRIC) {
							unit = "m";

						// Feet.
						} else {
							altitude *= FT_PER_M;
							unit = "ft";
						}

						value = altitude.format(INTEGER_FORMAT);

						// Show unit only if value plus unit fits within maximum field length.
						if ((value.length() + unit.length()) <= mMaxFieldLength) {
							value += unit;
						}
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
		}

		return value;
	}
}
