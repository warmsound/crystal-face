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

		gTeslaComplication = $.getBoolProperty("TeslaLink", false);
	}

	// function onStart(state) {
	// 	/*DEBUG*/ logMessage("App starting");
	// }

	// function onStop(state) {
	// 	/*DEBUG*/ logMessage("App stopping");
	// }

	// Return the initial view of your application here
	function getInitialView() {
		/*DEBUG*/ logMessage("Getting initial view");

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
	(:background)
	function getServiceDelegate() {
		//DEBUG*/ logMessage("Getting service delegate");
		return [new BackgroundService()];
	}

	function onSettingsChanged() {
		// This code check if the user selected a different vehicle index in its property. If so, we'll need to get a new vehicleID
		var propVehicleIndex;
		var storVehicleIndex;

		propVehicleIndex = $.getIntProperty("TeslaVehicleIndex", 1);

		storVehicleIndex = Storage.getValue("TeslaVehicleIndex");
		if (storVehicleIndex == null || propVehicleIndex != storVehicleIndex) {
			storVehicleIndex = propVehicleIndex;
			try {
				Storage.setValue("TeslaVehicleIndex", storVehicleIndex);
				Storage.setValue("TeslaVehicleID", null);
			}
			catch (e) {
			}
		}

		mView.onSettingsChanged(); // Calls checkPendingWebRequests().

		Ui.requestUpdate();
	}


	(:background)
	function onBackgroundData(data) {
		/*DEBUG*/ logMessage("onBackgroundData:received '" + data + "'");
		var pendingWebRequests = Storage.getValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		if (data == null) {
			/*DEBUG*/ logMessage("onBackgroundData:data is null");
			return;
		}

		if (data.isEmpty()) {
			/*DEBUG*/ logMessage("onBackgroundData:Empty data");
			return;
		}

		for (var keyIndex = 0; keyIndex < data.size(); keyIndex++) {
			var type = data.keys()[keyIndex]; // Type of received data.
			var storedData = Storage.getValue(type);
			if (storedData == null) {
				storedData = {};
			}
			var receivedData = data[type]; // The actual data received: strip away type key.
			
			// Do process the data if what we got was an error
			if (receivedData["httpError"] == null) {
				// New data received: clear pendingWebRequests flag and overwrite stored data that with what we received, leaving others intact.
				// storedData = receivedData;
				var keys = receivedData.keys();
				var values = receivedData.values();
				for (var i = 0; i < keys.size(); i++) {
					storedData.put(keys[i], values[i]);
				}

				storedData.put("NewData", true);
				Storage.setValue(type, storedData);

				pendingWebRequests.remove(type);
			}

			// No benifit of doing this now as it adds code to the background process that can be done in the main view instead
			// checkPendingWebRequests(); // We just got new data, process them right away before displaying
		}

		Storage.setValue("PendingWebRequests", pendingWebRequests);

		/*DEBUG*/ logMessage("onBackgroundData:Flag that requests are pending");
		Storage.setValue("RequestsPending", true);
		Ui.requestUpdate();
	}
	// Handle data received from BackgroundService.
	// data is Dictionary with single key that indicates the data type received.
	// (:background)
	// function onBackgroundData(data) {
	// 	var teslaInfo = Storage.getValue("TeslaInfo"); // What we have in Storage
	// 	if (teslaInfo == null) {
	// 		teslaInfo = {};
	// 	}

	// 	// Update in TeslaInfo what has been received in receivedData
	// 	var receivedData = data["TeslaInfo"]; // What we just received
	// 	if (receivedData != null && receivedData instanceof Lang.Dictionary) {
	// 		var keys = receivedData.keys();
	// 		var values = receivedData.values();
	// 		for (var i = 0; i < keys.size(); i++) {
	// 			teslaInfo.put(keys[i], values[i]);
	// 		}
	// 	}
	// 	else {
	// 		/*DEBUG*/ logMessage("Unexpected invalid receivedData: " + receivedData);
	// 	}

	// 	// Copy into their own name some of the entries in TeslaInfo, then delete from TeslaInfo
	// 	var arrayKey = ["RefreshToken", "AccessToken", "TokenCreatedAt", "TokenExpiresIn", "VehicleID"];
	// 	var arrayProp = [true, true, false, false, false ];
	// 	for (var i = 0; i < arrayKey.size(); i++) {
	// 		var value = teslaInfo.get(arrayKey[i]);
	// 		if (value != null) {
	// 			if (arrayProp[i]) {
	// 				Properties.setValue("Tesla" + arrayKey[i], value);
	// 			}
	// 			else {
	// 				Storage.setValue("Tesla" + arrayKey[i], value);
	// 			}
	// 			teslaInfo.remove(arrayKey[i]);
	// 		}
	// 	}

	// 	// Now store our updated copy of TeslaInfo
	// 	Storage.setValue("TeslaInfo", teslaInfo);

	// 	// We deal with specific errors here, leaving the good stuff to the battery indicator
	// 	var responseCode = teslaInfo["httpErrorTesla"];
	// 	var internalResponseCode = teslaInfo["httpInternalErrorTesla"];
	// 	if (responseCode != null && internalResponseCode != null) {
	// 		if (responseCode == 401 && internalResponseCode != 200) { // Our token has expired and we were unable to get one, refresh it
	// 			Properties.setValue("TeslaAccessToken", null); // Try to get a new vehicleID
	// 		} else if (responseCode == 404 && internalResponseCode != 200) { // We got a vehicle not found error and we were unable to get one, reset our vehicle ID
	// 			Storage.deleteValue("VehicleID"); // Try to get a new vehicleID
	// 		}
	// 	}

	// 	/*DEBUG*/ var nextTime = Time.now().add(new Time.Duration(5 * 60)); var local = Gregorian.info(nextTime, Time.FORMAT_SHORT); var time = $.getFormattedTime(local.hour, local.min, local.sec); 		logMessage("Next event: " + time[:hour] + ":" + time[:min] + ":" + time[:sec] + time[:amPm]);
	// 	Bg.registerForTemporalEvent(new Time.Duration(5 * 60)); // Since onSettingsChanged go for a specific time, go for duration here once we get going, otherwise we'll get background data only once the view is shown

	// 	Ui.requestUpdate();
	// }
}
