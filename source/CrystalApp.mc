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

	var mFieldTypes = new [3];
	var mGoalTypes = new [2];

	private var mUseComplications;

	function initialize() {
		AppBase.initialize();

		mFieldTypes[0] = {};
		mFieldTypes[1] = {};
		mFieldTypes[2] = {};

		mGoalTypes[0] = {};
		mGoalTypes[1] = {};

		gTeslaComplication = getBoolProperty("TeslaLink", false);

		// This code check if the user selected a different vehicle index in its property. If so, we'll need to get a new vehicleID
		var propVehicleIndex;
		var storVehicleIndex;

		try {
			propVehicleIndex = Properties.getValue("TeslaVehicleIndex");
		}
		catch (e) {
			propVehicleIndex = 1;
		}

		storVehicleIndex = Storage.getValue("TeslaVehiceIndex");
		if (storVehicleIndex == null || propVehicleIndex != storVehicleIndex) {
			storVehicleIndex = propVehicleIndex;
			try {
				Storage.setValue("TeslaVehiceIndex", storVehicleIndex);
				Storage.setValue("TeslaVehiceIndex", storVehicleIndex);
				Storage.setValue("TeslaVehicleID", null);
			}
			catch (e) {
			}
		}
	}

	// function onStart(state) {
	// 	/* DEBUG*/ logMessage("App starting");
	// }

	// function onStop(state) {
	// 	/* DEBUG*/ logMessage("App stopping");
	// }

	// Return the initial view of your application here
	function getInitialView() {
		/* DEBUG*/ logMessage("Getting initial view");

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
		/* DEBUG*/ logMessage("Getting service delegate");
		return [new BackgroundService()];
	}

	function onSettingsChanged() {
		mFieldTypes[0].put("type", $.getIntProperty("Field1Type", 0));
		mFieldTypes[1].put("type", $.getIntProperty("Field2Type", 1));
		mFieldTypes[2].put("type", $.getIntProperty("Field3Type", 2));

		mGoalTypes[0].put("type", $.getIntProperty("LeftGoalType", 0));
		mGoalTypes[1].put("type", $.getIntProperty("RightGoalType", 0));

		// We're not looking at the Complication sent by Tesla-Link and we have a refesh token, register for temporal events
		if (gTeslaComplication == false && $.getStringProperty("TeslaRefreshToken", "").length() > 0) {
			var lastTime = Bg.getLastTemporalEventTime();
			if (lastTime) {
				// Events scheduled for a time in the past trigger immediately.
				var nextTime = lastTime.add(new Time.Duration(5 * 60));
				Bg.registerForTemporalEvent(nextTime);
			} else {
				Bg.registerForTemporalEvent(Time.now());
			}
		}
		else {
			Bg.deleteTemporalEvent();
		}

		mView.onSettingsChanged(); // Calls checkPendingWebRequests().

		// Reread our complications if we're allowed
		if (Toybox has :Complications) {
			// First we drop all our subscriptions before building a new list
			Complications.unsubscribeFromAllUpdates();
			// We listen for complications if we're allowed
			Complications.registerComplicationChangeCallback(mView.useComplications() ? self.method(:onComplicationUpdated) : null);
		}

		Ui.requestUpdate();
	}

	// Handle data received from BackgroundService.
	// On success, clear appropriate pendingWebRequests flag.
	// data is Dictionary with single key that indicates the data type received. This corresponds with Object Store and
	// pendingWebRequests keys.
	(:background_method)
	function onBackgroundData(data) {
		var receivedData = data["TeslaInfo"]; // What we just received
		
		var teslaInfo = Storage.getValue("TeslaInfo"); // What we have in Storage
		if (teslaInfo == null) {
			teslaInfo = {};
		}

		// Update in TeslaInfo what has been received in receivedData
		var keys = receivedData.keys();
		var values = receivedData.values();
		for (var i = 0; i < keys.size(); i++) {
			teslaInfo.put(keys[i], values[i]);
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

	function hasField(fieldType) {
		return ((mFieldTypes[0].get("type") == fieldType) ||
				(mFieldTypes[1].get("type") == fieldType) ||
				(mFieldTypes[2].get("type") == fieldType));
	}

    function onComplicationUpdated(complicationId) {
		var complication = Complications.getComplication(complicationId);
		var complicationType = complication.getType();
		var complicationShortLabel = complication.shortLabel;
		//DEBUG*/ var complicationLongLabel = complication.longLabel;
		var complicationValue = complication.value;

		//DEBUG*/ if (complicationType == Complications.COMPLICATION_TYPE_STEPS) {
			//DEBUG*/ logMessage("Type: " + complicationType + " short label: " + complicationShortLabel + " long label: " + complicationLongLabel + " Value:" + complicationValue);
		//DEBUG*/ }

		if (complicationType == Complications.COMPLICATION_TYPE_INVALID && complicationShortLabel != null && complicationShortLabel.equals("TESLA")) {
			$.doTeslaComplication(complicationValue);
		}

		// I've seen this while in low power mode, so skip it
		if (complicationValue == null) {
			//DEBUG*/ logMessage("We got a Complication value of null for " + complicationType);
			return;
		}

		// Do fields first
		var fieldCount = $.getIntProperty("FieldCount", 3);

		for (var i = 0; i < fieldCount; i++) {
			if (mFieldTypes[i].get("ComplicationType") == complicationType) {
				mFieldTypes[i].put("ComplicationValue", complicationValue);
			}
		}

		// Now do goals
		if (mGoalTypes[0].get("ComplicationType") == complicationType) {
			mGoalTypes[0].put("ComplicationValue", complicationValue);
		}
		if (mGoalTypes[1].get("ComplicationType") == complicationType) {
			mGoalTypes[1].put("ComplicationValue", complicationValue);
		}
    }
}
