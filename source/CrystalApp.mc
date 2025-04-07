using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Time;
using Toybox.Application.Storage as Storage;
using Toybox.Application.Properties as Properties;

import Toybox.Lang;
import Toybox.Application;

typedef PendingWebRequests as Dictionary<String, Boolean>;

typedef FormattedTime as {
	:hour as String,
	:min as String,
	:amPm as String
};

// In-memory current location.
// Previously persisted in App.Storage, but now persisted in Object Store due to #86 workaround for App.Storage firmware bug.
// Current location retrieved/saved in checkPendingWebRequests().
// Persistence allows weather and sunrise/sunset features to be used after watch face restart, even if watch no longer has current
// location available.
var gLocationLat = null;
var gLocationLng = null;

(:properties_and_storage,:background)
function getPropertyValue(key as PropertyKeyType) as PropertyValueType {
	return Properties.getValue(key);
}
(:properties_and_storage,:background)
function setPropertyValue(key as PropertyKeyType, value as PropertyValueType) as Void {
	Properties.setValue(key, value);
}
(:properties_and_storage,:background)
function getStorageValue(key as PropertyKeyType) as PropertyValueType {
	return Storage.getValue(key);
}
(:properties_and_storage,:background)
function setStorageValue(key as PropertyKeyType, value as PropertyValueType) as Void {
	Storage.setValue(key, value);
}
(:properties_and_storage,:background)
function deleteStorageValue(key as PropertyKeyType) as Void {
	Storage.deleteValue(key);
}

(:object_store)
function getPropertyValue(key as PropertyKeyType) as PropertyValueType {
	return App.getApp().getProperty(key);
}
(:object_store)
function setPropertyValue(key as PropertyKeyType, value as PropertyValueType) as Void {
	App.getApp().setProperty(key, value);
}
(:object_store)
function getStorageValue(key as PropertyKeyType) as PropertyValueType {
	return App.getApp().getProperty(key);
}
(:object_store)
function setStorageValue(key as PropertyKeyType, value as PropertyValueType) as Void {
	App.getApp().setProperty(key, value);
}
(:object_store)
function deleteStorageValue(key as PropertyKeyType) as Void {
	App.getApp().deleteProperty(key);
}

(:background)
class CrystalApp extends App.AppBase {

	var mView;
	var mFieldTypes as Array<Number?> = new [3];

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
		var value = getPropertyValue(key);
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
		if (location != null) {
			// Sys.println("Saving location");
			location = location.toDegrees(); // Array of Doubles.
			gLocationLat = location[0].toFloat();
			gLocationLng = location[1].toFloat();

			setStorageValue("LastLocationLat", gLocationLat);
			setStorageValue("LastLocationLng", gLocationLng);

		// If current location is not available, read stored value from Object Store, being careful not to overwrite a valid
		// in-memory value with an invalid stored one.
		} else {
			var lat = getStorageValue("LastLocationLat");
			if (lat != null) {
				gLocationLat = lat;
			}

			var lng = getStorageValue("LastLocationLng");
			if (lng != null) {
				gLocationLng = lng;
			}
		}
		// Sys.println(gLocationLat + ", " + gLocationLng);

		if (!(Sys has :ServiceDelegate)) {
			return;
		}

		var pendingWebRequests = getStorageValue("PendingWebRequests") as PendingWebRequests?;
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		// 1. City local time:
		// City has been specified.
		var city = getPropertyValue("LocalTimeInCity");
		
		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((city != null) && (city.length() > 0)) {

			var cityLocalTime = getStorageValue("CityLocalTime") as CityLocalTimeResponse?;

			// No existing data.
			if ((cityLocalTime == null) ||

			// Existing data is old.
			(((cityLocalTime as CityLocalTimeSuccessResponse)["next"] != null) && (Time.now().value() >= (cityLocalTime as CityLocalTimeSuccessResponse)["next"]["when"]))) {

				pendingWebRequests["CityLocalTime"] = true;
		
			// Existing data not for this city: delete it.
			// Error response from server: contains requestCity. Likely due to unrecognised city. Prevent requesting this
			// city again.
			} else if (!cityLocalTime["requestCity"].equals(city)) {

				deleteStorageValue("CityLocalTime");
				pendingWebRequests["CityLocalTime"] = true;
			}
		}

		// 2. Weather:
		// Location must be available, weather or humidity (#113) data field must be shown.
		if ((gLocationLat != null) &&
			(hasField(FIELD_TYPE_WEATHER) || hasField(FIELD_TYPE_HUMIDITY))) {

			var owmCurrent = getStorageValue("OpenWeatherMapCurrent") as OpenWeatherMapCurrentData?;

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

		// If there are any pending requests:
		if (pendingWebRequests.keys().size() > 0) {

			// Register for background temporal event as soon as possible.
			var lastTime = Bg.getLastTemporalEventTime();
			if (lastTime != null) {
				// Events scheduled for a time in the past trigger immediately.
				var nextTime = lastTime.add(new Time.Duration(5 * 60));
				Bg.registerForTemporalEvent(nextTime);
			} else {
				Bg.registerForTemporalEvent(Time.now());
			}
		}

		setStorageValue("PendingWebRequests", pendingWebRequests);
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
		var pendingWebRequests = getStorageValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			//Sys.println("onBackgroundData() called with no pending web requests!");
			pendingWebRequests = {};
		}

		var type = data.keys()[0]; // Type of received data.
		var storedData = getStorageValue(type);
		var receivedData = (data as Dictionary<String, CityLocalTimeData or OpenWeatherMapCurrentData or HttpErrorData>)[type]; // The actual data received: strip away type key.
		
		// No value in showing any HTTP error to the user, so no need to modify stored data.
		// Leave pendingWebRequests flag set, and simply return early.
		if (receivedData["httpError"]) {
			return;
		}

		// New data received: clear pendingWebRequests flag and overwrite stored data.
		storedData = receivedData;
		pendingWebRequests.remove(type);
		setStorageValue("PendingWebRequests", pendingWebRequests);
		setStorageValue(type, storedData);

		Ui.requestUpdate();
	}

	// Return a formatted time dictionary that respects is24Hour and HideHoursLeadingZero settings.
	// - hour: 0-23.
	// - min:  0-59.
	function getFormattedTime(hour, min) as FormattedTime {
		var amPm = "";

		if (!Sys.getDeviceSettings().is24Hour) {

			// #6 Ensure noon is shown as PM.
			var isPm = (hour >= 12);
			if (isPm) {
				
				// But ensure noon is shown as 12, not 00.
				if (hour > 12) {
					hour = hour - 12;
				}
				amPm = "pm";
			} else {
				
				// #27 Ensure midnight is shown as 12, not 00.
				if (hour == 0) {
					hour = 12;
				}
				amPm = "am";
			}
		}

		// #10 If in 12-hour mode with Hide Hours Leading Zero set, hide leading zero. Otherwise, show leading zero.
		// #69 Setting now applies to both 12- and 24-hour modes.
		hour = hour.format(getPropertyValue("HideHoursLeadingZero") ? INTEGER_FORMAT : "%02d");

		return {
			:hour => hour,
			:min => min.format("%02d"),
			:amPm => amPm
		};
	}
}
