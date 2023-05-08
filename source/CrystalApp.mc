using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Complications;

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// In-memory current location.
// Previously persisted in App.Storage, but now persisted in Object Store due to #86 workaround for App.Storage firmware bug.
// Current location retrieved/saved in checkPendingWebRequests().
// Persistence allows weather and sunrise/sunset features to be used after watch face restart, even if watch no longer has current
// location available.
var gLocationLat = null;
var gLocationLng = null;
var gTeslaComplication = false;

(:background)
class CrystalApp extends App.AppBase {
	var mView;

	function initialize() {
		AppBase.initialize();

		gTeslaComplication = getBoolProperty("TeslaLink", false);
	}

	// Return the initial view of your application here
	function getInitialView() {
		if (WatchUi has :WatchFaceDelegate) {
			mView = new CrystalView();
			onSettingsChanged(); // After creating view.
			var delegate = new CrystalDelegate(mView);
			return [mView, delegate] as Array<Views or InputDelegates>;
		}
		else {
			mView = new CrystalView();
			onSettingsChanged(); // After creating view.
			return [mView];
		}
	}

	function getView() {
		return mView;
	}

	// New app settings have been received so trigger a UI update
	(:background_method)
	function getServiceDelegate() {
		return [new BackgroundService()];
	}

	function onSettingsChanged() {
		mView.onSettingsChanged(); // Calls checkPendingWebRequests().

		Ui.requestUpdate();
	}

	// Handle data received from BackgroundService.
	// On success, clear appropriate pendingWebRequests flag.
	// data is Dictionary with single key that indicates the data type received. This corresponds with Object Store and
	// pendingWebRequests keys.
	(:background_method)
	function onBackgroundData(data) {
		//2022-04-10 logMessage("onBackgroundData:received '" + data + "'");
		var pendingWebRequests = Storage.getValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		var type = data.keys()[0]; // Type of received data.
		var receivedData = data[type]; // The actual data received: strip away type key.
		
		// Do process the data if what we got was an error
		if (receivedData["httpError"] == null) {
			// New data received: clear pendingWebRequests flag and overwrite stored data.
			pendingWebRequests.remove(type);
			Storage.setValue("PendingWebRequests", pendingWebRequests);

			if (type.equals("TeslaInfo")) {
				// TeslaInfo is refeshed, not overwritten
				var storedData = Storage.getValue(type);
				if (storedData == null) {
					storedData = {};
				}

                var keys = receivedData.keys();
                var values = receivedData.values();

				for (var i = 0; i < keys.size(); i++) {
					storedData.put(keys[i], values[i]);
				}
				Storage.setValue(type, storedData);
			}
			else {
				Storage.setValue(type, receivedData);
			}

			checkPendingWebRequests(); // We just got new data, process them right away before displaying
		}

		Ui.requestUpdate();
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
			if (location[0] != 0.0 && location[1] != 0.0) {
				gLocationLat = location[0];
				gLocationLng = location[1];
				Properties.setValue("LastLocationLat", gLocationLat.format("%0.5f"));
				Properties.setValue("LastLocationLng", gLocationLng.format("%0.5f"));
			}
		}
		// If current location is not available, read stored value from Object Store, being careful not to overwrite a valid
		// in-memory value with an invalid stored one.
		else {
			var lat = $.getStringProperty("LastLocationLat","");
			if (lat != null) {
				gLocationLat = lat.toFloat();
			}

			var lng = $.getStringProperty("LastLocationLng","");
			if (lng != null) {
				gLocationLng = lng.toFloat();
			}
		}

		if (!(Sys has :ServiceDelegate)) {
			return;
		}

		var pendingWebRequests = Storage.getValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		// 1. City local time:
		// City has been specified.
		var city = $.getStringProperty("LocalTimeInCity","");
		
		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((city != null) && (city.length() > 0)) {

			var cityLocalTime = Storage.getValue("CityLocalTime");

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
			(mView.hasField(FIELD_TYPE_WEATHER) || mView.hasField(FIELD_TYPE_HUMIDITY))) {

			var owmKeyOverride = $.getStringProperty("OWMKeyOverride","");
			if (owmKeyOverride == null || owmKeyOverride.length() == 0) {
				//2022-04-10 logMessage("Using Garmin Weather so skipping OWM code");
			} else {
				//2022-04-10 logMessage("Using OpenWeatherMap");
				var owmCurrent = Storage.getValue("OpenWeatherMapCurrent");
	
				// No existing data.
				if (owmCurrent == null) {
					pendingWebRequests["OpenWeatherMapCurrent"] = true;
				// Successfully received weather data.
				} else if (owmCurrent["cod"] == 200) {
					// Existing data is older than 5 mins.
					// TODO: Consider requesting weather at sunrise/sunset to update weather icon.
					if ((Time.now().value() > (owmCurrent["dt"] + 300)) ||
	
					// Existing data not for this location.
					// Not a great test, as a degree of longitude varies betwee 69 (equator) and 0 (pole) miles, but simpler than
					// true distance calculation. 0.02 degree of latitude is just over a mile.
					(((gLocationLat - owmCurrent["lat"]).abs() > 0.02) || ((gLocationLng - owmCurrent["lon"]).abs() > 0.02))) {
						pendingWebRequests["OpenWeatherMapCurrent"] = true;
					}
				} else {
					pendingWebRequests["OpenWeatherMapCurrent"] = true;
				}
			}
		}

		// 3. Tesla:
//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
//*******************checkPendingWebRequests**********************
		if (Storage.getValue("Tesla") != null && gTeslaComplication == false) {
			var teslaInfo = Storage.getValue("TeslaInfo");
			if (teslaInfo == null) { // We're not doing Tesla stuff so why asking for it, clear that
				pendingWebRequests["TeslaInfo"] = false;
			} else { // We're doing Tesla stuff
				var arrayKey = ["RefreshToken", "AccessToken", "TokenCreatedAt", "TokenExpiresIn", "VehicleID"];
				var arrayProp = [true, true, false, false, false ];

				for (var i = 0; i < arrayKey.size(); i++) {
					var value = teslaInfo.get(arrayKey[i]);
					if (value != null) {
						if (arrayProp[i]) {
							Properties.setValue("Tesla" + arrayKey[i], value);
						}
						else {
							Storage.setValue("Tesla" + arrayKey[i], value);
						}
						teslaInfo.remove(arrayKey[i]);
					}
				}

				// We deal with specific errors here, leaving the good stuff to the battery indicator
				var responseCode = teslaInfo["httpErrorTesla"];
				var internalResponseCode = teslaInfo["httpInternalErrorTesla"];
				if (responseCode != null && internalResponseCode != null) {
					if (responseCode == 401 && internalResponseCode != 200) { // Our token has expired and we were unable to get one, refresh it
						Properties.setValue("TeslaAccessToken", null); // Try to get a new vehicleID
					} else if (responseCode == 404 && internalResponseCode != 200) { // We got a vehicle not found error and we were unable to get one, reset our vehicle ID
						Storage.remove("VehicleID"); // Try to get a new vehicleID
					}

					Storage.setValue("TeslaInfo", teslaInfo);
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

		Storage.setValue("PendingWebRequests", pendingWebRequests);
	}
}
