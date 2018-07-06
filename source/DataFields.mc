using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;

class DataFields extends Ui.Drawable {

	private var mLeft;
	private var mRight;
	private var mTop;
	private var mBottom;

	private var mBatteryFillWidth;
	private var mBatteryFillHeight;

	private var mIconsFont;
	private var mLabelFont;

	private var mFieldCount;
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

		mBatteryFillWidth = params[:batteryFillWidth];
		mBatteryFillHeight = params[:batteryFillHeight];

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
		switch (mFieldCount) {
			case 3:
				drawDataField(dc, App.getApp().getProperty("Field1Type"), mLeft);
				drawDataField(dc, App.getApp().getProperty("Field2Type"), (mRight + mLeft) / 2);
				drawDataField(dc, App.getApp().getProperty("Field3Type"), mRight);
				break;
			case 2:
				drawDataField(dc, App.getApp().getProperty("Field1Type"), mLeft + ((mRight - mLeft) * 0.15));
				drawDataField(dc, App.getApp().getProperty("Field2Type"), mLeft + ((mRight - mLeft) * 0.85));
				break;
			case 1:
				drawDataField(dc, App.getApp().getProperty("Field1Type"), (mRight + mLeft) / 2);
				break;
			case 0:
				break;
		}
	}

	// "fieldType" parameter is raw property value (it's converted to symbol below).
	function drawDataField(dc, fieldType, x) {
		var value = getValueForFieldType(fieldType);
		var colour;

		// Grey out icon if no value was retrieved.
		// #37 Do not grey out battery icon (getValueForFieldType() returns empty string).
		if ((value.length() == 0) && (FIELD_TYPES[fieldType] != :FIELD_TYPE_BATTERY_HIDE_PERCENT)) {
			colour = App.getApp().getProperty("MeterBackgroundColour");
		} else {
			colour = App.getApp().getProperty("ThemeColour");
		}

		// Icon.
		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mTop,
			mIconsFont,
			App.getApp().getInitialView()[0].getIconFontChar(FIELD_TYPES[fieldType]),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Value.
		dc.setColor(App.getApp().getProperty("MonoLightColour"), Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mBottom,
			mLabelFont,
			value,
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Battery meter.
		switch (FIELD_TYPES[fieldType]) {
			case :FIELD_TYPE_BATTERY:
			case :FIELD_TYPE_BATTERY_HIDE_PERCENT:
				fillBatteryMeter(dc, x);
				break;
		}
	}

	// "type" parameter is raw property value (it's converted to symbol below).
	// Return empty string if value cannot be retrieved (e.g. unavailable, or unsupported).
	function getValueForFieldType(type) {
		var value = "";

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
				if (ActivityMonitor has :getHeartRateHistory) {
					iterator = ActivityMonitor.getHeartRateHistory(1, /* newestFirst */ true);
					sample = iterator.next();
					if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
						value = sample.heartRate.format("%d");
					}
				}
				break;

			case :FIELD_TYPE_BATTERY:
				// #8: battery returned as float. Use floor() to match native. Must match fillBatteryMeter().
				battery = Math.floor(Sys.getSystemStats().battery);
				value = battery.format("%d") + "%";
				break;

			case :FIELD_TYPE_BATTERY_HIDE_PERCENT:
				// #37 Return empty string. updateDataField() has special case so that battery icon is not greyed out.
				break;

			case :FIELD_TYPE_NOTIFICATIONS:
				settings = Sys.getDeviceSettings();
				if (settings.notificationCount > 0) {
					value = settings.notificationCount.format("%d");
				}
				break;

			case :FIELD_TYPE_CALORIES:
				activityInfo = ActivityMonitor.getInfo();
				value = activityInfo.calories.format("%d");
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
					value = settings.alarmCount.format("%d");
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

						value = altitude.format("%d");

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

						value = temperature.format("%d");

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

	function fillBatteryMeter(dc, x) {
		// #8: battery returned as float. Use floor() to match native. Must match getValueForFieldType().
		var batteryLevel = Math.floor(Sys.getSystemStats().battery);
		var colour;
		var fillWidth, fillHeight;

		// Fill colour based on battery level.
		if (batteryLevel <= BATTERY_LEVEL_CRITICAL) {
			colour = Graphics.COLOR_RED;
		} else if (batteryLevel <= BATTERY_LEVEL_LOW) {
			colour = Graphics.COLOR_YELLOW;
		} else {
			colour = App.getApp().getProperty("ThemeColour");
		}

		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);

		dc.fillRectangle(
			x - (mBatteryFillWidth / 2) - 1,
			mTop - (mBatteryFillHeight / 2) + 1,
			Math.ceil(mBatteryFillWidth * (batteryLevel / 100)), 
			mBatteryFillHeight);	
	}
}
