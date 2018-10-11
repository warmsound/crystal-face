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
		checkBackgroundRequests();
		return [mView];
	}

	function getView() {
		return mView;
	}

	// New app settings have been received so trigger a UI update
	function onSettingsChanged() {
		mView.onSettingsChanged();
		checkBackgroundRequests();
		Ui.requestUpdate();
	}

	// Determine if any background request is needed, and register for temporal event if so.
	// TODO: Error handling.
	function checkBackgroundRequests() {
		var needed = false;
		
		if (Sys has :ServiceDelegate) {

			// Time zone request:
			// City has been specified.
			var timeZone1City = App.getApp().getProperty("TimeZone1City");
			if (timeZone1City.length() > 0) {

				var timeZone1 = App.Storage.getValue("TimeZone1");

				// No existing data.
				if (timeZone1 == null) {
					needed = true;

				// HTTP error: has error and responseCode (but no requestCity): keep retrying. Likely due to no connectivity.
				} else if ((timeZone1["error"] != null) && (timeZone1["error"]["responseCode"] != null)) {
					needed = true;
			
				// Existing data not for this city: delete it.
				// Error response from server: contains requestCity. Likely due to unrecognised city. Prevent requesting this
				// city again.
				} else if (!timeZone1["requestCity"].equals(timeZone1City)) {
					App.Storage.deleteValue("TimeZone1");
					needed = true;

				// Existing data is old.
				} else if ((timeZone1["next"] != null) && (Time.now().value() >= timeZone1["next"]["when"])) {
					needed = true;
				}
			}
		}

		if (needed) {

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
	}

	function getServiceDelegate() {
		return [new BackgroundService()];
	}

	// Sample time zone data:
	/*
	{
	"requestCity":"london",
	"city":"London",
	"current":{
		"gmtOffset":3600,
		"dst":true
		},
	"next":{
		"when":1540688400,
		"gmtOffset":0,
		"dst":false
		}
	}
	*/

	// Sample error when city is not found:
	/*
	{
	"requestCity":"atlantis",
	"error":{
		"code":2, // CITY_NOT_FOUND
		"message":"City \"atlantis\" not found."
		}
	}
	*/

	// Sample HTTP error:
	/*
	{
	"error":{
		"responseCode":404
		}
	}
	*/
	function onBackgroundData(data) {
		var timeZone1 = App.Storage.getValue("TimeZone1");

		// HTTP error with existing data: merge HTTP error into existing data, so that existing data can still be used while HTTP
		// error conditions exist e.g. roll onto next GMT offset while offline. checkBackgroundRequests() should retry on next
		// wake (or settings change), as long as timeZone1.error.responseCode is set.
		if ((timeZone1 != null) && (data["error"] != null) && (data["error"]["responseCode"] != null)) {
			timeZone1["error"] = data["error"];
			App.Storage.setValue("TimeZone1", timeZone1);

		// New data received: overwrite existing.
		} else {
			App.Storage.setValue("TimeZone1", data);
		}
		
		Ui.requestUpdate();
	}
}
