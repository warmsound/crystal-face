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
		textColour = Graphics.COLOR_LT_GRAY; // Default in case we get nothing

		var value = "???";
		var showMode;

		gToggleCounter = (gToggleCounter + 1) & 7; // Increase by one, reset to 0 once 8 is reached. Called every second so incremented every second, giving a two second display of each value
		showMode = gToggleCounter / 2;  // 0-1 is battery, 2-3 Sentry, 4-5 preconditionning, 6-7 is inside temp changed to 0 to 3
		//logMessage("gToggleCounter=" + gToggleCounter + " showMode=" + showMode);

		var teslaInfo = Storage.getValue("TeslaInfo");
		if (teslaInfo != null) {
			var httpErrorTesla = teslaInfo.get("httpErrorTesla");
			var vehicleState = teslaInfo.get("VehicleState");
			var vehicleAsleep = (vehicleState != null && vehicleState.equals("asleep") == true);
			var vehicleOnline = (vehicleState != null && vehicleState.equals("online") == true);

			// Only specific error are handled, the others are displayed 'as is' in pink
			if (httpErrorTesla != null && (httpErrorTesla == 200 || httpErrorTesla == 401 || httpErrorTesla == 408)) {
				if (!vehicleOnline) { // If confirnmed asleep, only show battery and preconditionning (0 and 2)
					showMode &= 2;
				}

				if (httpErrorTesla == 401) { // No access token, only show the battery (in gray, default above)
					showMode = 0;
				}
				else if (vehicleAsleep || httpErrorTesla == 200) { // Vehicle confirmed asleep (even if we got a 408, we'll add a "?" after the battery level to show this) or we got valid data. If the vehicle is offline, the line will show gray for stale data
					textColour = gThemeColour; // Defaults to theme's color
				}

				switch (showMode) {
					case 0:
						var suffix = "";

						batteryLevel = teslaInfo.get("BatteryLevel");
						if (batteryLevel != null && batteryLevel != 999) {
							var chargingState = teslaInfo.get("ChargingState");
							if (httpErrorTesla != 200 && httpErrorTesla != 408) { // ResponseCode other than 200 and 408 will show a "?" beside thr battery level
								suffix = "?";
							}
							else if (vehicleAsleep) {
								suffix = "s";
							}
							else if (chargingState != null && chargingState.equals("Charging") == true) {
								suffix = "+";
							}

							value = batteryLevel + "%" + suffix;

							// If we're in theme's color, reset the color based on battery level, similar to the phone's battery
							if (batteryLevel <= /* BATTERY_LEVEL_CRITICAL */ 10 && textColour == gThemeColour) {
								textColour = Graphics.COLOR_RED;
							} else if (batteryLevel <= /* BATTERY_LEVEL_LOW */ 20 && textColour == gThemeColour) {
								textColour = Graphics.COLOR_YELLOW;
							}
						}
						else {
							value = "???%";
						}
						break;

					case 1:
						var sentryEnabled = teslaInfo.get("SentryEnabled");
						if (sentryEnabled != null && sentryEnabled instanceof Lang.Boolean) {
							value = (sentryEnabled ? "S on" : "S off");
						}
						else {
							value = "S ???";
						}
						break;

					case 2:
						var precondEnabled = teslaInfo.get("PrecondEnabled");
						if (precondEnabled != null && precondEnabled instanceof Lang.Boolean) {
							value = (sentryEnabled ? "P on" : "P off");
						}
						else {
							value = "P ???";
						}
						break;

					case 3:
						var insideTemp = teslaInfo.get("InsideTemp");
						if (insideTemp != null && insideTemp != 999) {
							value = (Sys.getDeviceSettings().temperatureUnits == Sys.UNIT_METRIC ? insideTemp.toNumber() + "°C" : ((insideTemp.toNumber() * 9) / 5 + 32).format("%d") + "°F"); 
						}
						else {
							value = (Sys.getDeviceSettings().temperatureUnits == Sys.UNIT_METRIC ? "???°C" : "???°F");
						}
						break;
				}
			}
			else {
				if (httpErrorTesla != null) {
					value = httpErrorTesla.toString();
				}
				textColour = Graphics.COLOR_PINK; // None handled error
			} 
		}

		//logMessage("value=" + value);		
		dc.setColor(textColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(x - (width / 2), y - height, gNormalFont, value, Graphics.TEXT_JUSTIFY_LEFT );
	}
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************
}

(:noComplications)
function updateComplications(complicationName, storageName, index, complicationType) {
}

(:hasComplications)
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
// - sec: 0-59
function getFormattedTime(hour, min, sec) {
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
		:sec => sec.format("%02d"),
		:amPm => amPm
	};
}

function MinutesToTimeString(totalMinutes) {
	var hours = (totalMinutes / 60).toNumber();
	var minutes = (totalMinutes - (hours * 60)).toNumber();
	var timeString = Lang.format("$1$:$2$", [hours.format("%d"), minutes.format("%02d") ]);
 	return timeString;
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
	else if (value instanceof Lang.String) {
		if (value.equals("true")) {
			value = true;
		}
		else if (value.equals("false")) {
			value = false;
		}
		else {
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

function to_array(string, splitter) {
	var array = new [30]; //Use maximum expected length
	var index = 0;
	var location;

	do {
		location = string.find(splitter);
		if (location != null) {
			array[index] = string.substring(0, location);
			string = string.substring(location + 1, string.length());
			index++;
		}
	} while (location != null);

	array[index] = string;

	var result = new [index + 1];
	for (var i = 0; i <= index; i++) {
		result[i] = array[i];
	}
	return result;
}

(:noComplications)
function doTeslaComplication(complicationValue) {
}

(:hasComplications)
function doTeslaComplication(complicationValue) {
	/*DEBUG*/ logMessage("Complication read: " + complicationValue);
	if (complicationValue instanceof Lang.String) { // Only handle the enhance data sent, not just the battery SoC (a Number)
		var teslaInfo = Storage.getValue("TeslaInfo");
		if (teslaInfo == null){
			teslaInfo = {};
		}
		var arrayInfo = $.to_array(complicationValue, "|");
		teslaInfo.put("httpErrorTesla", $.validateNumber(arrayInfo[0], 401)); // Defaults to need token
		teslaInfo.put("BatteryLevel", $.validateNumber(arrayInfo[1], 999)); // 999 means in writeBatteryLevel that we didn't get any
		teslaInfo.put("ChargingState", $.validateString(arrayInfo[2], ""));
		teslaInfo.put("InsideTemp", $.validateNumber(arrayInfo[3], 999)); // 999 means in writeBatteryLevel that we didn't get any
		teslaInfo.put("SentryEnabled", $.validateBoolean(arrayInfo[4], "")); // Yes, putting an empty string instead of a Boolean. The writeBatteryLevel will know it means I don't have one
		teslaInfo.put("PrecondEnabled", $.validateBoolean(arrayInfo[5], "")); // Yes, putting an empty string instead of a Boolean. The writeBatteryLevel will know it means I don't have one
		teslaInfo.put("VehicleState", $.validateString(arrayInfo[6], ""));

		Storage.setValue("TeslaInfo", teslaInfo);
	}
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
	var d = Gregorian.info(now, Time.FORMAT_SHORT);
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
	M += MFrac;
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
	lambda += lambdaFrac;
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

	var tzOffset = (tz == null) ? (Sys.getClockTime().timeZoneOffset / 3600.0) : tz;
	return [
		/* localRise */ (deltaJRise * 24) + tzOffset,
		/* localSet */ (deltaJSet * 24) + tzOffset
	];
}

//DEBUG
(:debug, :background)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	Sys.println(dateStr + " : " + message);
}
//DEBUG*/

(:release, :background)
function logMessage(message) {
}

/*
function type_name(obj) {
    if (obj instanceof Toybox.Lang.Number) {
        return "Number";
    } else if (obj instanceof Toybox.Lang.Long) {
        return "Long";
    } else if (obj instanceof Toybox.Lang.Float) {
        return "Float";
    } else if (obj instanceof Toybox.Lang.Double) {
        return "Double";
    } else if (obj instanceof Toybox.Lang.Boolean) {
        return "Boolean";
    } else if (obj instanceof Toybox.Lang.String) {
        return "String";
    } else if (obj instanceof Toybox.Lang.Array) {
        var s = "Array [";
        for (var i = 0; i < obj.size(); ++i) {
            s += type_name(obj);
            s += ", ";
        }
        s += "]";
        return s;
    } else if (obj instanceof Toybox.Lang.Dictionary) {
        var s = "Dictionary{";
        var keys = obj.keys();
        var vals = obj.values();
        for (var i = 0; i < keys.size(); ++i) {
            s += keys;
            s += ": ";
            s += vals;
            s += ", ";
        }
        s += "}";
        return s;
    } else if (obj instanceof Toybox.Time.Gregorian.Info) {
        return "Gregorian.Info";
    } else {
        return "???";
    }
}
*/