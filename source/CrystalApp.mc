using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Time;

// In-memory current location.
// Important for CIQ 1.x watches that only support Object Store, where stored location is overwritten with default when user
// changes any setting (this happens for any properties that do not have corresponding setting). Object Store is still useful for
// when user moves away from watch face and returns to it.
var gLocationLat = -360.0; // -360.0 is a special value, meaning "unitialised". Can't have null float property.
var gLocationLng = -360.0; // -360.0 is a special value, meaning "unitialised". Can't have null float property.

(:background)
class CrystalApp extends App.AppBase {

	var mView;

	function initialize() {
		AppBase.initialize();		
	}

	// onStart() is called on application start up
	function onStart(state) {
	}

	// onStop() is called when your application is exiting
	function onStop(state) {
	}

	// Return the initial view of your application here
	function getInitialView() {
		mView = new CrystalView();
		return [mView];
	}

	function getView() {
		return mView;
	}

	// New app settings have been received so trigger a UI update
	function onSettingsChanged() {
		mView.onSettingsChanged();
		checkPendingWebRequests();
		Ui.requestUpdate();
	}

	// Determine if any web requests are needed.
	// If so, set approrpiate pendingWebRequests flag for use by BackgroundService, then register for
	// temporal event.
	// Currently called on layout initialisation, when settings change, and on exiting sleep.
	function checkPendingWebRequests() {

		// Attempt to update current location, to be used by Sunrise/Sunset, and Weather.
		// If current location available from current activity, save it in case it goes "stale" and can not longer be retrieved.
		var location = Activity.getActivityInfo().currentLocation;
		if (location) {
			// Sys.println("Saving location");
			location = location.toDegrees(); // Array of Doubles.
			gLocationLat = location[0].toFloat();
			gLocationLng = location[1].toFloat();

			// Use App.Storage if possible, as this is not overwritten with default property value (-360.0) when user changes any
			// setting.
			if (App has :Storage) {
				App.Storage.setValue("LastLocationLat", gLocationLat);
				App.Storage.setValue("LastLocationLng", gLocationLng);
			} else {
				App.getApp().setProperty("LastLocationLat", gLocationLat);
				App.getApp().setProperty("LastLocationLng", gLocationLng);
			}

		// If current location is not available, read stored value from Storage or Object Store, being careful not to overwrite
		// a valid in-memory value with an invalid stored one.
		} else {
			var lat, lng;
			if (App has :Storage) {
				// Most likely null if location has not yet been saved to Storage: leave value at -360.0.
				lat = App.Storage.getValue("LastLocationLat");
				if (lat != null) {
					gLocationLat = lat;
				}
				lng = App.Storage.getValue("LastLocationLng");
				if (lng != null) {
					gLocationLng = lng;
				}
			} else {
				// Gets reset to -360.0 as soon as settings are changed, because this property has no corresponding setting.
				lat = App.getApp().getProperty("LastLocationLat");
				if (lat != -360.0) {
					gLocationLat = lat;
				}
				lng = App.getApp().getProperty("LastLocationLng");
				if (lng != -360) {
					gLocationLng = lng;
				}
			}
		}
		// Sys.println(gLocationLat + ", " + gLocationLng);

		if (!((Sys has :ServiceDelegate) && (App has :Storage))) {
			return;
		}

		var pendingWebRequests = App.Storage.getValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		// 1. City local time:
		// City has been specified.
		var city = App.getApp().getProperty("LocalTimeInCity");
		
		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((city != null) && (city.length() > 0)) {

			var cityLocalTime = App.Storage.getValue("CityLocalTime");

			// No existing data.
			if ((cityLocalTime == null) ||

			// Existing data is old.
			((cityLocalTime["next"] != null) && (Time.now().value() >= cityLocalTime["next"]["when"]))) {

				pendingWebRequests["CityLocalTime"] = true;
		
			// Existing data not for this city: delete it.
			// Error response from server: contains requestCity. Likely due to unrecognised city. Prevent requesting this
			// city again.
			} else if (!cityLocalTime["requestCity"].equals(city)) {

				App.Storage.deleteValue("CityLocalTime");
				pendingWebRequests["CityLocalTime"] = true;
			}
		}

		// 2. Weather:
		// Location must be available, weather data field must be shown.
		if ((gLocationLat != -360.0) && mView.mDataFields.hasField(FIELD_TYPE_WEATHER)) {

			var owmCurrent = App.Storage.getValue("OpenWeatherMapCurrent");

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
			if (lastTime) {
				// Events scheduled for a time in the past trigger immediately.
				var nextTime = lastTime.add(new Time.Duration(5 * 60));
				Bg.registerForTemporalEvent(nextTime);
			} else {
				Bg.registerForTemporalEvent(Time.now());
			}
		}

		App.Storage.setValue("PendingWebRequests", pendingWebRequests);
	}

	function getServiceDelegate() {
		return [new BackgroundService()];
	}

	// Handle data received from BackgroundService.
	// On success, clear appropriate pendingWebRequests flag.
	// data is Dictionary with single key that indicates the data type received. This corresponds with App.Storage and
	// pendingWebRequests keys.
	function onBackgroundData(data) {
		var pendingWebRequests = App.Storage.getValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			//Sys.println("onBackgroundData() called with no pending web requests!");
			pendingWebRequests = {};
		}

		var type = data.keys()[0]; // Type of received data.
		var storedData = App.Storage.getValue(type);
		var receivedData = data[type]; // The actual data received: strip away type key.
		
		// No value in showing any HTTP error to the user, so no need to modify stored data.
		// Leave pendingWebRequests flag set, and simply return early.
		if (receivedData["httpError"]) {
			return;
		}

		// New data received: clear pendingWebRequests flag and overwrite stored data.
		storedData = receivedData;
		pendingWebRequests.remove(type);
		App.Storage.setValue("PendingWebRequests", pendingWebRequests);
		App.Storage.setValue(type, storedData);

		Ui.requestUpdate();
	}
}
