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
		0 => :HEART_RATE,
		1 => :BATTERY,
		2 => :MESSAGES,
		3 => :CALORIES,
		4 => :DISTANCE
	};

	private var ICON_FONT_CHARS = {
		:GOAL_TYPE_STEPS => "0",
		:GOAL_TYPE_FLOORS_CLIMBED => "1",
		:GOAL_TYPE_ACTIVE_MINUTES => "2",
		:FIELD_TYPE_HEART_RATE => "3",
		:FIELD_TYPE_BATTERY => "4",
		:FIELD_TYPE_MESSAGES => "5",
		:FIELD_TYPE_CALORIES => "6",
		:FIELD_TYPE_DISTANCE => "7",
		:INDICATOR_BLUETOOTH => "8"
	};

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

	// Update the view
	function onUpdate(dc) {
		System.println("onUpdate()");

		updateGoalMeters();
		updateDataFields();
		updateBluetoothIndicator();

		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);
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

	function updateDataField(fieldType, iconLabel, valueLabel) {
		var info = getDisplayInfoForFieldType(fieldType);

		iconLabel.setColor(info[:colour]);
		valueLabel.setText(info[:value]);
	}

	// "type" parameter is raw property value (it's converted to symbol below).
	function getDisplayInfoForFieldType(type) {
		var info = {
			:colour => App.getApp().getProperty("ThemeColour"),
			:value => ""
		};

		switch (FIELD_TYPES[type]) {
			case :HEART_RATE:
				break;

			case :BATTERY:
				var battery = Sys.getSystemStats().battery;
				info[:value] = battery.format("%d") + "%";
				break;

			case :MESSAGES:
				break;

			case :CALORIES:
				break;

			case :DISTANCE:
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
