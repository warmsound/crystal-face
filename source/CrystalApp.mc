using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Time;
using Toybox.Time.Gregorian;

// In-memory current location.
// Previously persisted in App.Storage, but now persisted in Object Store due to #86 workaround for App.Storage firmware bug.
// Current location retrieved/saved in checkPendingWebRequests().
// Persistence allows weather and sunrise/sunset features to be used after watch face restart, even if watch no longer has current
// location available.
var gLocationLat = null;
var gLocationLng = null;

(:background)
class CrystalApp extends App.AppBase {

	var mView;
	var mFieldTypes = new [3];

	function initialize() {
		AppBase.initialize();
	}

	/*
	// onStart() is called on application start up
	function onStart(state) {
	}

	// onStop() is called when your application is exiting
	function onStop(state) {
	}
	*/

	// Return the initial view of your application here
	function getInitialView() {
		mView = new CrystalView();
		onSettingsChanged(); // After creating view.
		return [mView];
	}

	function getView() {
		return mView;
	}

	function getIntProperty(key, defaultValue) {
		var value = getProperty(key);
		if (value == null) {
			value = defaultValue;
		} else if (!(value instanceof Number)) {
			value = value.toNumber();
		}
		return value;
	}

	// New app settings have been received so trigger a UI update
	function onSettingsChanged() {
		mFieldTypes[0] = getIntProperty("Field1Type", 0);
		mFieldTypes[1] = getIntProperty("Field2Type", 1);
		mFieldTypes[2] = getIntProperty("Field3Type", 2);

		mView.onSettingsChanged(); // Calls checkPendingWebRequests().

		Ui.requestUpdate();
	}

	function hasField(fieldType) {
		return ((mFieldTypes[0] == fieldType) ||
			(mFieldTypes[1] == fieldType) ||
			(mFieldTypes[2] == fieldType));
	}

	// Determine if any web requests are needed.
	// If so, set approrpiate pendingWebRequests flag for use by BackgroundService, then register for
	// temporal event.
	// Currently called on layout initialisation, when settings change, and on exiting sleep.
	(:background_method)
	function checkPendingWebRequests() {
		// Attempt to update current location, to be used by Sunrise/Sunset, and Weather.
		// If current location available from current activity, save it in case it goes "stale" and can not longer be retrieved.
		var location = Activity.getActivityInfo().currentLocation;
		if (location) {
			location = location.toDegrees(); // Array of Doubles.
			gLocationLat = location[0].toFloat();
			gLocationLng = location[1].toFloat();

			setProperty("LastLocationLat", gLocationLat);
			setProperty("LastLocationLng", gLocationLng);

		// If current location is not available, read stored value from Object Store, being careful not to overwrite a valid
		// in-memory value with an invalid stored one.
		} else {
			var lat = getProperty("LastLocationLat");
			if (lat != null) {
				gLocationLat = lat;
			}

			var lng = getProperty("LastLocationLng");
			if (lng != null) {
				gLocationLng = lng;
			}
		}

		if (!(Sys has :ServiceDelegate)) {
			return;
		}

		var pendingWebRequests = getProperty("PendingWebRequests");
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		// 1. City local time:
		// City has been specified.
		var city = getProperty("LocalTimeInCity");
		
		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((city != null) && (city.length() > 0)) {

			var cityLocalTime = getProperty("CityLocalTime");

			// No existing data.
			if ((cityLocalTime == null) ||

			// Existing data is old.
			((cityLocalTime["next"] != null) && (Time.now().value() >= cityLocalTime["next"]["when"]))) {

				pendingWebRequests["CityLocalTime"] = true;
		
			// Existing data not for this city: delete it.
			// Error response from server: contains requestCity. Likely due to unrecognised city. Prevent requesting this
			// city again.
			} else if (!cityLocalTime["requestCity"].equals(city)) {

				deleteProperty("CityLocalTime");
				pendingWebRequests["CityLocalTime"] = true;
			}
		}

		// 2. Weather:
		// Location must be available, weather or humidity (#113) data field must be shown.
		if ((gLocationLat != null) &&
			(hasField(FIELD_TYPE_WEATHER) || hasField(FIELD_TYPE_HUMIDITY))) {

			var owmKeyOverride = getProperty("OWMKeyOverride");
			if (owmKeyOverride == null || owmKeyOverride.length() == 0) {
//2022-04-10 logMessage("Using Garmin Weather so skipping OWM code");
			} else {
//2022-04-10 logMessage("Using OpenWeatherMap");
				var owmCurrent = getProperty("OpenWeatherMapCurrent");
	
				// No existing data.
				if (owmCurrent == null) {
					pendingWebRequests["OpenWeatherMapCurrent"] = true;
				// Successfully received weather data.
				} else if (owmCurrent["cod"] == 200) {
					// Existing data is older than 30 mins.
					// TODO: Consider requesting weather at sunrise/sunset to update weather icon.
					if ((Time.now().value() > (owmCurrent["dt"] + 1800)) ||
	
					// Existing data not for this location.
					// Not a great test, as a degree of longitude varies betwee 69 (equator) and 0 (pole) miles, but simpler than
					// true distance calculation. 0.02 degree of latitude is just over a mile.
					(((gLocationLat - owmCurrent["lat"]).abs() > 0.02) || ((gLocationLng - owmCurrent["lon"]).abs() > 0.02))) {
	
						pendingWebRequests["OpenWeatherMapCurrent"] = true;
					}
				}
			}
		}

		// 3. Tesla:
//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
		if (getProperty("Tesla") != null) {
			var TeslaInfo = getProperty("TeslaInfo");
			if (TeslaInfo == null) { // We're not doing Tesla stuff so why asking for it, clear that
				pendingWebRequests["TeslaInfo"] = false;
			} else { // We're doing Tesla stuff
				var batterie_level = null; 
				var charging_state = null;
				var batterie_stale = false;
				var carAsleep = false;
				
				// First handle errors, setting batterie_level to "N/A" if the query returned a vehicle not found.
				// If we failed to get access, maybe our token has expired, clear it so next time the background process runs, it will refresh it
				// Other errors are silent for now
				var result = TeslaInfo["httpErrorTesla"];
				if (result != null) {
					if (result == 400 || result == 401) { // Our token has expired, refresh it
						setProperty("TeslaAccessToken", null); // Try to get a new vehicleID
						batterie_stale = true;
					} else if (result == 404) { // We got an vehicle not found error, reset our vehicle ID
						setProperty("TeslaVehicleID", null); // Try to get a new vehicleID
						batterie_stale = true;
					} else if (result == 408) { // Car is aslepep keep the old data but stop charging if it still was before going to sleep
						carAsleep = true;
					}
					else {
						batterie_stale = true;
					}
					setProperty("TeslaError", result);
				}
				
				// Check if our access token was refreshed. If so, store the new access and refresh tokens
				result = TeslaInfo["Token"];
				if (result != null) {
					var accessToken = result["access_token"];
					var refreshToken = result["refresh_token"];
					var expires_in = result["expires_in"];
					var created_at = Time.now().value(); 
					setProperty("TeslaAccessToken", accessToken);
					if (refreshToken != null && refreshToken.equals("") == false) { // Only if we received a refresh tokem
						setProperty("TeslaRefreshToken", refreshToken);
					}
					setProperty("TeslaTokenExpiresIn", expires_in);
					setProperty("TeslaTokenCreatedAt", created_at);

					setProperty("TeslaError", null);
				}

				// If the car isn't asleep and we didn't get an error, read what was returned
				else if (!carAsleep && !batterie_stale) {
					var batterie_state = TeslaInfo["battery_state"];
					if (batterie_state) {
						batterie_level = batterie_state["battery_level"]; 
						charging_state = batterie_state["charging_state"];
					}

					var inside_temp = TeslaInfo["inside_temp"];
					if (inside_temp != null) {
						setProperty("TeslaInsideTemp", inside_temp.toString());
					}
					
					var precond_enabled = TeslaInfo["preconditioning"];
					if (precond_enabled != null) {
						setProperty("TeslaPreconditioning", precond_enabled.toString());
					}

					var sentry_enabled = TeslaInfo["sentry_enabled"];
					if (sentry_enabled != null) {
						setProperty("TeslaSentryEnabled", sentry_enabled.toString());
					}

					// Read its vehicleID. If we don't have one, clear our property so the next call made by the background process will try to retrieve it.
					// If we have no vehicle, set the batterie level to N/A
					var vehicle_id = TeslaInfo["vehicle_id"];
					if (vehicle_id != null) { // We got our vehicle ID. Store it for future use in the background process
						if (vehicle_id != 0) {
							setProperty("TeslaVehicleID", vehicle_id.toString());
						} else {
							setProperty("TeslaVehicleID", null);
							batterie_stale = true;
							batterie_level = "N/A";
						}
					} else {
						batterie_stale = true;
					}

					// Here batterie_level is the same as what was read earlier or changed to N/A for some reason above.
					if (batterie_level  != null) {
						setProperty("TeslaBatterieLevel", batterie_level);
						setProperty("TeslaBatterieStale", batterie_stale);
						setProperty("TeslaChargingState", charging_state);

						setProperty("TeslaError", null);
						
					} else {
						setProperty("TeslaBatterieStale", true);
						setProperty("TeslaError", null);
					}
				} else if (!batterie_stale) { // Car is asleap, say so
					setProperty("TeslaChargingState", "Sleeping");
					setProperty("TeslaBatterieStale", false);
					setProperty("TeslaError", null);
				}
				
				pendingWebRequests["TeslaInfo"] = true;
			}
		}
		else {
			pendingWebRequests.remove("TeslaInfo");
		}
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************
		
		// If there are any pending requests and we can do background process
		if (Toybox.System has :ServiceDelegate && pendingWebRequests.keys().size() > 0) {
			// Register for background temporal event as soon as possible.
			var lastTime = Bg.getLastTemporalEventTime();
			if (lastTime) {
				// Events scheduled for a time in the past trigger immediately.
				var nextTime = lastTime.add(new Time.Duration(5 * 60));
				Bg.registerForTemporalEvent(nextTime);
			} else {
				Bg.registerForTemporalEvent(Time.now());
			}
		}

		setProperty("PendingWebRequests", pendingWebRequests);
	}

	(:background_method)
	function getServiceDelegate() {
		return [new BackgroundService()];
	}

	// Handle data received from BackgroundService.
	// On success, clear appropriate pendingWebRequests flag.
	// data is Dictionary with single key that indicates the data type received. This corresponds with Object Store and
	// pendingWebRequests keys.
	(:background_method)
	function onBackgroundData(data) {
//2022-04-10 logMessage("onBackgroundData:received '" + data + "'");
		var pendingWebRequests = getProperty("PendingWebRequests");
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		var type = data.keys()[0]; // Type of received data.
		var storedData = getProperty(type);
		var receivedData = data[type]; // The actual data received: strip away type key.
		
		// Do process the data if what we got was an error
		if (receivedData["httpError"] == null) {
			// New data received: clear pendingWebRequests flag and overwrite stored data.
			storedData = receivedData;
			pendingWebRequests.remove(type);
			setProperty("PendingWebRequests", pendingWebRequests);
			setProperty(type, storedData);
	
			checkPendingWebRequests(); // We just got new data, process them right away before displaying
		}		

		Ui.requestUpdate();
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
		hour = hour.format(getProperty("HideHoursLeadingZero") ? INTEGER_FORMAT : "%02d");

		return {
			:hour => hour,
			:min => min.format("%02d"),
			:amPm => amPm
		};
	}
}

(:debug)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	Sys.println(dateStr + " : " + message);
}

(:release)
function logMessage(output) {
}