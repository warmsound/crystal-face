using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

const INTEGER_FORMAT = "%d";

class CrystalView extends Ui.WatchFace {
	private var mIsSleeping = false;
	private var mSettingsChangedSinceLastDraw = false; // Have settings changed since last full update?

	private var mHoursFont;
	private var mMinutesFont;
	private var mSecondsFont;

	private var mIconsFont;
	private var mNormalFont;

	private var mTime;
	private var mDataFields;

	// Cache references to drawables immediately after layout, to avoid expensive findDrawableById() calls in onUpdate();
	private var mDrawables = {};

	// N.B. Not all watches that support SDK 2.3.0 support per-second updates e.g. 735xt.
	private const PER_SECOND_UPDATES_SUPPORTED = Ui.WatchFace has :onPartialUpdate;

	private var THEMES = [
		:THEME_BLUE_DARK,
		:THEME_PINK_DARK,
		:THEME_GREEN_DARK,
		:THEME_MONO_LIGHT,
		:THEME_CORNFLOWER_BLUE_DARK,
		:THEME_LEMON_CREAM_DARK,
		:THEME_DAYGLO_ORANGE_DARK,
		:THEME_RED_DARK,
		:THEME_MONO_DARK,
		:THEME_BLUE_LIGHT,
		:THEME_GREEN_LIGHT,
		:THEME_RED_LIGHT,
		:THEME_VIVID_YELLOW_DARK,
	];

	private var COLOUR_OVERRIDES = {
		-1 => :FROM_THEME,
		-2 => :MONO_HIGHLIGHT,
		-3 => :MONO
	};

	function initialize() {
		WatchFace.initialize();

		updateThemeColours();
		updateHoursMinutesColours();		
	}

	// Load your resources here
	function onLayout(dc) {
		mHoursFont = Ui.loadResource(Rez.Fonts.HoursFont);
		mMinutesFont = Ui.loadResource(Rez.Fonts.MinutesFont);
		mSecondsFont = Ui.loadResource(Rez.Fonts.SecondsFont);

		mIconsFont = Ui.loadResource(Rez.Fonts.IconsFont);

		setLayout(Rez.Layouts.WatchFace(dc));

		cacheDrawables();

		// Cache reference to ThickThinTime, for use in low power mode. Saves nearly 5ms!
		// Slighly faster than mDrawables lookup.
		mTime = View.findDrawableById("Time");
		mTime.setFonts(mHoursFont, mMinutesFont, mSecondsFont);

		mDrawables[:Indicators].setFont(mIconsFont);

		mDataFields = View.findDrawableById("DataFields");		

		setHideSeconds(App.getApp().getProperty("HideSeconds"));

		updateNormalFont(); // Requires mIconsFont, mDrawables, mDataFields.
	}

	function cacheDrawables() {
		mDrawables[:LeftGoalMeter] = View.findDrawableById("LeftGoalMeter");
		mDrawables[:LeftGoalIcon] = View.findDrawableById("LeftGoalIcon");

		mDrawables[:RightGoalMeter] = View.findDrawableById("RightGoalMeter");
		mDrawables[:RightGoalIcon] = View.findDrawableById("RightGoalIcon");

		mDrawables[:DataArea] = View.findDrawableById("DataArea");

		mDrawables[:Date] = View.findDrawableById("Date");

		mDrawables[:Indicators] = View.findDrawableById("Indicators");

		// Use mTime instead.
		//mDrawables[:Time] = View.findDrawableById("Time");

		// Use mDataFields instead.
		//mDrawables[:DataFields] = View.findDrawableById("DataFields");

		mDrawables[:MoveBar] = View.findDrawableById("MoveBar");
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() {
	}

	// Set flag to respond to settings change on next full draw (onUpdate()), as we may be in 1Hz (lower power) mode, and cannot
	// update the full screen immediately. This is true on real hardware, but not in the simulator, which calls onUpdate()
	// immediately. Ui.requestUpdate() does not appear to work in 1Hz mode on real hardware.
	function onSettingsChanged() {
		mSettingsChangedSinceLastDraw = true;

		updateNormalFont();

		// Themes: explicitly set *Colour properties that have no corresponding (user-facing) setting.
		updateThemeColours();

		// Update hours/minutes colours after theme colours have been set.
		updateHoursMinutesColours();
	}

	// Select normal font, based on whether time zone feature is being used.
	// Saves memory when cities are not in use.
	// Update drawables that use normal font.
	function updateNormalFont() {

		var timeZone1City = App.getApp().getProperty("TimeZone1City");

		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((timeZone1City != null) && (timeZone1City.length() > 0)) {
			mNormalFont = Ui.loadResource(Rez.Fonts.NormalFontCities);
		} else {
			mNormalFont = Ui.loadResource(Rez.Fonts.NormalFont);
		}

		mDataFields.setFonts(mIconsFont, mNormalFont);
		mDrawables[:DataArea].setFont(mNormalFont);
	}

	function updateThemeColours() {
		var theme = THEMES[App.getApp().getProperty("Theme")];

		// Theme-specific colours.
		var themeColour;
		switch (theme) {
			case :THEME_BLUE_DARK:
				themeColour = Graphics.COLOR_BLUE;
				break;
			
			case :THEME_PINK_DARK:
				themeColour = Graphics.COLOR_PINK;
				break;

			case :THEME_GREEN_DARK:
				themeColour = Graphics.COLOR_GREEN;
				break;

			case :THEME_MONO_LIGHT:
				themeColour = Graphics.COLOR_DK_GRAY;
				break;

			case :THEME_CORNFLOWER_BLUE_DARK:
				themeColour = 0x55AAFF;
				break;

			case :THEME_LEMON_CREAM_DARK:
				themeColour = 0xFFFFAA;
				break;

			case :THEME_VIVID_YELLOW_DARK:
				themeColour = 0xFFFF00;
				break;

			case :THEME_DAYGLO_ORANGE_DARK:
				themeColour = Graphics.COLOR_ORANGE;
				break;

			case :THEME_RED_DARK:
				themeColour = Graphics.COLOR_RED;
				break;

			case :THEME_MONO_DARK:
				themeColour = Graphics.COLOR_WHITE;
				break;

			case :THEME_BLUE_LIGHT:
				themeColour = Graphics.COLOR_DK_BLUE;
				break;

			case :THEME_GREEN_LIGHT:
				themeColour = Graphics.COLOR_DK_GREEN;
				break;

			case :THEME_RED_LIGHT:
				themeColour = Graphics.COLOR_DK_RED;
				break;
		}
		App.getApp().setProperty("ThemeColour", themeColour); 

		// Light/dark-specific colours.
		switch (theme) {
			case :THEME_BLUE_DARK:
			case :THEME_PINK_DARK:
			case :THEME_GREEN_DARK:
			case :THEME_CORNFLOWER_BLUE_DARK:
			case :THEME_LEMON_CREAM_DARK:
			case :THEME_VIVID_YELLOW_DARK:
			case :THEME_DAYGLO_ORANGE_DARK:
			case :THEME_RED_DARK:
			case :THEME_MONO_DARK:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_WHITE);
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_LT_GRAY);

				App.getApp().setProperty("MeterBackgroundColour", Graphics.COLOR_DK_GRAY);
				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_BLACK);
				break;

			case :THEME_MONO_LIGHT:
			case :THEME_BLUE_LIGHT:
			case :THEME_GREEN_LIGHT:
			case :THEME_RED_LIGHT:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_BLACK);
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_DK_GRAY);
				
				App.getApp().setProperty("MeterBackgroundColour", Graphics.COLOR_LT_GRAY);
				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_WHITE);
				break;
		}
	}

	function updateHoursMinutesColours() {

		// Hours colour.
		var hoursColour;
		switch (COLOUR_OVERRIDES[App.getApp().getProperty("HoursColourOverride")]) {
			case :FROM_THEME:
				hoursColour = App.getApp().getProperty("ThemeColour");
				break;

			case :MONO_HIGHLIGHT:
				hoursColour = App.getApp().getProperty("MonoLightColour");
				break;

			case :MONO:
				hoursColour = App.getApp().getProperty("MonoDarkColour");
				break;
		}
		App.getApp().setProperty("HoursColour", hoursColour);

		// Minutes colour.
		var minutesColour;
		switch (COLOUR_OVERRIDES[App.getApp().getProperty("MinutesColourOverride")]) {
			case :FROM_THEME:
				minutesColour = App.getApp().getProperty("ThemeColour");
				break;

			case :MONO_HIGHLIGHT:
				minutesColour = App.getApp().getProperty("MonoLightColour");
				break;

			case :MONO:
				minutesColour = App.getApp().getProperty("MonoDarkColour");
				break;
		}
		App.getApp().setProperty("MinutesColour", minutesColour);
	}

	function onSettingsChangedSinceLastDraw() {

		// Recreate background buffers for each meter, in case theme colour has changed.
		mDrawables[:LeftGoalMeter].onSettingsChanged();
		mDrawables[:RightGoalMeter].onSettingsChanged();

		mDrawables[:MoveBar].onSettingsChanged();

		mDataFields.onSettingsChanged();

		// If watch does not support per-second updates, and watch is sleeping, do not show seconds immediately, as they will not 
		// update. Instead, wait for next onExitSleep(). 
		if (PER_SECOND_UPDATES_SUPPORTED || !mIsSleeping) { 
			setHideSeconds(App.getApp().getProperty("HideSeconds")); 
		} 

		mSettingsChangedSinceLastDraw = false;
	}

	// Update the view
	function onUpdate(dc) {
		//System.println("onUpdate()");

		// Respond now to any settings change since last full draw, as we can now update the full screen.
		if (mSettingsChangedSinceLastDraw) {
			onSettingsChangedSinceLastDraw();
		}

		// Clear any partial update clipping.
		if (dc has :clearClip) {
			dc.clearClip();
		}

		updateGoalMeters();

		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);
	}

	function updateGoalMeters() {
		var leftValues = updateGoalMeter(
			getGoalType(App.getApp().getProperty("LeftGoalType")),
			mDrawables[:LeftGoalMeter],
			mDrawables[:LeftGoalIcon]
		);

		var rightValues = updateGoalMeter(
			getGoalType(App.getApp().getProperty("RightGoalType")),
			mDrawables[:RightGoalMeter],
			mDrawables[:RightGoalIcon]
		);

		mDrawables[:DataArea].setGoalValues(leftValues, rightValues);
	}

	function updateGoalMeter(goalType, meter, iconLabel) {
		var values = getValuesForGoalType(goalType);

		// Meter.
		meter.setValues(values[:current], values[:max]);

		// Icon label.
		iconLabel.setFont(mIconsFont);
		iconLabel.setText(getIconFontChar(goalType));
		if (values[:isValid]) {
			iconLabel.setColor(App.getApp().getProperty("ThemeColour"));
		} else {
			iconLabel.setColor(App.getApp().getProperty("MeterBackgroundColour"));
		}

		return values;
	}

	// Replace dictionary with function to save memory.
	function getGoalType(goalProperty) {
		switch (goalProperty) {
			case App.GOAL_TYPE_STEPS:
				return :GOAL_TYPE_STEPS;
			case App.GOAL_TYPE_FLOORS_CLIMBED:
				return :GOAL_TYPE_FLOORS_CLIMBED;
			case App.GOAL_TYPE_ACTIVE_MINUTES:
				return :GOAL_TYPE_ACTIVE_MINUTES;
			case -1:
				return :GOAL_TYPE_BATTERY;
			case -2:
				return :GOAL_TYPE_CALORIES;
		}
	}

	// Replace dictionary with function to save memory.
	function getIconFontChar(fieldType) {
		switch (fieldType) {
			case :GOAL_TYPE_STEPS:
				return "0";
			case :GOAL_TYPE_FLOORS_CLIMBED:
				return "1";
			case :GOAL_TYPE_ACTIVE_MINUTES:
				return "2";
			case :FIELD_TYPE_HEART_RATE:
			case :FIELD_TYPE_HR_LIVE_5S:
				return "3";
			case :FIELD_TYPE_BATTERY:
			case :FIELD_TYPE_BATTERY_HIDE_PERCENT:
				return "4";
			case :FIELD_TYPE_NOTIFICATIONS:
			case :INDICATOR_TYPE_NOTIFICATIONS:
				return "5";
			case :FIELD_TYPE_CALORIES:
			case :GOAL_TYPE_CALORIES:
				return "6"; // Use calories icon for both field and goal.
			case :FIELD_TYPE_DISTANCE:
				return "7";
			case :INDICATOR_TYPE_BLUETOOTH:
				return "8";
			case :GOAL_TYPE_BATTERY:
				return "9";
			case :FIELD_TYPE_ALARMS:
			case :INDICATOR_TYPE_ALARMS:
				return ":";
			case :FIELD_TYPE_ALTITUDE:
				return ";";
			case :FIELD_TYPE_TEMPERATURE:
				return "<";
			// case :LIVE_HR_SPOT:
			// 	return "=";
		}
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
				if (info has :activeMinutesWeek) {
					values[:current] = info.activeMinutesWeek.total;
					values[:max] = info.activeMinutesWeekGoal;
				} else {
					values[:isValid] = false;
				}
				break;

			case :GOAL_TYPE_BATTERY:
				// #8: floor() battery to be consistent.
				values[:current] = Math.floor(Sys.getSystemStats().battery);
				values[:max] = 100;
				break;

			case :GOAL_TYPE_CALORIES:
				values[:current] = info.calories;
				values[:max] = App.getApp().getProperty("CaloriesGoal");
				break;
		}

		// #16: If user has set goal to zero, or negative (in simulator), show as invalid. Set max to 1 to avoid divide-by-zero
		// crash in GoalMeter.getSegmentScale().
		if (values[:max] < 1) {
			values[:max] = 1;
			values[:isValid] = false;
		}

		return values;
	}

	// Set clipping region to previously-displayed seconds text only.
	// Clear background, clear clipping region, then draw new seconds.
	function onPartialUpdate(dc) {
		//Sys.println("onPartialUpdate()");
	
		mDataFields.update(dc, /* isPartialUpdate */ true);
		mTime.drawSeconds(dc, /* isPartialUpdate */ true);
	}

	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory.
	function onHide() {
	}

	// The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep() {
		mIsSleeping = false;

		//Sys.println("onExitSleep()");

		// If watch does not support per-second updates, AND HideSeconds property is false,
		// show seconds, and make move bar original width.
		if (!PER_SECOND_UPDATES_SUPPORTED && !App.getApp().getProperty("HideSeconds")) {
			setHideSeconds(false);
		}

		// Rather than checking the need for background requests on a timer, or on the hour, easier just to check when exiting
		// sleep.
		App.getApp().checkBackgroundRequests();
	}

	// Terminate any active timers and prepare for slow updates.
	function onEnterSleep() {
		mIsSleeping = true;

		//Sys.println("onEnterSleep()");
		//Sys.println("Partial updates supported = " + PER_SECOND_UPDATES_SUPPORTED);

		// If watch does not support per-second updates, then hide seconds, and make move bar full width.
		// onUpdate() is about to be called one final time before entering sleep.
		// If HideSeconds property is true, do not wastefully hide seconds again (they should already be hidden).
		if (!PER_SECOND_UPDATES_SUPPORTED && !App.getApp().getProperty("HideSeconds")) {
			setHideSeconds(true);
		}
	}

	function isSleeping() {
		return mIsSleeping;
	}

	function setHideSeconds(hideSeconds) {
		mTime.setHideSeconds(hideSeconds);
		mDrawables[:MoveBar].setFullWidth(hideSeconds);
	}

	private const BATTERY_LINE_WIDTH = 2;
	private const BATTERY_HEAD_HEIGHT = 4;
	private const BATTERY_MARGIN = 1;

	private const BATTERY_LEVEL_LOW = 20;
	private const BATTERY_LEVEL_CRITICAL = 10;

	// x, y are co-ordinates of centre point.
	// width and height are outer dimensions of battery "body".
	function drawBatteryMeter(dc, x, y, width, height) {
		var themeColour = App.getApp().getProperty("ThemeColour");
		dc.setColor(themeColour, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(BATTERY_LINE_WIDTH);

		// Body.
		// drawRoundedRectangle's x and y are top-left corner of middle of stroke.
		// Bottom-right corner of middle of stroke will be (x + width - 1, y + height - 1).
		dc.drawRoundedRectangle(
			x - (width / 2) + (BATTERY_LINE_WIDTH / 2),
			y - (height / 2) + (BATTERY_LINE_WIDTH / 2),
			width - BATTERY_LINE_WIDTH + 1,
			height - BATTERY_LINE_WIDTH + 1,
			/* BATTERY_CORNER_RADIUS */ 2);

		// Head.
		// fillRectangle() works as expected.
		dc.fillRectangle(
			x + (width / 2) + BATTERY_MARGIN,
			y - (BATTERY_HEAD_HEIGHT / 2),
			/* BATTERY_HEAD_WIDTH */ 2,
			BATTERY_HEAD_HEIGHT);

		// Fill.
		// #8: battery returned as float. Use floor() to match native. Must match getValueForFieldType().
		var batteryLevel = Math.floor(Sys.getSystemStats().battery);		

		// Fill colour based on battery level.
		var fillColour;
		if (batteryLevel <= BATTERY_LEVEL_CRITICAL) {
			fillColour = Graphics.COLOR_RED;
		} else if (batteryLevel <= BATTERY_LEVEL_LOW) {
			fillColour = Graphics.COLOR_YELLOW;
		} else {
			fillColour = themeColour;
		}

		dc.setColor(fillColour, Graphics.COLOR_TRANSPARENT);

		var fillWidth = width - (2 * (BATTERY_LINE_WIDTH + BATTERY_MARGIN));
		dc.fillRectangle(
			x - (width / 2) + BATTERY_LINE_WIDTH + BATTERY_MARGIN,
			y - (height / 2) + BATTERY_LINE_WIDTH + BATTERY_MARGIN,
			Math.ceil(fillWidth * (batteryLevel / 100)), 
			height - (2 * (BATTERY_LINE_WIDTH + BATTERY_MARGIN)));
	}
}
