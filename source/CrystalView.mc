using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

class CrystalView extends Ui.WatchFace {
	
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
		:INDICATOR_BLUETOOTH => "8"
	};

	const BATTERY_FILL_WIDTH = 18;
	const BATTERY_FILL_HEIGHT = 6;
	const BATTERY_LEVEL_LOW = 20;
	const BATTERY_LEVEL_CRITICAL = 10;

	const CM_PER_KM = 100000;
	const MI_PER_KM = 0.621371;

	function initialize() {
		WatchFace.initialize();
	}

	// Load your resources here
	function onLayout(dc) {
		setLayout(Rez.Layouts.WatchFace(dc));
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() {
	}

	// Recreate background buffers for each meter, in case theme colour has changed.
	function onSettingsChanged() {
		View.findDrawableById("LeftGoalMeter").onSettingsChanged();
		View.findDrawableById("RightGoalMeter").onSettingsChanged();
	}

	// Update the view
	function onUpdate(dc) {
		System.println("onUpdate()");

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
			fillBatteryMeter(dc, View.findDrawableById("LeftFieldIcon"));
		}

		if (FIELD_TYPES[App.getApp().getProperty("CenterFieldType")] == :FIELD_TYPE_BATTERY) {
			fillBatteryMeter(dc, View.findDrawableById("CenterFieldIcon"));
		}

		if (FIELD_TYPES[App.getApp().getProperty("RightFieldType")] == :FIELD_TYPE_BATTERY) {
			fillBatteryMeter(dc, View.findDrawableById("RightFieldIcon"));
		}
	}

	function fillBatteryMeter(dc, batteryIcon) {
		var batteryLevel = Sys.getSystemStats().battery;
		var colour;

		if (batteryLevel <= BATTERY_LEVEL_CRITICAL) {
			colour = Graphics.COLOR_RED;
		} else if (batteryLevel <= BATTERY_LEVEL_LOW) {
			colour = Graphics.COLOR_YELLOW;
		} else {
			colour = App.getApp().getProperty("ThemeColour");
		}

		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		dc.fillRectangle(
			batteryIcon.locX - (BATTERY_FILL_WIDTH / 2) - 1,
			batteryIcon.locY - (BATTERY_FILL_HEIGHT / 2) + 1,
			Math.ceil(BATTERY_FILL_WIDTH * (batteryLevel / 100)), 
			BATTERY_FILL_HEIGHT);
	}

	function updateDataFields() {
		updateDataField(
			App.getApp().getProperty("LeftFieldType"),
			View.findDrawableById("LeftFieldIcon"),
			View.findDrawableById("LeftFieldValue")
		);

		updateDataField(
			App.getApp().getProperty("CenterFieldType"),
			View.findDrawableById("CenterFieldIcon"),
			View.findDrawableById("CenterFieldValue")
		);

		updateDataField(
			App.getApp().getProperty("RightFieldType"),
			View.findDrawableById("RightFieldIcon"),
			View.findDrawableById("RightFieldValue")
		);
	}

	// "fieldType" parameter is raw property value (it's converted to symbol below).
	function updateDataField(fieldType, iconLabel, valueLabel) {
		var info = getDisplayInfoForFieldType(fieldType);

		iconLabel.setText(ICON_FONT_CHARS[FIELD_TYPES[fieldType]]);
		iconLabel.setColor(info[:colour]);
		
		valueLabel.setText(info[:value]);
	}

	// "type" parameter is raw property value (it's converted to symbol below).
	function getDisplayInfoForFieldType(type) {
		var info = {
			:colour => App.getApp().getProperty("ThemeColour"),
			:value => ""
		};

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
				iterator = activityInfo.getHeartRateHistory(1, /* newestFirst */ true);
				sample = iterator.next();
				if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
					info[:value] = sample.heartRate.format("%d");

				// If no HR history available, grey out icon and do not show text.
				} else {
					info[:colour] = App.getApp().getProperty("MeterBackgroundColour");
				}
				break;

			case :FIELD_TYPE_BATTERY:
				battery = Sys.getSystemStats().battery;
				info[:value] = battery.format("%d") + "%";
				break;

			case :FIELD_TYPE_NOTIFICATIONS:
				settings = Sys.getDeviceSettings();
				
				if (settings.notificationCount > 0) {
					info[:value] = settings.notificationCount.format("%d");

				// If no notifications, grey out icon and do not show text.
				} else {
					info[:colour] = App.getApp().getProperty("MeterBackgroundColour");
				}
				break;

			case :FIELD_TYPE_CALORIES:
				activityInfo = ActivityMonitor.getInfo();
				info[:value] = activityInfo.calories.format("%d");
				break;

			case :FIELD_TYPE_DISTANCE:
				settings = Sys.getDeviceSettings();
				activityInfo = ActivityMonitor.getInfo();
				distance = activityInfo.distance / CM_PER_KM;

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

				info[:value] = distance.format(format) + unit;
				
				break;
		}

		return info;
	}

	// Set colour of bluetooth indicator, depending on phone connection status.
	function updateBluetoothIndicator() {
		var indicator = View.findDrawableById("Bluetooth");

		if (Sys.getDeviceSettings().phoneConnected) {
			indicator.setColor(App.getApp().getProperty("ThemeColour"));
		} else {
			indicator.setColor(App.getApp().getProperty("MeterBackgroundColour"));
		}
	}

	function updateGoalMeters() {
		var themeColour = App.getApp().getProperty("ThemeColour");
		var info = ActivityMonitor.getInfo();

		var leftGoalType = GOAL_TYPES[App.getApp().getProperty("LeftGoalType")];
		var leftGoalValues = getValuesForGoalType(info, leftGoalType);

		var leftGoalIcon = View.findDrawableById("LeftGoalIcon");
		leftGoalIcon.setText(ICON_FONT_CHARS[leftGoalType]);
		leftGoalIcon.setColor(themeColour);

		View.findDrawableById("LeftGoalMeter").setValues(leftGoalValues[:current], leftGoalValues[:max]);
		View.findDrawableById("LeftGoalCurrent").setText(leftGoalValues[:current].format("%d"));
		View.findDrawableById("LeftGoalMax").setText(leftGoalValues[:max].format("%d"));

		var rightGoalType = GOAL_TYPES[App.getApp().getProperty("RightGoalType")];
		var rightGoalValues = getValuesForGoalType(info, rightGoalType);

		var rightGoalIcon = View.findDrawableById("RightGoalIcon");
		rightGoalIcon.setText(ICON_FONT_CHARS[rightGoalType]);
		rightGoalIcon.setColor(themeColour);

		View.findDrawableById("RightGoalMeter").setValues(rightGoalValues[:current], rightGoalValues[:max]);
		View.findDrawableById("RightGoalCurrent").setText(rightGoalValues[:current].format("%d"));
		View.findDrawableById("RightGoalMax").setText(rightGoalValues[:max].format("%d"));
	}

	function getValuesForGoalType(info, type) {
		var current;
		var max;

		switch(type) {
			case :GOAL_TYPE_STEPS:
				current = info.steps;
				max = info.stepGoal;
				break;

			case :GOAL_TYPE_FLOORS_CLIMBED:
				current = info.floorsClimbed;
				max = info.floorsClimbedGoal;
				break;

			case :GOAL_TYPE_ACTIVE_MINUTES:
				current = info.activeMinutesWeek.total;
				max = info.activeMinutesWeekGoal;
				break;
		}

		return { :current => current, :max => max };
	}

	// Set clipping region to previously-displayed seconds text only.
	// Clear background, clear clipping region, then draw new seconds.
	function onPartialUpdate(dc) {
		System.println("onPartialUpdate()");
	
		var time = View.findDrawableById("Time");
		time.drawSeconds(dc, /* isPartialUpdate */ true);
	}

	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory.
	function onHide() {
	}

	// The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep() {
	}

	// Terminate any active timers and prepare for slow updates.
	function onEnterSleep() {
	}

}
