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

	private var mIconsFont;
	private var mLabelFont;

	private var FIELD_TYPES = {
		0 => :FIELD_TYPE_HEART_RATE,
		1 => :FIELD_TYPE_BATTERY,
		2 => :FIELD_TYPE_NOTIFICATIONS,
		3 => :FIELD_TYPE_CALORIES,
		4 => :FIELD_TYPE_DISTANCE,
		5 => :FIELD_TYPE_ALARMS,
		6 => :FIELD_TYPE_ALTITUDE,
		7 => :FIELD_TYPE_TEMPERATURE,
		8 => :FIELD_TYPE_BATTERY_HIDE_PERCENT,
	};

	private var ICON_FONT_CHARS = {
		:GOAL_TYPE_STEPS => "0",
		:GOAL_TYPE_FLOORS_CLIMBED => "1",
		:GOAL_TYPE_ACTIVE_MINUTES => "2",
		:FIELD_TYPE_HEART_RATE => "3",
		:FIELD_TYPE_BATTERY => "4",
		:FIELD_TYPE_BATTERY_HIDE_PERCENT => "4",
		:FIELD_TYPE_NOTIFICATIONS => "5",
		:FIELD_TYPE_CALORIES => "6",
		:GOAL_TYPE_CALORIES => "6", // Use calories icon for both field and goal.
		:FIELD_TYPE_DISTANCE => "7",
		:INDICATOR_BLUETOOTH => "8",
		:GOAL_TYPE_BATTERY => "9",
		:FIELD_TYPE_ALARMS => ":",
		:FIELD_TYPE_ALTITUDE => ";",
		:FIELD_TYPE_TEMPERATURE => "<"
	};

	const BATTERY_FILL_WIDTH = 18;
	const BATTERY_FILL_HEIGHT = 6;

	const BATTERY_WIDTH_SMALL = 24;
	const BATTERY_FILL_WIDTH_SMALL = 15;
	const BATTERY_FILL_HEIGHT_SMALL = 4;

	const BATTERY_LEVEL_LOW = 20;
	const BATTERY_LEVEL_CRITICAL = 10;

	const CM_PER_KM = 100000;
	const MI_PER_KM = 0.621371;
	const FT_PER_M = 3.28084;

	function initialize(params) {
		Drawable.initialize(params);

		mLeft = params[:left];
		mRight = params[:right];
		mTop = params[:top];
		mBottom = params[:bottom];
	}

	function setFonts(iconsFont, labelFont) {
		mIconsFont = iconsFont;
		mLabelFont = labelFont;
	}

	function draw(dc) {
		switch (App.getApp().getProperty("FieldCount")) {
			case 3:
				drawDataField(dc, App.getApp().getProperty("Field1Type"), mLeft);
				drawDataField(dc, App.getApp().getProperty("Field2Type"), (mRight + mLeft) / 2);
				drawDataField(dc, App.getApp().getProperty("Field3Type"), mRight);
				break;
			case 2:
				drawDataField(dc, App.getApp().getProperty("Field1Type"), mLeft + ((mRight - mLeft) * 0.125));
				drawDataField(dc, App.getApp().getProperty("Field2Type"), mLeft + ((mRight - mLeft) * 0.875));
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
			ICON_FONT_CHARS[FIELD_TYPES[fieldType]],
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

				// Show unit only if distance is less than 10, to save space.
				if (distance < 10) {
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
						if ((value.length() + unit.length()) <= MAX_FIELD_LENGTH) {
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
						if ((value.length() + unit.length()) <= MAX_FIELD_LENGTH) {
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

		if (batteryLevel <= BATTERY_LEVEL_CRITICAL) {
			colour = Graphics.COLOR_RED;
		} else if (batteryLevel <= BATTERY_LEVEL_LOW) {
			colour = Graphics.COLOR_YELLOW;
		} else {
			colour = App.getApp().getProperty("ThemeColour");
		}

		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);

		// Layout uses small battery icon.
		if (dc.getTextWidthInPixels(ICON_FONT_CHARS[:FIELD_TYPE_BATTERY], mIconsFont) == BATTERY_WIDTH_SMALL) {
			fillWidth = BATTERY_FILL_WIDTH_SMALL;
			fillHeight = BATTERY_FILL_HEIGHT_SMALL;
		} else {
			fillWidth = BATTERY_FILL_WIDTH;
			fillHeight = BATTERY_FILL_HEIGHT;
		}
		dc.fillRectangle(
			x - (fillWidth / 2) - 1,
			mTop - (fillHeight / 2) + 1,
			Math.ceil(fillWidth * (batteryLevel / 100)), 
			fillHeight);	
	}
}
