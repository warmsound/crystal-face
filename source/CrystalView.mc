using Toybox.WatchUi as Ui;
using Toybox.Background as Bg;
using Toybox.Graphics as Graphics;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Communications as Comms;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Weather;
using Toybox.Position;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Complications as Complications;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Complications;

using Toybox.Math;

const INTEGER_FORMAT = "%d";

import Toybox.Lang;
import Toybox.WatchUi;

var gThemeColour;
var gMonoLightColour;
var gMonoDarkColour;
var gBackgroundColour;
var gMeterBackgroundColour;
var gHoursColour;
var gMinutesColour;

var gNormalFont;
var gIconsFont;

var gStressLevel;
//DEBUG*/ var gStressLevelLogText;

const SCREEN_MULTIPLIER = (Sys.getDeviceSettings().screenWidth < 360) ? 1 : 2;
//const BATTERY_LINE_WIDTH = 2;
const BATTERY_HEAD_HEIGHT = 4 * SCREEN_MULTIPLIER;
const BATTERY_MARGIN = SCREEN_MULTIPLIER;

var mGarminToOWM = [ 1, 2, 3, 10, 13, 4, 11, 13, 50, 50, 10, 9, 11, 1, 9, 10, 13, 13, 13, 13, 4, 13, 3, 2, 9, 10, 10, 9, 11, 50, 4, 9, 11, 4, 13, 4, 4, 4, 4, 50, 2, 11, 11, 13, 13, 9, 13, 13, 13, 13, 13, 13, 2, 1 ];

//const BATTERY_LEVEL_LOW = 20;
//const BATTERY_LEVEL_CRITICAL = 10;

class CrystalView extends Ui.WatchFace {
	private var mIsSleeping = false;
	private var mIsBurnInProtection = false; // Is burn-in protection required and active?
	private var mBurnInProtectionChangedSinceLastDraw = false; // Did burn-in protection change since last full update?
	private var mSettingsChangedSinceLastDraw = true; // Have settings changed since last full update?
	private var mTime;
	var mDataFields;

	var mFieldTypes = new [3];
	var mGoalTypes = new [2];

	// Cache references to drawables immediately after layout, to avoid expensive findDrawableById() calls in onUpdate();
	var mDrawables = {};

	var mWeatherStationName;
	var mLocalCityName;
	var mLocalCityLat;
	var mLocalCityLon;

	private var mUseComplications;
	var mDigitStyle;
	var mShowWeatherStationName;

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

		gNormalFont = Ui.loadResource(Rez.Fonts.NormalFontCities);

		mFieldTypes[0] = {};
		mFieldTypes[1] = {};
		mFieldTypes[2] = {};

		mGoalTypes[0] = {};
		mGoalTypes[1] = {};
	}

	function burnInProtectionIsOrWasActive() {
		return mIsBurnInProtection | mBurnInProtectionChangedSinceLastDraw;
	}

	// Load your resources here
	function onLayout(dc) {
		gIconsFont = Ui.loadResource(Rez.Fonts.IconsFont);

		setLayout(Rez.Layouts.WatchFace(dc));
		cacheDrawables();
	}

	function cacheDrawables() {
		mDrawables[:LeftGoalMeter] = View.findDrawableById("LeftGoalMeter");
		mDrawables[:RightGoalMeter] = View.findDrawableById("RightGoalMeter");
		mDrawables[:DataArea] = View.findDrawableById("DataArea");
		mDrawables[:Indicators] = View.findDrawableById("Indicators");

		// Use mTime instead.
		// Cache reference to ThickThinTime, for use in low power mode. Saves nearly 5ms!
		// Slighly faster than mDrawables lookup.
		//mDrawables[:Time] = View.findDrawableById("Time");
		mTime = View.findDrawableById("Time");

		// Use mDataFields instead.
		//mDrawables[:DataFields] = View.findDrawableById("DataFields");
		mDataFields = View.findDrawableById("DataFields");

		mDrawables[:MoveBar] = View.findDrawableById("MoveBar");

		setHideSeconds($.getIntProperty("HideSeconds", 0)); // Requires mTime, mDrawables[:MoveBar];
	}

	/*
	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory. */
	function onShow() {
		/*DEBUG*/ logMessage("View showing");
	}

	// Set flag to respond to settings change on next full draw (onUpdate()), as we may be in 1Hz (lower power) mode, and cannot
	// update the full screen immediately. This is true on real hardware, but not in the simulator, which calls onUpdate()
	// immediately. Ui.requestUpdate() does not appear to work in 1Hz mode on real hardware.
	(:noComplications)
	function onSettingsChanged() {
		mSettingsChangedSinceLastDraw = true;
		//logMessage("onSettingsChanged called");

		mFieldTypes[0].put("type", $.getIntProperty("Field1Type", 0));
		mFieldTypes[1].put("type", $.getIntProperty("Field2Type", 1));
		mFieldTypes[2].put("type", $.getIntProperty("Field3Type", 2));

		mGoalTypes[0].put("type", $.getIntProperty("LeftGoalType", 0));
		mGoalTypes[1].put("type", $.getIntProperty("RightGoalType", 0));

		// Themes: explicitly set *Colour properties that have no corresponding (user-facing) setting.
		updateThemeColours();

		// Update hours/minutes colours after theme colours have been set.
		updateHoursMinutesColours();

		ReadWeather(false);

		// Get our 2nd local time if available
		var localTimeInCity = $.getStringProperty("LocalTimeInCity", "");
		var splitArray = $.to_array(localTimeInCity, ",");
		if (splitArray.size() == 3) {
			mLocalCityName = $.validateString(splitArray[0], "???");
			mLocalCityLat = $.validateFloat(splitArray[1], null);
			mLocalCityLon = $.validateFloat(splitArray[2], null);
		}
		else {
			mLocalCityName = null;
		}

		mDigitStyle = $.getIntProperty("GoalMeterDigitsStyle", 0);
		mShowWeatherStationName = $.getBoolProperty("ShowWeatherStationName", true);
	}

	(:hasComplications)
	function onSettingsChanged() {
		mSettingsChangedSinceLastDraw = true;
		//logMessage("onSettingsChanged called");

		mFieldTypes[0].put("type", $.getIntProperty("Field1Type", 0));
		mFieldTypes[1].put("type", $.getIntProperty("Field2Type", 1));
		mFieldTypes[2].put("type", $.getIntProperty("Field3Type", 2));

		mGoalTypes[0].put("type", $.getIntProperty("LeftGoalType", 0));
		mGoalTypes[1].put("type", $.getIntProperty("RightGoalType", 0));

		// Themes: explicitly set *Colour properties that have no corresponding (user-facing) setting.
		updateThemeColours();

		// Update hours/minutes colours after theme colours have been set.
		updateHoursMinutesColours();

		ReadWeather(false);

		// Get our 2nd local time if available
		var localTimeInCity = $.getStringProperty("LocalTimeInCity", "");
		var splitArray = $.to_array(localTimeInCity, ",");
		if (splitArray.size() == 3) {
			mLocalCityName = $.validateString(splitArray[0], "???");
			mLocalCityLat = $.validateFloat(splitArray[1], null);
			mLocalCityLon = $.validateFloat(splitArray[2], null);
		}
		else {
			mLocalCityName = null;
		}

		mDigitStyle = $.getIntProperty("GoalMeterDigitsStyle", 0);
		mShowWeatherStationName = $.getBoolProperty("ShowWeatherStationName", true);

		// Reread our complications if we're allowed
		mUseComplications = $.getBoolProperty("UseComplications", false);
		gTeslaComplication = $.getBoolProperty("TeslaLink", false);

		// We're not looking at the Complication sent by Tesla-Link and we have a refesh token, register for temporal events
		if (gTeslaComplication == false && $.getStringProperty("TeslaRefreshToken", "").length() > 0) {
			var lastTime = Bg.getLastTemporalEventTime();
			if (lastTime) {
				// Events scheduled for a time in the past trigger immediately.
				var nextTime = lastTime.add(new Time.Duration(5 * 60));

				/*DEBUG*/ var local = Gregorian.info(nextTime, Time.FORMAT_SHORT); var time = $.getFormattedTime(local.hour, local.min, local.sec); logMessage("Next temporal event at " + time[:hour] + ":" + time[:min] + ":" + time[:sec] + time[:amPm]);
				Bg.registerForTemporalEvent(nextTime);
			} else {
				/*DEBUG*/ logMessage("Next Temporal Events should happen NOW");
				Bg.registerForTemporalEvent(Time.now());
			}
		}
		else {
			Bg.deleteTemporalEvent();
		}

		// Reread our complications if we're allowed
		if (Toybox has :Complications) {
			// First we drop all our subscriptions before building a new list
			Complications.unsubscribeFromAllUpdates();
			// We listen for complications if we're allowed
			Complications.registerComplicationChangeCallback($.getBoolProperty("UseComplications", false) ? self.method(:onComplicationUpdated) : null);
		}
	}

	// Read the weather from the Garmin API and store it into the same format OpenWeatherMap expects to see
	function ReadWeather(fromComplication) {
		var weather;
		var result;
		if (fromComplication) {
		}
		else if (Toybox has :Weather && Toybox.Weather has :getCurrentConditions) {
			weather = Weather.getCurrentConditions();
			if (weather != null) {
				var temperature = $.validateNumber(weather.temperature, null); // In Celcius
				if (temperature == null) {
					temperature = "NaN";
				}
				else {
					if (Sys.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
						temperature = (temperature * (9.0 / 5)) + 32; // Convert to Farenheit: ensure floating point division.
					}

					temperature = temperature.format(INTEGER_FORMAT) + "°";
				}
		
				var humidity = $.validateNumber(weather.relativeHumidity, null);
				if (humidity == null) {
					humidity = "NaN";
				}
				else {
					humidity = humidity.format(INTEGER_FORMAT) + "%";
				}

				mWeatherStationName = $.validateString(weather.observationLocationName, null);

				var icon = "01";
				var day = "d";
				var myLocation = weather.observationLocationPosition;
				var now = Time.now();
				if (myLocation != null) {
					if (Toybox.Weather has :getSunrise) {
						var sunrise = Weather.getSunrise(myLocation, now);
						var sunset = Weather.getSunset(myLocation, now);

						if (sunrise != null and sunset != null) {
							var sinceSunrise = sunrise.compare(now);
							var sinceSunset = now.compare(sunset);
							if (sinceSunrise >= 0 || sinceSunset >= 0) {
								day = "n";
							}
						}
					}
					else {
						//logMessage("Sucks, We DON'T have sunrise and sunset routines, do it the old way then");
						var myLocationArray = myLocation.toDegrees();
						now = Gregorian.info(now, Time.FORMAT_SHORT);

						// Convert to same format as sunTimes, for easier comparison. Add a minute, so that e.g. if sun rises at
						// 07:38:17, then 07:38 is already consided daytime (seconds not shown to user).
						now = now.hour + ((now.min + 1) / 60.0);
						//logMessage(now);

						// Get today's sunrise/sunset times in current time zone.
						var sunTimes = getSunTimes(myLocationArray[0], myLocationArray[1], null, /* tomorrow */ false);
						//logMessage(sunTimes);
						//logMessage("now=" + now); 
						//logMessage("sunTimes=" + sunTimes); 
						// If sunrise/sunset happens today.
						var sunriseSunsetToday = ((sunTimes[0] != null) && (sunTimes[1] != null));
						if (sunriseSunsetToday) {
							if (now < sunTimes[0] || now > sunTimes[1]) {
								day = "n";
							}
						}
					}
				}

				var condition = $.validateNumber(weather.condition, null);
				if (condition != null && condition < 53) {
					icon = (mGarminToOWM[condition]).format("%02d") + day;
					//logMessage("icon=" + icon); 
				}
				else {
					/*DEBUG*/ logMessage("Icon index " + condition + " is invalid");
				}
				result = { "cod" => 200, "temp" => temperature, "humidity" => humidity, "icon" => icon };
				/*DEBUG*/ logMessage("Weather at " + mWeatherStationName + " is " + result);
			}
			else {
				result = { "cod" => 404 };
				/*DEBUG*/ logMessage("No weather data, returning cod = 404");
			}
		}
		else {
			result = { "cod" => 400 };
			/*DEBUG*/ logMessage("No weather data, returning cod = 400");
		}
		Storage.setValue("WeatherInfo", result);
		Storage.setValue("NewWeatherInfo", true);
	}	

	function updateThemeColours() {

		// #182 Protect against null or unexpected type e.g. String.
		var theme = $.getIntProperty("Theme", 0);
		var lightFlag;
		var themeOverride = $.getStringProperty("ThemeOverride","");

		gThemeColour = null; // Will still be null if our override is invalid
		if (themeOverride.equals("") == false) {
			try {
				gThemeColour = themeOverride.toNumberWithBase(16);
			}
			catch (e) {
			}
			lightFlag = $.getBoolProperty("ThemeLightOverride", false);
		}

		if (gThemeColour == null) {
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

			lightFlag = lightFlags[theme];
		}

		// #124: fr45 cannot show grey. SG Fr45 not supported
		//var isFr45 = (Sys.getDeviceSettings().screenWidth == 208);

		if (lightFlag) {
			gMonoLightColour = Graphics.COLOR_BLACK;
			gMonoDarkColour = /*isFr45 ? Graphics.COLOR_BLACK : */ Graphics.COLOR_DK_GRAY;			
			
			gMeterBackgroundColour = /*isFr45 ? Graphics.COLOR_BLACK : */ Graphics.COLOR_LT_GRAY;
			gBackgroundColour = Graphics.COLOR_WHITE;
		} else {
			gMonoLightColour = Graphics.COLOR_WHITE;
			gMonoDarkColour = /*isFr45 ? Graphics.COLOR_WHITE : */ Graphics.COLOR_LT_GRAY;

			gMeterBackgroundColour = /*isFr45 ? Graphics.COLOR_WHITE : */ Graphics.COLOR_DK_GRAY;
			gBackgroundColour = Graphics.COLOR_BLACK;
		}
	}

	function updateHoursMinutesColours() {
		var overrideColours = [
			gThemeColour,     // FROM_THEME
			gMonoLightColour, // MONO_HIGHLIGHT
			gMonoDarkColour   // MONO
		];

		// #182 Protect against null or unexpected type e.g. String.
		// #182 Protect against invalid integer values (still crashing with getIntProperty()).
		var hco = $.getIntProperty("HoursColourOverride", 0);
		gHoursColour = overrideColours[(hco < 0 || hco > 2) ? 0 : hco];

		var mco = $.getIntProperty("MinutesColourOverride", 0);
		gMinutesColour = overrideColours[(mco < 0 || mco > 2) ? 0 : mco];
	}

	function onSettingsChangedSinceLastDraw() {
		if (!mIsBurnInProtection) {

			// Recreate background buffers for each meter, in case theme colour has changed.	
			mDrawables[:LeftGoalMeter].onSettingsChanged(0);
			mDrawables[:RightGoalMeter].onSettingsChanged(1);

			mDrawables[:MoveBar].onSettingsChanged();	

			mDataFields.onSettingsChanged();	

			mDrawables[:Indicators].onSettingsChanged();
		}

		// If watch does not support per-second updates, and watch is sleeping, do not show seconds immediately, as they will not 
		// update. Instead, wait for next onExitSleep(). 
		if (PER_SECOND_UPDATES_SUPPORTED || !mIsSleeping) { 
			setHideSeconds($.getIntProperty("HideSeconds", 0)); 
		} 

		mSettingsChangedSinceLastDraw = false;
	}

	// Update the view
	function onUpdate(dc) {
		//Sys.println("onUpdate()");
        //DEBUG*/ var myStats = Sys.getSystemStats(); logMessage("Total memory: " + myStats.totalMemory + " Used memory: " + myStats.usedMemory + " Free memory: " + myStats.freeMemory);

		// If burn-in protection has changed, set layout appropriate to new burn-in protection state.
		// If turning on burn-in protection, free memory for regular watch face drawables by clearing references. This means that
		// any use of mDrawables cache must only occur when burn in protection is NOT active.
		// If turning off burn-in protection, recache regular watch face drawables.
		if (mBurnInProtectionChangedSinceLastDraw) {
			setLayout(mIsBurnInProtection ? Rez.Layouts.AlwaysOn(dc) : Rez.Layouts.WatchFace(dc));
			cacheDrawables();
			mBurnInProtectionChangedSinceLastDraw = false;
		}

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
		if (mIsBurnInProtection) {
			return;
		}

		var leftType = $.getIntProperty("LeftGoalType", 0);
		var leftValues = getValuesForGoalType(0, leftType);
		mDrawables[:LeftGoalMeter].setValues(leftValues[:current], leftValues[:max], /* isOff */ leftType == GOAL_TYPE_OFF);

		var rightType = $.getIntProperty("RightGoalType", 1);
		var rightValues = getValuesForGoalType(1, rightType);
		mDrawables[:RightGoalMeter].setValues(rightValues[:current], rightValues[:max], /* isOff */ rightType == GOAL_TYPE_OFF);

		mDrawables[:DataArea].setGoalValues(leftType, leftValues, rightType, rightValues);
	}

	function getValuesForGoalType(index, type) {
		var values = {
			:current => 0,
			:max => 1,
			:isValid => true,
			:staled => false
		};

		var info = ActivityMonitor.getInfo();

		switch(type) {
			case GOAL_TYPE_STEPS:
				values[:isValid] = false;
				if (Toybox has :Complications && mUseComplications) {
					var tmpValue = mGoalTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						// For some stupid reason, above 10K, it becomes a float and divided by 1000, so 15,500 becomes 15.500. WTF?
						if (tmpValue instanceof Lang.Float) {
							tmpValue = tmpValue * 1000;
						}
						values[:current] = tmpValue.toNumber();
						values[:isValid] = true;
					}
				}
				if (values[:isValid] == false) { // ignore steps (but get the max value) if we have Complication
					values[:current] = info.steps;
				}
				values[:max] = info.stepGoal;
				values[:isValid] = true;
				break;

			case GOAL_TYPE_FLOORS_CLIMBED:
				values[:isValid] = false;
				if (Toybox has :Complications && mUseComplications) {
					var tmpValue = mGoalTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						values[:current] = tmpValue.toNumber();
						values[:isValid] = true;
					}
				}
				if (info has :floorsClimbed) {
					if (values[:isValid] == false) { // ignore floor climbs (but get the max value) if we have Complication
						values[:current] = info.floorsClimbed;
					}
					values[:max] = info.floorsClimbedGoal;
					values[:isValid] = true;
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

			// SG Addition
			case GOAL_TYPE_BODY_BATTERY:
				values[:isValid] = false;
				values[:max] = 100;

				if (Toybox has :Complications && mUseComplications) {
					var tmpValue = mGoalTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						values[:current] = tmpValue.toFloat();
						values[:isValid] = true;
					}
				}
				if (values[:isValid] == false && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
					var bodyBattery = Toybox.SensorHistory.getBodyBatteryHistory({:period=>1});
					if (bodyBattery != null) {
						bodyBattery = bodyBattery.next();
					}
					if (bodyBattery !=null) {
						bodyBattery = bodyBattery.data;
					}
					if (bodyBattery != null && bodyBattery >= 0 && bodyBattery <= 100) {
						values[:current] = bodyBattery.toFloat();
						values[:isValid] = true;
					}
				}

				break;

			// SG Addition
			case GOAL_TYPE_STRESS_LEVEL:
				values[:isValid] = false;
				values[:max] = 100;

				if (Toybox has :Complications && mUseComplications) {
					var tmpValue = mGoalTypes[index].get("ComplicationValue");
					if (tmpValue != null) {
						values[:current] = tmpValue.toFloat();
						values[:isValid] = true;
					}
				}
				if (values[:isValid] == false && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory)) {
					var stressLevel = Toybox.SensorHistory.getStressHistory({:period=>1});
					//DEBUG*/ var stressLevelDate = 0;

					if (stressLevel != null) {
						stressLevel = stressLevel.next();
					}
					if (stressLevel !=null) {
						//DEBUG*/ stressLevelDate = stressLevel.when.value();
						stressLevel = stressLevel.data;
					}

					if (stressLevel != null) {
						if (stressLevel >= 0 && stressLevel <= 100) {
							values[:current] = stressLevel.toFloat();
							values[:isValid] = true;
							gStressLevel = stressLevel;
	 					} else if (gStressLevel != null) {
							values[:current] = gStressLevel.toFloat();
							values[:isValid] = true;
							values[:staled] = true;
						}
 					} else if (gStressLevel != null) {
						values[:current] = gStressLevel.toFloat();
						values[:isValid] = true;
						values[:staled] = true;
					}
					//logMessage("stressLeve " + stressLevel + " count " + count + " keptCount " + keptCount + " stressLevelDate " + stressLevelDate);
				}

				break;

			case GOAL_TYPE_CALORIES:
				values[:current] = info.calories;

				// #123 Protect against null value returned by getProperty(). Trigger invalid goal handling code below.
				// Protect against unexpected type e.g. String.
				values[:max] = $.getIntProperty("CaloriesGoal", 2000);
				break;

			case GOAL_TYPE_OFF:
				values[:isValid] = false;
				break;
		}

		// #16: If user has set goal to zero, or negative (in simulator), show as invalid. Set max to 1 to avoid divide-by-zero
		// crash in GoalMeter.getSegmentScale().
		// Sanity check. I've seen weird Invalid Value and "System Error" in DataArea.setGoalValues:48 and :61. Make sure the data is valid
		if (values[:isValid] && (!(values[:max] instanceof Lang.Number || values[:max] instanceof Lang.Float) || values[:max] < 1)) {
			/*DEBUG*/ logMessage("values[:max] is invalid=" + values[:max]);
			values[:max] = 1;
			values[:isValid] = false;
		}
		if (values[:isValid] && (!(values[:current] instanceof Lang.Number || values[:current] instanceof Lang.Float))) {
			/*DEBUG*/ logMessage("values[:current] is invalid=" + values[:current]);
			values[:current] = 0;
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

	/*
	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory */
	function onHide() {
		/*DEBUG*/ logMessage("View hidding");
	}

	// The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep() {
		mIsSleeping = false;

		//Sys.println("onExitSleep()");

		// If watch does not support per-second updates, AND HideSeconds property is false,
		// show seconds, and make move bar original width.
		var hideSeconds = $.getIntProperty("HideSeconds", 0);
		if ((!PER_SECOND_UPDATES_SUPPORTED && hideSeconds == 0) || hideSeconds == 1 ) {
			setHideSeconds(false);
		}

		ReadWeather(false);

		// If watch requires burn-in protection, set flag to false when entering sleep.
		var settings = Sys.getDeviceSettings();
		if (settings has :requiresBurnInProtection && settings.requiresBurnInProtection) {
			mIsBurnInProtection = false;
			mBurnInProtectionChangedSinceLastDraw = true;
		}
	}

	// Terminate any active timers and prepare for slow updates.
	function onEnterSleep() {
		mIsSleeping = true;

		//Sys.println("onEnterSleep()");
		//Sys.println("Partial updates supported = " + PER_SECOND_UPDATES_SUPPORTED);

		// If watch does not support per-second updates, then hide seconds, and make move bar full width.
		// onUpdate() is about to be called one final time before entering sleep.
		// If HideSeconds property is true, do not wastefully hide seconds again (they should already be hidden).
		var hideSeconds = $.getIntProperty("HideSeconds", 0);
		if ((!PER_SECOND_UPDATES_SUPPORTED && hideSeconds == 0) || hideSeconds == 1) {
			setHideSeconds(true);
		}

		// If watch requires burn-in protection, set flag to true when entering sleep.
		var settings = Sys.getDeviceSettings();
		if (settings has :requiresBurnInProtection && settings.requiresBurnInProtection) {
			//DEBUG*/ logMessage("onEnterSleep with needing burning proctection");
			mIsBurnInProtection = true;
			mBurnInProtectionChangedSinceLastDraw = true;
		}

		Ui.requestUpdate();
	}

	function isSleeping() {
		return mIsSleeping;
	}

	function useComplications() {
		return mUseComplications;
	}

	function setHideSeconds(hideSeconds) {

		// #158 Venu 2.80 firmware crash: mIsBurnInProtection fails to be set in onEnterSleep(), hopefully because that function
		// is now not called at startup before entering sleep, rather than because requiresBurnInProtection is not set. mTime will
		// be null in always-on mode, so add additional safety check here.
		// TODO: If Venu is guaranteed to start in always-on mode, we could initialise mIsBurnInProtection to true if
		// requiresBurnInProtection is true.
		if (mIsBurnInProtection || (mTime == null)) {
			return;
		}

		mTime.setHideSeconds(hideSeconds);
		mDrawables[:MoveBar].setFullWidth(hideSeconds);
	}

	(:noComplications)
    function onComplicationUpdated(complicationId) {
	}

	(:hasComplications)
    function onComplicationUpdated(complicationId) {
		var complication = Complications.getComplication(complicationId);
		var complicationType = complication.getType();
		var complicationShortLabel = complication.shortLabel;
		var complicationValue = complication.value;

		//DEBUG*/ var complicationLongLabel = complication.longLabel; if (complicationType == Complications.COMPLICATION_TYPE_RECOVERY_TIME) { logMessage("Type: " + complicationType + " short label: " + complicationShortLabel + " long label: " + complicationLongLabel + " Value:" + complicationValue); }

		if (gTeslaComplication == true && complicationType == Complications.COMPLICATION_TYPE_INVALID && complicationShortLabel != null && complicationShortLabel.equals("TESLA")) {
			$.doTeslaComplication(complicationValue);
		}

		// I've seen this while in low power mode, so skip it
		if (complicationValue == null) {
			//DEBUG*/ logMessage("We got a Complication value of null for " + complicationType);
			return;
		}

		// Do fields first
		var fieldCount = $.getIntProperty("FieldCount", 3);

		for (var i = 0; i < fieldCount; i++) {
			if (mFieldTypes[i].get("ComplicationType") == complicationType) {
				mFieldTypes[i].put("ComplicationValue", complicationValue);
			}
		}

		// Now do goals
		if (mGoalTypes[0].get("ComplicationType") == complicationType) {
			mGoalTypes[0].put("ComplicationValue", complicationValue);
		}
		if (mGoalTypes[1].get("ComplicationType") == complicationType) {
			mGoalTypes[1].put("ComplicationValue", complicationValue);
		}
    }

	function hasField(fieldType) {
		return ((mFieldTypes[0].get("type") == fieldType) ||
				(mFieldTypes[1].get("type") == fieldType) ||
				(mFieldTypes[2].get("type") == fieldType));
	}
}

(:noComplications)
class CrystalDelegate extends Ui.WatchFaceDelegate {
    public function initialize(view as CrystalView) {
        WatchFaceDelegate.initialize();
    }
}

(:hasComplications)
class CrystalDelegate extends Ui.WatchFaceDelegate {
    private var mView as CrystalView;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as CrystalView) {
        WatchFaceDelegate.initialize();
        mView = view;
    }

	public function onPress(clickEvent as Ui.ClickEvent) as Lang.Boolean {
		var co_ords = clickEvent.getCoordinates();
        //DEBUG*/ logMessage("onPress called with x:" + co_ords[0] + ", y:" + co_ords[1]);

		// returns the complicationId within the boundingBoxes
		if (Toybox has :Complications && App.getApp().getView().useComplications()) {
			if (mView != null && mView.mDrawables != null && mView.mDataFields != null) { // Saw an unexpected error because one of these were null, although it shouldn't have happened
				var defComplicationName = $.getStringProperty("ComplicationName", "");
				var complicationId = checkBoundingBoxes(co_ords);
				if (complicationId != null) {
					try {
						Complications.exitTo(complicationId);
					}
					catch (e) {}
				}
				else if (defComplicationName.length() > 0 ) {
					// We're outside our hotspots, see if we can launch our Flashlight
					var iter = Complications.getComplications();
					if (iter == null) {
						return;
					}
					complicationId = iter.next();

					while (complicationId != null) {
						//logMessage(complicationId.longLabel.toString());
						if ((complicationId.getType() == Complications.COMPLICATION_TYPE_INVALID && complicationId.longLabel != null && complicationId.longLabel.equals(defComplicationName))) {
							//DEBUG*/ logMessage("Found our flashlight complication");
							complicationId = complicationId.complicationId;
							/*DEBUG*/ logMessage("complicationId is '" + complicationId + "'");
							if (complicationId != null) { // Got a crash caused by a null complicationId (while holding over 'Steps' while in a indoor walk activity)
								try {
									Complications.exitTo(complicationId);
								}
								catch (e) {}

								return;
							}
						}
						complicationId = iter.next();
					}
				}
			}
		}
	}

	function checkBoundingBoxes(co_ords) {
		// First check the indicators
		var indicatorCount = $.getIntProperty("IndicatorCount", 1);
		var spacingX;
		var spacingY;
		var complicationIndex;
		var complicationId;

		if (indicatorCount > 0) {
			var indicators = mView.mDrawables[:Indicators];
			if (indicators != null) {
				var locX = indicators[:locX];
				var locY = indicators[:locY];
				var batteryWidth = indicators[:mBatteryWidth];

				spacingY = indicators[:mSpacing];
				spacingX = batteryWidth * 2;
				locX -= (batteryWidth / 1.5).toNumber();
				if (indicatorCount == 1) {
					locY -= spacingY;
					spacingY *= 2;
				}
				else {
					locY -= spacingY / 2;
				}

				if (indicatorCount == 3) {
					complicationIndex = "Complication_I" + isWithin(co_ords[0], co_ords[1], locX, locY - spacingY, spacingX, spacingY, "1") + isWithin(co_ords[0], co_ords[1], locX, locY, spacingX, spacingY, "2") + isWithin(co_ords[0], co_ords[1], locX, locY + spacingY, spacingX, spacingY, "3");
				} else if (indicatorCount == 2) {
					complicationIndex = "Complication_I" + isWithin(co_ords[0], co_ords[1], locX, locY - spacingY / 2, spacingX, spacingY, "1") + isWithin(co_ords[0], co_ords[1], locX, locY + spacingY / 2, spacingX, spacingY, "2");
				} else if (indicatorCount == 1) {
					complicationIndex = "Complication_I" + isWithin(co_ords[0], co_ords[1], locX, locY, spacingX, spacingY, "1");
				}

				if (complicationIndex.equals("Complication_I") == false) {
					complicationId = Storage.getValue(complicationIndex);
				}

				//DEBUG*/ logMessage(complicationIndex + " = " + complicationId);
				if (complicationId != null) {
					return complicationId;
				}
			}
		}
		
		// Check the fields
		var fieldCount = $.getIntProperty("FieldCount", 3);

		if (fieldCount > 0) {
			spacingX = Sys.getDeviceSettings().screenWidth / (2 * fieldCount);
			spacingY = Sys.getDeviceSettings().screenHeight / 4;

			var left = mView.mDataFields.mLeft;
			var right = mView.mDataFields.mRight;
			var top = mView.mDataFields.mTop;

			if (left != null && right != null && top != null) {
				if (fieldCount == 3) {
					complicationIndex = "Complication_F" + isWithin(co_ords[0], co_ords[1], left - spacingX / 2, top - spacingY / 2, spacingX, spacingY, "1") + isWithin(co_ords[0], co_ords[1], (right + left) / 2 - spacingX / 2, top - spacingY /2, spacingX, spacingY, "2") + isWithin(co_ords[0], co_ords[1], right - spacingX / 2, top - spacingY / 2, spacingX, spacingY, "3");
				} else if (fieldCount == 2) {
					complicationIndex = "Complication_F" + isWithin(co_ords[0], co_ords[1], left + ((right - left) * 0.15) - spacingX / 2, top - spacingY / 2, spacingX, spacingY, "1") + isWithin(co_ords[0], co_ords[1], left + ((right - left) * 0.85) - spacingX / 2, top - spacingY / 2, spacingX, spacingY, "2");
				} else if (fieldCount == 1) {
					complicationIndex = "Complication_F" + isWithin(co_ords[0], co_ords[1], (right + left) / 2 - spacingX / 2, top - spacingY / 2, spacingX, spacingY, "1");
				}

				if (complicationIndex.equals("Complication_F") == false) {
					complicationId = Storage.getValue(complicationIndex);
				}

				//DEBUG*/ logMessage(complicationIndex + " = " + complicationId);
				if (complicationId != null) {
					return complicationId;
				}
			}
		}

		// Check the goals
		spacingX = Sys.getDeviceSettings().screenWidth / 11;
		spacingY = Sys.getDeviceSettings().screenHeight / 6;

		var left = mView.mDrawables[:DataArea].mGoalIconLeftX - spacingX / 8;
		var right = mView.mDrawables[:DataArea].mGoalIconRightX + spacingX / 8;
		var y = mView.mDrawables[:DataArea].mGoalIconY - spacingY / 8;

		if (left != null && right != null && y != null) {
			// spacing * 3 to give it more room so we can press on the text too.
			complicationIndex = "Complication_G" + isWithin(co_ords[0], co_ords[1], left, y, spacingX * 3, spacingY, "1") + isWithin(co_ords[0], co_ords[1], right - spacingX * 3, y, spacingX * 3, spacingY, "2");
			if (complicationIndex.equals("Complication_G") == false) {
				complicationId = Storage.getValue(complicationIndex);
			}

			//DEBUG*/ logMessage(complicationIndex + " = " + complicationId);
			if (complicationId != null) {
				return complicationId;
			}
		}

		return null;
	}

	function isWithin(x, y, startX, startY, spacingX, spacingY, field) {
		if (x > startX && x < startX + spacingX && y > startY and y < startY + spacingY) {
			//DEBUG*/ logMessage("True:  " + x + "/" + y + " is within " + startX + "/" + startY + " and " + (startX + spacingX).toString() + "/" + (startY + spacingY).toString());
			return field;
		}
		else {
			//DEBUG*/ logMessage("False:  " + x + "/" + y + " is NOT within " + startX + "/" + startY + " and " + (startX + spacingX).toString() + "/" + (startY + spacingY).toString());
			return "";
		}
	}

    //! The onPowerBudgetExceeded callback is called by the system if the
    //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
    //! the system will stop invoking onPartialUpdate each second, so we notify the
    //! view here to let the rendering methods know they should not be rendering a
    //! second hand.
    //! @param powerInfo Information about the power budget
    public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        //DEBUG*/ logMessage("Average execution time: " + powerInfo.executionTimeAverage);
        //DEBUG*/ logMessage("Allowed execution time: " + powerInfo.executionTimeLimit);
		//mView.turnPartialUpdatesOff();
    }
}
