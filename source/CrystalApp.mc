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

var gTeslaComplication = false;

(:background)
class CrystalApp extends App.AppBase {
	var mView;

	function initialize() {
		AppBase.initialize();
	}

	// function onStart(state) {
	// 	/*DEBUG*/ logMessage("App starting");
	// }

	// function onStop(state) {
	// 	/*DEBUG*/ logMessage("App stopping");
	// }

	// Return the initial view of your application here
	function getInitialView() {
		//DEBUG*/ logMessage("Getting initial view");

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

	// Handle data received from BackgroundService.
	// On success, clear appropriate pendingWebRequests flag.
	// data is Dictionary with single key that indicates the data type received. This corresponds with Object Store and
	// pendingWebRequests keys.
	(:background_method)
	function onBackgroundData(data) {
		var teslaInfo = Storage.getValue("TeslaInfo"); // What we have in Storage
		if (teslaInfo == null) {
			teslaInfo = {};
		}

		// Update in TeslaInfo what has been received in receivedData
		var receivedData = data["TeslaInfo"]; // What we just received
		if (receivedData != null && receivedData instanceof Lang.Dictionary) {
			var keys = receivedData.keys();
			var values = receivedData.values();
			for (var i = 0; i < keys.size(); i++) {
				teslaInfo.put(keys[i], values[i]);
			}
		}
		else {
			//DEBUG*/ logMessage("Unexpected invalid receivedData: " + receivedData);
		}

		// Copy into their own name some of the entries in TeslaInfo, then delete from TeslaInfo
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

		// Now store our updated copy of TeslaInfo
		Storage.setValue("TeslaInfo", teslaInfo);

		// We deal with specific errors here, leaving the good stuff to the battery indicator
		var responseCode = teslaInfo["httpErrorTesla"];
		var internalResponseCode = teslaInfo["httpInternalErrorTesla"];
		if (responseCode != null && internalResponseCode != null) {
			if (responseCode == 401 && internalResponseCode != 200) { // Our token has expired and we were unable to get one, refresh it
				Properties.setValue("TeslaAccessToken", null); // Try to get a new vehicleID
			} else if (responseCode == 404 && internalResponseCode != 200) { // We got a vehicle not found error and we were unable to get one, reset our vehicle ID
				Storage.remove("VehicleID"); // Try to get a new vehicleID
			}
		}

		Ui.requestUpdate();
	}
}
