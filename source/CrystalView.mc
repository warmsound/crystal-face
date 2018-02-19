using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

class CrystalView extends Ui.WatchFace {
	private var ICON_FONT_CHARS = {
		App.GOAL_TYPE_STEPS => "0",
		App.GOAL_TYPE_FLOORS_CLIMBED => "1",
		App.GOAL_TYPE_ACTIVE_MINUTES => "2",
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

		updateBluetoothIndicator();
		updateGoalMeters();		

		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);
	}

	// Set colour of bluetooth indicator, depending on phone connection status.
	function updateBluetoothIndicator() {
		var indicator = View.findDrawableById("Bluetooth");

		if (Sys.getDeviceSettings().phoneConnected) {
			indicator.setColor(App.getApp().getProperty("ThemeColour"));
		} else {
			indicator.setColor(App.getApp().getProperty("MonoDarkColour"));
		}
	}

	function updateGoalMeters() {
		var themeColour = App.getApp().getProperty("ThemeColour");
		var info = ActivityMonitor.getInfo();

		var leftGoalType = App.getApp().getProperty("LeftGoalType");
		var leftGoalValues = getValuesForGoalType(info, leftGoalType);

		var leftGoalIcon = View.findDrawableById("LeftGoalIcon");
		leftGoalIcon.setText(ICON_FONT_CHARS[leftGoalType]);
		leftGoalIcon.setColor(themeColour);

		View.findDrawableById("LeftGoalMeter").setValues(leftGoalValues[:current], leftGoalValues[:max]);
		View.findDrawableById("LeftGoalCurrent").setText(leftGoalValues[:current].format("%d"));
		View.findDrawableById("LeftGoalMax").setText(leftGoalValues[:max].format("%d"));

		var rightGoalType = App.getApp().getProperty("RightGoalType");
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
			case App.GOAL_TYPE_STEPS:
				current = info.steps;
				max = info.stepGoal;
				break;

			case App.GOAL_TYPE_FLOORS_CLIMBED:
				current = info.floorsClimbed;
				max = info.floorsClimbedGoal;
				break;

			case App.GOAL_TYPE_ACTIVE_MINUTES:
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
