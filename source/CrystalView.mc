using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

using Toybox.Time;
using Toybox.Time.Gregorian;

using Toybox.Math;

const INTEGER_FORMAT = "%d";

var gThemeColour;
var gMonoLightColour;
var gMonoDarkColour;
var gBackgroundColour;
var gMeterBackgroundColour;
var gHoursColour;
var gMinutesColour;

var gNormalFont;
var gIconsFont;

const BATTERY_LINE_WIDTH = 2;
const BATTERY_HEAD_HEIGHT = 4;
const BATTERY_MARGIN = 1;

const BATTERY_LEVEL_LOW = 20;
const BATTERY_LEVEL_CRITICAL = 10;

// x, y are co-ordinates of centre point.
// width and height are outer dimensions of battery "body".
function drawBatteryMeter(dc, x, y, width, height) {
	dc.setColor(gThemeColour, Graphics.COLOR_TRANSPARENT);
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
		fillColour = gThemeColour;
	}

	dc.setColor(fillColour, Graphics.COLOR_TRANSPARENT);

	var fillWidth = width - (2 * (BATTERY_LINE_WIDTH + BATTERY_MARGIN));
	dc.fillRectangle(
		x - (width / 2) + BATTERY_LINE_WIDTH + BATTERY_MARGIN,
		y - (height / 2) + BATTERY_LINE_WIDTH + BATTERY_MARGIN,
		Math.ceil(fillWidth * (batteryLevel / 100)), 
		height - (2 * (BATTERY_LINE_WIDTH + BATTERY_MARGIN)));
}

class CrystalView extends Ui.WatchFace {
	private var mIsSleeping = false;
	private var mSettingsChangedSinceLastDraw = false; // Have settings changed since last full update?

	private var mTime;
	var mDataFields;

	// Cache references to drawables immediately after layout, to avoid expensive findDrawableById() calls in onUpdate();
	private var mDrawables = {};

	// N.B. Not all watches that support SDK 2.3.0 support per-second updates e.g. 735xt.
	private const PER_SECOND_UPDATES_SUPPORTED = Ui.WatchFace has :onPartialUpdate;

	// private enum /* THEMES */ {
	// 	THEME_BLUE_DARK,
	// 	THEME_PINK_DARK,
	// 	THEME_GREEN_DARK,
	// 	THEME_MONO_LIGHT,
	// 	THEME_CORNFLOWER_BLUE_DARK,
	// 	THEME_LEMON_CREAM_DARK,
	// 	THEME_DAYGLO_ORANGE_DARK,
	// 	THEME_RED_DARK,
	// 	THEME_MONO_DARK,
	// 	THEME_BLUE_LIGHT,
	// 	THEME_GREEN_LIGHT,
	// 	THEME_RED_LIGHT,
	// 	THEME_VIVID_YELLOW_DARK,
	// 	THEME_DAYGLO_ORANGE_LIGHT,
	// 	THEME_CORN_YELLOW_DARK
	// }

	// private enum /* COLOUR_OVERRIDES */ {
	// 	FROM_THEME = -1,
	// 	MONO_HIGHLIGHT = -2,
	// 	MONO = -3
	// }

	function initialize() {
		WatchFace.initialize();

		updateThemeColours();
		updateHoursMinutesColours();

		//Sys.println(getSunTimes(51.748124, -0.461689, null));
	}

	// Load your resources here
	function onLayout(dc) {
		gIconsFont = Ui.loadResource(Rez.Fonts.IconsFont);

		setLayout(Rez.Layouts.WatchFace(dc));

		cacheDrawables();

		// Cache reference to ThickThinTime, for use in low power mode. Saves nearly 5ms!
		// Slighly faster than mDrawables lookup.
		mTime = View.findDrawableById("Time");

		mDataFields = View.findDrawableById("DataFields");
		App.getApp().checkPendingWebRequests(); // Depends on mDataFields.hasField().

		setHideSeconds(App.getApp().getProperty("HideSeconds"));

		updateNormalFont(); // Requires mDrawables, mDataFields.
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

		var city = App.getApp().getProperty("LocalTimeInCity");

		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((city != null) && (city.length() > 0)) {
			gNormalFont = Ui.loadResource(Rez.Fonts.NormalFontCities);
		} else {
			gNormalFont = Ui.loadResource(Rez.Fonts.NormalFont);
		}
	}

	function updateThemeColours() {
		var theme = App.getApp().getProperty("Theme");

		// Theme-specific colours.
		gThemeColour = [
			Graphics.COLOR_BLUE,     // THEME_BLUE_DARK
			Graphics.COLOR_PINK,     // THEME_PINK_DARK
			Graphics.COLOR_GREEN,    // THEME_GREEN_DARK
			Graphics.COLOR_DK_GRAY,  // THEME_MONO_LIGHT
			0x55AAFF,                // THEME_CORNFLOWER_BLUE_DARK
			0xFFFFAA,                // THEME_LEMON_CREAM_DARK
			Graphics.COLOR_ORANGE,   // THEME_DAYGLO_ORANGE_DARK
			Graphics.COLOR_RED,      // THEME_RED_DARK
			Graphics.COLOR_WHITE,    // THEME_MONO_DARK
			Graphics.COLOR_DK_BLUE,  // THEME_BLUE_LIGHT
			Graphics.COLOR_DK_GREEN, // THEME_GREEN_LIGHT
			Graphics.COLOR_DK_RED,   // THEME_RED_LIGHT
			0xFFFF00,                // THEME_VIVID_YELLOW_DARK
			Graphics.COLOR_ORANGE,   // THEME_DAYGLO_ORANGE_LIGHT
			Graphics.COLOR_YELLOW    // THEME_CORN_YELLOW_DARK
		][theme];

		// Light/dark-specific colours.
		var lightFlags = [
			false, // THEME_BLUE_DARK
			false, // THEME_PINK_DARK
			false, // THEME_GREEN_DARK
			true,  // THEME_MONO_LIGHT
			false, // THEME_CORNFLOWER_BLUE_DARK
			false, // THEME_LEMON_CREAM_DARK
			false, // THEME_DAYGLO_ORANGE_DARK
			false, // THEME_RED_DARK
			false, // THEME_MONO_DARK
			true,  // THEME_BLUE_LIGHT
			true,  // THEME_GREEN_LIGHT
			true,  // THEME_RED_LIGHT
			false, // THEME_VIVID_YELLOW_DARK
			true,  // THEME_DAYGLO_ORANGE_LIGHT
			false, // THEME_CORN_YELLOW_DARK
		];
		if (lightFlags[theme]) {
			gMonoLightColour = Graphics.COLOR_BLACK;
			gMonoDarkColour = Graphics.COLOR_DK_GRAY;
			
			gMeterBackgroundColour = Graphics.COLOR_LT_GRAY;
			gBackgroundColour = Graphics.COLOR_WHITE;
		} else {
			gMonoLightColour = Graphics.COLOR_WHITE;
			gMonoDarkColour = Graphics.COLOR_LT_GRAY;

			gMeterBackgroundColour = Graphics.COLOR_DK_GRAY;
			gBackgroundColour = Graphics.COLOR_BLACK;
		}
	}

	function updateHoursMinutesColours() {
		var overrideColours = [
			gThemeColour,     // FROM_THEME
			gMonoLightColour, // MONO_HIGHLIGHT
			gMonoDarkColour   // MONO
		];

		gHoursColour = overrideColours[App.getApp().getProperty("HoursColourOverride")];
		gMinutesColour = overrideColours[App.getApp().getProperty("MinutesColourOverride")];
	}

	function onSettingsChangedSinceLastDraw() {

		// Recreate background buffers for each meter, in case theme colour has changed.
		mDrawables[:LeftGoalMeter].onSettingsChanged();
		mDrawables[:RightGoalMeter].onSettingsChanged();

		mDrawables[:MoveBar].onSettingsChanged();

		mDataFields.onSettingsChanged();

		mDrawables[:Indicators].onSettingsChanged();

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

	// Update each goal meter separately, then also pass types and values to data area to draw goal icons.
	function updateGoalMeters() {
		var leftType = App.getApp().getProperty("LeftGoalType");
		var leftValues = getValuesForGoalType(leftType);
		mDrawables[:LeftGoalMeter].setValues(leftValues[:current], leftValues[:max]);

		var rightType = App.getApp().getProperty("RightGoalType");
		var rightValues = getValuesForGoalType(rightType);
		mDrawables[:RightGoalMeter].setValues(rightValues[:current], rightValues[:max]);

		mDrawables[:DataArea].setGoalValues(leftType, leftValues, rightType, rightValues);
	}

	function getValuesForGoalType(type) {
		var values = {
			:current => 0,
			:max => 1,
			:isValid => true
		};

		var info = ActivityMonitor.getInfo();

		switch(type) {
			case GOAL_TYPE_STEPS:
				values[:current] = info.steps;
				values[:max] = info.stepGoal;
				break;

			case GOAL_TYPE_FLOORS_CLIMBED:
				if (info has :floorsClimbed) {
					values[:current] = info.floorsClimbed;
					values[:max] = info.floorsClimbedGoal;
				} else {
					values[:isValid] = false;
				}
				
				break;

			case GOAL_TYPE_ACTIVE_MINUTES:
				if (info has :activeMinutesWeek) {
					values[:current] = info.activeMinutesWeek.total;
					values[:max] = info.activeMinutesWeekGoal;
				} else {
					values[:isValid] = false;
				}
				break;

			case GOAL_TYPE_BATTERY:
				// #8: floor() battery to be consistent.
				values[:current] = Math.floor(Sys.getSystemStats().battery);
				values[:max] = 100;
				break;

			case GOAL_TYPE_CALORIES:
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
		App.getApp().checkPendingWebRequests();
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

	/**
	* With thanks to ruiokada. Adapted, then translated to Monkey C, from:
	* https://gist.github.com/ruiokada/b28076d4911820ddcbbc
	*
	* Calculates sunrise and sunset in local time given latitude, longitude, and tz.
	*
	* Equations taken from:
	* https://en.wikipedia.org/wiki/Julian_day#Converting_Julian_or_Gregorian_calendar_date_to_Julian_Day_Number
	* https://en.wikipedia.org/wiki/Sunrise_equation#Complete_calculation_on_Earth
	*
	* @method getSunTimes
	* @param {Float} lat Latitude of location (South is negative)
	* @param {Float} lng Longitude of location (West is negative)
	* @param {Integer || null} tz Timezone hour offset. e.g. Pacific/Los Angeles is -8 (Specify null for system timezone)
	* @param {Boolean} tomorrow Calculate tomorrow's sunrise and sunset, instead of today's.
	* @return {Array} Returns array of length 2 with sunrise and sunset as floats.
	*                 Returns array with [null, -1] if the sun never rises, and [-1, null] if the sun never sets.
	*/
	function getSunTimes(lat, lng, tz, tomorrow) {

		// Use double precision where possible, as floating point errors can affect result by minutes.
		lat = lat.toDouble();
		lng = lng.toDouble();

		var now = Time.now();
		if (tomorrow) {
			now = now.add(new Time.Duration(24 * 60 * 60));
		}
		var d = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
		var rad = Math.PI / 180.0d;
		var deg = 180.0d / Math.PI;
		
		// Calculate Julian date from Gregorian.
		var a = Math.floor((14 - d.month) / 12);
		var y = d.year + 4800 - a;
		var m = d.month + (12 * a) - 3;
		var jDate = d.day
			+ Math.floor(((153 * m) + 2) / 5)
			+ (365 * y)
			+ Math.floor(y / 4)
			- Math.floor(y / 100)
			+ Math.floor(y / 400)
			- 32045;

		// Number of days since Jan 1st, 2000 12:00.
		var n = jDate - 2451545.0d + 0.0008d;
		//Sys.println("n " + n);

		// Mean solar noon.
		var jStar = n - (lng / 360.0d);
		//Sys.println("jStar " + jStar);

		// Solar mean anomaly.
		var M = 357.5291d + (0.98560028d * jStar);
		var MFloor = Math.floor(M);
		var MFrac = M - MFloor;
		M = MFloor.toLong() % 360;
		M = M + MFrac;
		//Sys.println("M " + M);

		// Equation of the centre.
		var C = 1.9148d * Math.sin(M * rad)
			+ 0.02d * Math.sin(2 * M * rad)
			+ 0.0003d * Math.sin(3 * M * rad);
		//Sys.println("C " + C);

		// Ecliptic longitude.
		var lambda = (M + C + 180 + 102.9372d);
		var lambdaFloor = Math.floor(lambda);
		var lambdaFrac = lambda - lambdaFloor;
		lambda = lambdaFloor.toLong() % 360;
		lambda = lambda + lambdaFrac;
		//Sys.println("lambda " + lambda);

		// Solar transit.
		var jTransit = 2451545.5d + jStar
			+ 0.0053d * Math.sin(M * rad)
			- 0.0069d * Math.sin(2 * lambda * rad);
		//Sys.println("jTransit " + jTransit);

		// Declination of the sun.
		var delta = Math.asin(Math.sin(lambda * rad) * Math.sin(23.44d * rad));
		//Sys.println("delta " + delta);

		// Hour angle.
		var cosOmega = (Math.sin(-0.83d * rad) - Math.sin(lat * rad) * Math.sin(delta))
			/ (Math.cos(lat * rad) * Math.cos(delta));
		//Sys.println("cosOmega " + cosOmega);

		// Sun never rises.
		if (cosOmega > 1) {
			return [null, -1];
		}
		
		// Sun never sets.
		if (cosOmega < -1) {
			return [-1, null];
		}
		
		// Calculate times from omega.
		var omega = Math.acos(cosOmega) * deg;
		var jSet = jTransit + (omega / 360.0);
		var jRise = jTransit - (omega / 360.0);
		var deltaJSet = jSet - jDate;
		var deltaJRise = jRise - jDate;

		var tzOffset;
		if (tz == null) {
			tzOffset = (Sys.getClockTime().timeZoneOffset / 3600);
		} else {
			tzOffset = tz;
		}
		
		var localRise = (deltaJRise * 24) + tzOffset;
		var localSet = (deltaJSet * 24) + tzOffset;
		return [localRise, localSet];
	}

	// Return a formatted time dictionary that respects is24Hour and HideHoursLeadingZero settings.
	// - hour: 0-23.
	// - min:  0-59.
	function getFormattedTime(hour, min) {
		var amPm = "";

		if (!Sys.getDeviceSettings().is24Hour) {

			// #6 Ensure noon is shown as PM.
			var isPm = (hour >= 12);
			if (isPm) {
				
				// But ensure noon is shown as 12, not 00.
				if (hour > 12) {
					hour = hour - 12;
				}
				amPm = "p";
			} else {
				
				// #27 Ensure midnight is shown as 12, not 00.
				if (hour == 0) {
					hour = 12;
				}
				amPm = "a";
			}
		}

		// #10 If in 12-hour mode with Hide Hours Leading Zero set, hide leading zero.
		// #69 Setting now applies to both 12- and 24-hour modes.
		if (App.getApp().getProperty("HideHoursLeadingZero")) {
			hour = hour.format(INTEGER_FORMAT);

		// Otherwise, show leading zero.
		} else {
			hour = hour.format("%02d");
		}

		return {
			:hour => hour,
			:min => min.format("%02d"),
			:amPm => amPm
		};
	}
}
