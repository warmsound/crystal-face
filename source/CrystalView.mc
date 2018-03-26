using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

class CrystalView extends Ui.WatchFace {

	private var mHoursFont;
	private var mMinutesFont;
	private var mSecondsFont;

	private var mDateFont;

	private var mTime;
	
	private var GOAL_TYPES = {
		App.GOAL_TYPE_STEPS => :GOAL_TYPE_STEPS,
		App.GOAL_TYPE_FLOORS_CLIMBED => :GOAL_TYPE_FLOORS_CLIMBED,
		App.GOAL_TYPE_ACTIVE_MINUTES => :GOAL_TYPE_ACTIVE_MINUTES,
		
		-1 => :GOAL_TYPE_BATTERY
	};

	private var FIELD_TYPES = {
		0 => :FIELD_TYPE_HEART_RATE,
		1 => :FIELD_TYPE_BATTERY,
		2 => :FIELD_TYPE_NOTIFICATIONS,
		3 => :FIELD_TYPE_CALORIES,
		4 => :FIELD_TYPE_DISTANCE
	};

	private var ICON_FONT_CHARS = {
		:GOAL_TYPE_STEPS => "0",
		:GOAL_TYPE_FLOORS_CLIMBED => "1",
		:GOAL_TYPE_ACTIVE_MINUTES => "2",
		:FIELD_TYPE_HEART_RATE => "3",
		:FIELD_TYPE_BATTERY => "4",
		:FIELD_TYPE_NOTIFICATIONS => "5",
		:FIELD_TYPE_CALORIES => "6",
		:FIELD_TYPE_DISTANCE => "7",
		:INDICATOR_BLUETOOTH => "8",
		:GOAL_TYPE_BATTERY => "9"
	};

	// Cache references to drawables immediately after layout, to avoid expensive findDrawableById() calls in onUpdate();
	private var mDrawables = {};

	const BATTERY_FILL_WIDTH = 18;
	const BATTERY_FILL_HEIGHT = 6;

	const BATTERY_WIDTH_SMALL = 24;
	const BATTERY_FILL_WIDTH_SMALL = 15;
	const BATTERY_FILL_HEIGHT_SMALL = 4;

	const BATTERY_LEVEL_LOW = 20;
	const BATTERY_LEVEL_CRITICAL = 10;

	const CM_PER_KM = 100000;
	const MI_PER_KM = 0.621371;

	// N.B. Not all watches that support SDK 2.3.0 support per-second updates e.g. 735xt.
	const PER_SECOND_UPDATES_SUPPORTED = Ui.WatchFace has :onPartialUpdate;

	function initialize() {
		WatchFace.initialize();
	}

	// Load your resources here
	function onLayout(dc) {
		mHoursFont = Ui.loadResource(Rez.Fonts.HoursFont);
		mMinutesFont = Ui.loadResource(Rez.Fonts.MinutesFont);
		mSecondsFont = Ui.loadResource(Rez.Fonts.SecondsFont);

		// Unfortunate: because fonts can't be overridden based on locale, we have to read in current locale as manually-specified
		// string, then override font in code.
		var dateFontOverride = Ui.loadResource(Rez.Strings.DATE_FONT_OVERRIDE);
		switch (dateFontOverride) {
			case "ZHS":
				mDateFont  = Ui.loadResource(Rez.Fonts.DateFontOverrideZHS);
				break;

			case "ZHT":
				mDateFont  = Ui.loadResource(Rez.Fonts.DateFontOverrideZHT);
				break;

			default:
				mDateFont  = Ui.loadResource(Rez.Fonts.DateFont);
				break;
		}

		setLayout(Rez.Layouts.WatchFace(dc));

		cacheDrawables();

		// Cache reference to ThickThinTime, for use in low power mode. Saves nearly 5ms!
		// Slighly faster than mDrawables lookup.
		mTime = View.findDrawableById("Time");
		mTime.setFonts(mHoursFont, mMinutesFont, mSecondsFont);

		mDrawables[:Date].setFont(mDateFont);
	}

	function cacheDrawables() {
		mDrawables[:LeftGoalMeter] = View.findDrawableById("LeftGoalMeter");
		mDrawables[:LeftGoalIcon] = View.findDrawableById("LeftGoalIcon");
		mDrawables[:LeftGoalCurrent] = View.findDrawableById("LeftGoalCurrent");
		mDrawables[:LeftGoalMax] = View.findDrawableById("LeftGoalMax");

		mDrawables[:RightGoalMeter] = View.findDrawableById("RightGoalMeter");
		mDrawables[:RightGoalIcon] = View.findDrawableById("RightGoalIcon");
		mDrawables[:RightGoalCurrent] = View.findDrawableById("RightGoalCurrent");
		mDrawables[:RightGoalMax] = View.findDrawableById("RightGoalMax");

		mDrawables[:LeftFieldIcon] = View.findDrawableById("LeftFieldIcon");
		mDrawables[:LeftFieldValue] = View.findDrawableById("LeftFieldValue");

		mDrawables[:CenterFieldIcon] = View.findDrawableById("CenterFieldIcon");
		mDrawables[:CenterFieldValue] = View.findDrawableById("CenterFieldValue");

		mDrawables[:RightFieldIcon] = View.findDrawableById("RightFieldIcon");
		mDrawables[:RightFieldValue] = View.findDrawableById("RightFieldValue");

		mDrawables[:Date] = View.findDrawableById("Date");

		mDrawables[:Bluetooth] = View.findDrawableById("Bluetooth");

		// Use mTime instead.
		//mDrawables[:Time] = View.findDrawableById("Time");

		mDrawables[:MoveBar] = View.findDrawableById("MoveBar");
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() {
	}

	// Recreate background buffers for each meter, in case theme colour has changed.
	function onSettingsChanged() {
		mDrawables[:LeftGoalMeter].onSettingsChanged();
		mDrawables[:RightGoalMeter].onSettingsChanged();

		mDrawables[:MoveBar].onSettingsChanged();
	}

	// Update the view
	function onUpdate(dc) {
		System.println("onUpdate()");

		// Clear any partial update clipping.
		dc.clearClip();

		updateGoalMeters();
		updateDataFields();
		updateBluetoothIndicator();

		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);

		// Additional drawing on top of drawables.
		// TODO: Solving z-order issue forces ugly repetition (retrieval of battery value, etc.); can this be avoided?
		onPostUpdate(dc);
	}

	function onPostUpdate(dc) {

		// Find any battery meter icons, and draw fill on top. 
		if (FIELD_TYPES[App.getApp().getProperty("LeftFieldType")] == :FIELD_TYPE_BATTERY) {
			fillBatteryMeter(dc, mDrawables[:LeftFieldIcon]);
		}

		if (FIELD_TYPES[App.getApp().getProperty("CenterFieldType")] == :FIELD_TYPE_BATTERY) {
			fillBatteryMeter(dc, mDrawables[:CenterFieldIcon]);
		}

		if (FIELD_TYPES[App.getApp().getProperty("RightFieldType")] == :FIELD_TYPE_BATTERY) {
			fillBatteryMeter(dc, mDrawables[:RightFieldIcon]);
		}
	}

	function fillBatteryMeter(dc, batteryIcon) {
		// #8: battery returned as float. Use ceil() for optimistic values. Must match getDisplayInfoForFieldType().
		var batteryLevel = Math.ceil(Sys.getSystemStats().battery);
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
		if (batteryIcon.width == BATTERY_WIDTH_SMALL) {
			fillWidth = BATTERY_FILL_WIDTH_SMALL;
			fillHeight = BATTERY_FILL_HEIGHT_SMALL;
		} else {
			fillWidth = BATTERY_FILL_WIDTH;
			fillHeight = BATTERY_FILL_HEIGHT;
		}
		dc.fillRectangle(
			batteryIcon.locX - (fillWidth / 2) - 1,
			batteryIcon.locY - (fillHeight / 2) + 1,
			Math.ceil(fillWidth * (batteryLevel / 100)), 
			fillHeight);	
	}

	function updateDataFields() {
		updateDataField(
			App.getApp().getProperty("LeftFieldType"),
			mDrawables[:LeftFieldIcon],
			mDrawables[:LeftFieldValue]
		);

		updateDataField(
			App.getApp().getProperty("CenterFieldType"),
			mDrawables[:CenterFieldIcon],
			mDrawables[:CenterFieldValue]
		);

		updateDataField(
			App.getApp().getProperty("RightFieldType"),
			mDrawables[:RightFieldIcon],
			mDrawables[:RightFieldValue]
		);
	}

	// "fieldType" parameter is raw property value (it's converted to symbol below).
	function updateDataField(fieldType, iconLabel, valueLabel) {
		var value = getValueForFieldType(fieldType);
		var colour;

		// Grey out icon if no value was retrieved.
		if (value.length() == 0) {
			colour = App.getApp().getProperty("MeterBackgroundColour");
		} else {
			colour = App.getApp().getProperty("ThemeColour");
		}

		iconLabel.setText(ICON_FONT_CHARS[FIELD_TYPES[fieldType]]);
		iconLabel.setColor(colour);
		
		valueLabel.setText(value);
		valueLabel.setColor(App.getApp().getProperty("MonoLightColour"));
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
		var format;
		var unit;

		switch (FIELD_TYPES[type]) {
			case :FIELD_TYPE_HEART_RATE:
				activityInfo = ActivityMonitor.getInfo();
				if (activityInfo has :getHeartRateHistory) {
					iterator = activityInfo.getHeartRateHistory(1, /* newestFirst */ true);
					sample = iterator.next();
					if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
						value = sample.heartRate.format("%d");
					}
				}
				break;

			case :FIELD_TYPE_BATTERY:
				// #8: battery returned as float. Use ceil() for optimistic values. Must match fillBatteryMeter().
				battery = Math.ceil(Sys.getSystemStats().battery);
				value = battery.format("%d") + "%";
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

				//  Show decimal point only if distance less than 10, to save space.
				if (distance < 10) {
					format = "%.1f";
				} else {
					format = "%d";
				}

				value = distance.format(format) + unit;
				
				break;
		}

		return value;
	}

	// Set colour of bluetooth indicator, depending on phone connection status.
	function updateBluetoothIndicator() {
		var indicator = mDrawables[:Bluetooth];

		if (Sys.getDeviceSettings().phoneConnected) {
			indicator.setColor(App.getApp().getProperty("ThemeColour"));
		} else {
			indicator.setColor(App.getApp().getProperty("MeterBackgroundColour"));
		}
	}

	function updateGoalMeters() {
		updateGoalMeter(
			GOAL_TYPES[App.getApp().getProperty("LeftGoalType")],
			mDrawables[:LeftGoalMeter],
			mDrawables[:LeftGoalIcon],
			mDrawables[:LeftGoalCurrent],
			mDrawables[:LeftGoalMax]
		);

		updateGoalMeter(
			GOAL_TYPES[App.getApp().getProperty("RightGoalType")],
			mDrawables[:RightGoalMeter],
			mDrawables[:RightGoalIcon],
			mDrawables[:RightGoalCurrent],
			mDrawables[:RightGoalMax]
		);
	}

	function updateGoalMeter(goalType, meter, iconLabel, currentLabel, maxLabel) {
		var values = getValuesForGoalType(goalType);

		// Meter.
		meter.setValues(values[:current], values[:max]);

		// Icon label.
		iconLabel.setText(ICON_FONT_CHARS[goalType]);
		if (values[:isValid]) {
			iconLabel.setColor(App.getApp().getProperty("ThemeColour"));
		} else {
			iconLabel.setColor(App.getApp().getProperty("MeterBackgroundColour"));
		}		

		// Current label.
		if (values[:isValid]) {
			currentLabel.setText(values[:current].format("%d"));
		} else {
			currentLabel.setText("");
		}
		currentLabel.setColor(App.getApp().getProperty("MonoLightColour"));

		// Max/target label.
		if (values[:isValid]) {
			if (goalType == :GOAL_TYPE_BATTERY) {
				maxLabel.setText("%");
			} else {
				maxLabel.setText(values[:max].format("%d"));
			}
			
		} else {
			maxLabel.setText("");
		}
		maxLabel.setColor(App.getApp().getProperty("MonoDarkColour"));
	}

	function getValuesForGoalType(type) {
		var values = {
			:current => 0,
			:max => 1,
			:isValid => true
		};

		var info = ActivityMonitor.getInfo();

		switch(type) {
			case :GOAL_TYPE_STEPS:
				values[:current] = info.steps;
				values[:max] = info.stepGoal;
				break;

			case :GOAL_TYPE_FLOORS_CLIMBED:
				if (info has :floorsClimbed) {
					values[:current] = info.floorsClimbed;
					values[:max] = info.floorsClimbedGoal;
				} else {
					values[:isValid] = false;
				}
				
				break;

			case :GOAL_TYPE_ACTIVE_MINUTES:
				values[:current] = info.activeMinutesWeek.total;
				values[:max] = info.activeMinutesWeekGoal;
				break;

			case :GOAL_TYPE_BATTERY:
				values[:current] = Math.ceil(Sys.getSystemStats().battery);
				values[:max] = 100;
				break;
		}

		return values;
	}

	// Set clipping region to previously-displayed seconds text only.
	// Clear background, clear clipping region, then draw new seconds.
	function onPartialUpdate(dc) {
		System.println("onPartialUpdate()");
	
		mTime.drawSeconds(dc, /* isPartialUpdate */ true);
	}

	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory.
	function onHide() {
	}

	// The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep() {
		Sys.println("onExitSleep()");

		// If watch does not support per-second updates, show seconds, and make move bar original width.
		if (!PER_SECOND_UPDATES_SUPPORTED) {
			mTime.setHideSeconds(false);
			mDrawables[:MoveBar].setFullWidth(false);
		}
	}

	// Terminate any active timers and prepare for slow updates.
	function onEnterSleep() {
		Sys.println("onEnterSleep()");
		Sys.println("Partial updates supported = " + PER_SECOND_UPDATES_SUPPORTED);

		// If watch does not support per-second updates, then hide seconds, and make move bar full width.
		// onUpdate() is about to be called one final time before entering sleep.
		if (!PER_SECOND_UPDATES_SUPPORTED) {
			mTime.setHideSeconds(true);
			mDrawables[:MoveBar].setFullWidth(true);
		}
	}

}
