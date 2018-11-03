using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;

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
	// Currently called on initialisation, when settings change, and on exiting sleep.
	function checkPendingWebRequests() {

		// Attempt to updated stored location, to be used by Sunrise/Sunset, and Weather.
		var lat, lng;
		var location = Activity.getActivityInfo().currentLocation;
		if (location) {
			location = location.toDegrees(); // Array of Doubles.
			lat = location[0].toFloat();
			lng = location[1].toFloat();

			// Save current location, in case it goes "stale" and can not longer be retrieved from current activity.
			App.getApp().setProperty("LastLocationLat", lat);
			App.getApp().setProperty("LastLocationLng", lng);
		} else {
			lat = App.getApp().getProperty("LastLocationLat");
			lng = App.getApp().getProperty("LastLocationLng");
		}

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
		// Location must be available.
		if (lat != -360) {

			// Weather data field must be shown.
			if (mView.mDataFields.hasField(FIELD_TYPE_WEATHER)) {

				var owmCurrent = App.Storage.getValue("OpenWeatherMapCurrent");

				// No existing data.
				if (owmCurrent == null) {

					pendingWebRequests["OpenWeatherMapCurrent"] = true;

				// Successfully received weather data.
				} else if (owmCurrent["cod"] == 200) {

					// Existing data is older than an hour.
					if ((Time.now().value() > (owmCurrent["dt"] + 3600)) ||

					// Existing data not for this location.
					// Not a great test, as a degree of longitude varies betwee 69 (equator) and 0 (pole) miles, but simpler than
					// true distance calculation. 0.02 degree of latitude is just over a mile.
					(((lat - owmCurrent["lat"]).abs() > 0.02) || ((lng - owmCurrent["lon"]).abs() > 0.02))) {

						pendingWebRequests["OpenWeatherMapCurrent"] = true;
					}
				}
				// TODO: Else if "invalid API key" response, and user has since changed key.
				// TODO: Should we ever delete weather data?
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
