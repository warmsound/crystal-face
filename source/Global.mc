using Toybox.WatchUi as Ui;
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

import Toybox.Lang;

// x, y are co-ordinates of centre point.
// width and height are outer dimensions of battery "body".
function drawBatteryMeter(dc, x, y, width, height) {
	dc.setColor(gThemeColour, Graphics.COLOR_TRANSPARENT);
	dc.setPenWidth(/* BATTERY_LINE_WIDTH */ 2);

	// Body.
	// drawRoundedRectangle's x and y are top-left corner of middle of stroke.
	// Bottom-right corner of middle of stroke will be (x + width - 1, y + height - 1).
	dc.drawRoundedRectangle(
		x - (width / 2) + /* (BATTERY_LINE_WIDTH / 2) */ 1,
		y - (height / 2) + /* (BATTERY_LINE_WIDTH / 2) */ 1,
		width - /* BATTERY_LINE_WIDTH + 1 */ 1,
		height - /* BATTERY_LINE_WIDTH + 1 */ 1,
		/* BATTERY_CORNER_RADIUS */ 2 * SCREEN_MULTIPLIER);

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
	if (batteryLevel <= /* BATTERY_LEVEL_CRITICAL */ 10) {
		fillColour = Graphics.COLOR_RED;
	} else if (batteryLevel <= /* BATTERY_LEVEL_LOW */ 20) {
		fillColour = Graphics.COLOR_YELLOW;
	} else {
		fillColour = gThemeColour;
	}

	dc.setColor(fillColour, Graphics.COLOR_TRANSPARENT);

	var lineWidthPlusMargin = (/* BATTERY_LINE_WIDTH */ 2 + BATTERY_MARGIN);
	var fillWidth = width - (2 * lineWidthPlusMargin);
	dc.fillRectangle(
		x - (width / 2) + lineWidthPlusMargin,
		y - (height / 2) + lineWidthPlusMargin,
		Math.ceil(fillWidth * (batteryLevel / 100)), 
		height - (2 * lineWidthPlusMargin));
}

var gToggleCounter = 0; // Used to switch between charge and inside temp

function writeBatteryLevel(dc, x, y, width, height, type) {
	var batteryLevel;		
	var textColour;
	
	if (type == 0) { // Standard watch battery is being shown
		batteryLevel = Math.floor(Sys.getSystemStats().battery);

		if (batteryLevel <= /* BATTERY_LEVEL_CRITICAL */ 10) {
			textColour = Graphics.COLOR_RED;
		} else if (batteryLevel <= /* BATTERY_LEVEL_LOW */ 20) {
			textColour = Graphics.COLOR_YELLOW;
		} else {
			textColour = gThemeColour;
		}

		dc.setColor(textColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(x - (width / 2), y - height, gNormalFont, batteryLevel.toNumber().format(INTEGER_FORMAT) + "%", Graphics.TEXT_JUSTIFY_LEFT);
	}
//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
	else { // Tesla stuff
		var value;
		var batteryStale = false;
		var chargingState = 0;
		var error = null;
		var showMode;

		gToggleCounter = (gToggleCounter + 1) & 7; // Increase by one, reset to 0 once 8 is reached
		showMode = gToggleCounter / 2;  // 0-1 is battery, 2-3 Sentry, 4-5 preconditionning, 6-7 is inside temp changed to 0 to 3
		//logMessage("gToggleCounter=" + gToggleCounter + " showMode=" + showMode);
		batteryStale = Storage.getValue("TeslaBatterieStale");
		chargingState = Storage.getValue("TeslaChargingState");
		error = Storage.getValue("TeslaError");

		if (chargingState != null) {
			if (chargingState.equals("Charging")) {
				chargingState = 1;
			} else if (chargingState.equals("Sleeping")) {
				chargingState = 2;
				showMode /= 2; // Keep only 0 and 2.
			} else {
				chargingState = 0;
			}
		} else {
			chargingState = 0;
		}

		var inText = null;
		switch (showMode) {
			case 0:
				value = Storage.getValue("TeslaBatterieLevel");
				break;
			case 1:
				value = Storage.getValue("TeslaPreconditioning");
				if (value != null && value.equals("true")) {
					inText = "P  on";
				}
				else if (value != null && value.equals("false")) {
					inText = "P off";
				}
				else {
					inText = "P ?";
				}
				break;
			case 2:
				value = Storage.getValue("TeslaSentryEnabled");
				if (value != null && value.equals("true")) {
					inText = "S on";
				}
				else if (value != null && value.equals("false")) {
					inText = "S off";
				}
				else {
					inText = "S ?";
				}
				break;
			case 3:
				value = Storage.getValue("TeslaInsideTemp");
				break;
		}

		//logMessage("value=" + value);		
		if (value == null) {
			value = "N/A";
		}
		
		if (inText != null && error == null) {
			if (batteryStale == true) {
				textColour = Graphics.COLOR_LT_GRAY;
			} else {
				textColour = gThemeColour;
			}
			dc.setColor(textColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(x - (width / 2), y - height, gNormalFont, inText, Graphics.TEXT_JUSTIFY_LEFT);
		} else if (value == null || (value instanceof Toybox.Lang.String && value.equals("N/A")) && error == null) {
			dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
			dc.drawText(x - (width / 2), y - height, gNormalFont, "???", Graphics.TEXT_JUSTIFY_LEFT);
		} else {
			var suffixe = "";

			if (error != null) {
				textColour = Graphics.COLOR_PINK;
				value = error.toFloat();
			} else {
				value = value.toFloat();
	
				if (batteryStale == true) {
					textColour = Graphics.COLOR_LT_GRAY;
				} else if (value <= /* BATTERY_LEVEL_CRITICAL */ 10 && showMode == 0) {
					textColour = Graphics.COLOR_RED;
				} else if (value <= /* BATTERY_LEVEL_LOW */ 20 && showMode == 0) {
					textColour = Graphics.COLOR_YELLOW;
				} else {
					textColour = gThemeColour;
				}
			
				if (showMode == 0) {
					suffixe = "%" + (chargingState == 1 ? "+" : (chargingState == 2 ? "s" : ""));
				} else {
					suffixe = "°C";
					if (Sys.getDeviceSettings().temperatureUnits == Sys. UNIT_STATUTE) {
						suffixe = "°F";
						value = value * 9.0 / 5.0 + 32;
					}
				}
			}

			dc.setColor(textColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(x - (width / 2), y - height, gNormalFont, value.toNumber().format(INTEGER_FORMAT) + suffixe, Graphics.TEXT_JUSTIFY_LEFT);
		}
	}
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************
}

function updateComplications(complicationName, storageName, index, complicationType) {
	if (Toybox has :Complications) {
		// Check if we should subscribe to our Tesla Complication
		var iter = Complications.getComplications();
		if (iter == null) {
			return;
		}
		var complicationId = iter.next();

		while (complicationId != null) {
			//logMessage(complicationId.longLabel.toString());
			if (complicationId.getType() == complicationType || (complicationId.getType() == Complications.COMPLICATION_TYPE_INVALID && complicationId.longLabel != null && complicationId.longLabel.equals(complicationName))) {
				//DEBUG*/ logMessage("Found complication " + complicationName + " with type " + complicationType);
				break;
			}
			complicationId = iter.next();
		}

		if (complicationId != null) {
			if (complicationId.getType() == Complications.COMPLICATION_TYPE_INVALID) {
				complicationId = complicationId.complicationId;
			}
			else {
				complicationId = new Complications.Id(complicationType);
			}
			if (index != null) {
				Storage.setValue(storageName + index, complicationId);
				Complications.subscribeToUpdates(complicationId);
			}
		}
	}
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

	// #10 If in 12-hour mode with Hide Hours Leading Zero set, hide leading zero. Otherwise, show leading zero.
	// #69 Setting now applies to both 12- and 24-hour modes.
	hour = hour.format($.getBoolProperty("HideHoursLeadingZero", true) ? INTEGER_FORMAT : "%02d");

	return {
		:hour => hour,
		:min => min.format("%02d"),
		:amPm => amPm
	};
}

(:background)
function getIntProperty(key, defaultValue) {
	var value;
	var exception;

	try {
		exception = false;
		value = Properties.getValue(key);
	}
	catch (e) {
		exception = true;
		value = defaultValue;
	}

	if (exception) {
		try {
			Properties.setValue(key, defaultValue);
		}
		catch (e) {
		}
	}
	return validateNumber(value, defaultValue);
}

(:background)
function validateNumber(value, defaultValue) {
	if (value == null || !(value has :toNumber)) {
		value = defaultValue;
	} else if (!(value instanceof Lang.Number)) {
		try {
			value = value.toNumber();
		}
		catch (e) {
			value = defaultValue;
		}
	}
	if (value == null) {
		value = defaultValue;
	}
	return value;
}

(:background)
function getFloatProperty(key, defaultValue) {
	var value;
	var exception;

	try {
		exception = false;
		value = Properties.getValue(key);
	}
	catch (e) {
		exception = true;
		value = defaultValue;
	}

	if (exception) {
		try {
			Properties.setValue(key, defaultValue);
		}
		catch (e) {
		}
	}
	return validateFloat(value, defaultValue);
}

(:background)
function validateFloat(value, defaultValue) {
	if (value == null || !(value has :toFloat)) {
		value = defaultValue;
	} else if (!(value instanceof Lang.Float)) {
		try {
			value = value.toFloat();
		}
		catch (e) {
			value = defaultValue;
		}
	}
	if (value == null) {
		value = defaultValue;
	}
	return value;
}

(:background)
function getStringProperty(key, defaultValue) {
	var value;
	var exception;

	try {
		exception = false;
		value = Properties.getValue(key);
	}
	catch (e) {
		exception = true;
		value = defaultValue;
	}

	if (exception) {
		try {
			Properties.setValue(key, defaultValue);
		}
		catch (e) {
		}
	}
	return validateString(value, defaultValue);
}

(:background)
function validateString(value, defaultValue) {
	if (value == null || !(value has :toString)) {
		value = defaultValue;
	} else if (!(value instanceof Lang.String)) {
		try {
			value = value.toString();
		}
		catch (e) {
			value = defaultValue;
		}
	}
	if (value == null) {
		value = defaultValue;
	}
	return value;
}

(:background)
function getBoolProperty(key, defaultValue) {
	var value;
	var exception;

	try {
		exception = false;
		value = Properties.getValue(key);
	}
	catch (e) {
		exception = true;
		value = defaultValue;
	}

	if (exception) {
		try {
			Properties.setValue(key, defaultValue);
		}
		catch (e) {
		}
	}

	return validateBoolean(value, defaultValue);
}

(:background)
function validateBoolean(value, defaultValue) {
	if (value == null) {
		value = defaultValue;
	} else if ((value instanceof Lang.Boolean) || (value instanceof Lang.Number)) {
		try {
			if (value) {
				value = true;
			}
			else {
				value = false;
			}
		}
		catch (e) {
			value = defaultValue;
		}
	}
	else {
		value = defaultValue;
	}

	if (value == null) {
		value = defaultValue;
	}
	return value;
}

(:debug, :background)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	Sys.println(dateStr + " : " + message);
}

(:release, :background)
function logMessage(message) {
}
