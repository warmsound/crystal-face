using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Complications;

class Indicators extends Ui.Drawable {

	var mSpacing;
	var mIsHorizontal = false;
	var mBatteryWidth;

	var mIndicator1Type;
	var mIndicator2Type;
	var mIndicator3Type;

	// private enum /* INDICATOR_TYPES */ {
	// 	INDICATOR_TYPE_BLUETOOTH,
	// 	INDICATOR_TYPE_ALARMS,
	// 	INDICATOR_TYPE_NOTIFICATIONS,
	// 	INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS,
	// 	INDICATOR_TYPE_BATTERY
	// }

	function initialize(params) {
		Drawable.initialize(params);

		if (params[:spacingX] != null) {
			mSpacing = params[:spacingX];
			mIsHorizontal = true;
		} else {
			mSpacing = params[:spacingY];
		}
		mBatteryWidth = params[:batteryWidth];

		onSettingsChanged();
	}

	function onSettingsChanged() {
		mIndicator1Type = $.getIntProperty("Indicator1Type", 5);
		mIndicator2Type = $.getIntProperty("Indicator2Type", 3);
		mIndicator3Type = $.getIntProperty("Indicator3Type", 0);

//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
		var teslaIndicator;
		if (mIndicator1Type == 6) {
			teslaIndicator = 1;
		}
		if (mIndicator2Type == 6) {
			teslaIndicator = 2;
		}
		if (mIndicator3Type == 6) {
			teslaIndicator = 3;
		}
		if (teslaIndicator != null) {
			//DEBUG*/ logMessage("onSettingsChanged:Doing Tesla!");
			Storage.setValue("Tesla", true);
			if (App.getApp().getView().useComplications()) {
				$.updateComplications("Tesla-Link", "Complication_I", teslaIndicator, Complications.COMPLICATION_TYPE_INVALID);
			}
		} else {
			Storage.deleteValue("Tesla");
			teslaIndicator = 0;
		}

		for (var i = 1; i < 4; i++) {
			if (i != teslaIndicator) {
				Storage.deleteValue("Complication_I" + i);
			}
		}
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************
	}

	function draw(dc) {

		// #123 Protect against null or unexpected type e.g. String.
		var indicatorCount = $.getIntProperty("IndicatorCount", 1);

		// Horizontal layout for rectangle-148x205.
		if (mIsHorizontal) {
			drawHorizontal(dc, indicatorCount);

		// Vertical layout for others.
		} else {
			drawVertical(dc, indicatorCount);
		}
	}

	(:horizontal_indicators)
	function drawHorizontal(dc, indicatorCount) {
		if (indicatorCount == 3) {
			drawIndicator(dc, mIndicator1Type, locX - mSpacing, locY);
			drawIndicator(dc, mIndicator2Type, locX, locY);
			drawIndicator(dc, mIndicator3Type, locX + mSpacing, locY);
		} else if (indicatorCount == 2) {
			drawIndicator(dc, mIndicator1Type, locX - (mSpacing / 2), locY);
			drawIndicator(dc, mIndicator2Type, locX + (mSpacing / 2), locY);
		} else if (indicatorCount == 1) {
			drawIndicator(dc, mIndicator1Type, locX, locY);
		}
	}

	(:vertical_indicators)
	function drawVertical(dc, indicatorCount) {

		/*var spacingY = mSpacing;
		var spacingX = mBatteryWidth * 2;

		var xlocX = locX - (mBatteryWidth / 1.5).toNumber();
		var ylocY;
		if (indicatorCount == 1) {
			ylocY = locY - spacingY;
			spacingY *= 2;
		}
		else {
			ylocY = locY - spacingY / 2;
		}*/

		if (indicatorCount == 3) {
			drawIndicator(dc, mIndicator1Type, locX, locY - mSpacing);
			drawIndicator(dc, mIndicator2Type, locX, locY);
			drawIndicator(dc, mIndicator3Type, locX, locY + mSpacing);
			// dc.drawRectangle(xlocX, ylocY - spacingY, spacingX, spacingY);
			// dc.drawRectangle(xlocX, ylocY, spacingX, spacingY);
			// dc.drawRectangle(xlocX, ylocY + spacingY, spacingX, spacingY);
		} else if (indicatorCount == 2) {
			drawIndicator(dc, mIndicator1Type, locX, locY - (mSpacing / 2));
			drawIndicator(dc, mIndicator2Type, locX, locY + (mSpacing / 2));
			// dc.drawRectangle(xlocX, ylocY - spacingY / 2, spacingX, spacingY);
			// dc.drawRectangle(xlocX, ylocY + spacingY / 2, spacingX, spacingY);
		} else if (indicatorCount == 1) {
			drawIndicator(dc, mIndicator1Type, locX, locY);
			// dc.drawRectangle(xlocX, ylocY, spacingX, spacingY);
		}
	}

	function drawIndicator(dc, indicatorType, x, y) {

		// Battery indicator.
		if (indicatorType == 4 /* INDICATOR_TYPE_BATTERY */) {
			$.drawBatteryMeter(dc, x, y, mBatteryWidth, mBatteryWidth / 2);
			return;
		}

		if (indicatorType == 5 /* INDICATOR_TYPE_BATTERY_NUMERIC */) {
			$.writeBatteryLevel(dc, x, y, mBatteryWidth, mBatteryWidth / 2, 0);
			return;
		}

//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
		if (indicatorType == 6 /* INDICATOR_TYPE_TESLA */) { // We're reusing the watch batterie indicator to show the Tesla's batterie level
			$.writeBatteryLevel(dc, x, y, mBatteryWidth, mBatteryWidth / 2, 1); 
			return;
		}

//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************

		// Show notifications icon if connected and there are notifications, bluetoothicon otherwise.
		var settings = Sys.getDeviceSettings();
		if (indicatorType == 3 /* INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS */) {
			if (settings.phoneConnected && (settings.notificationCount > 0)) {
				indicatorType = 2; // INDICATOR_TYPE_NOTIFICATIONS
			} else {
				indicatorType = 0; // INDICATOR_TYPE_BLUETOOTH
			}
		}
		else if (indicatorType == 7) {
			indicatorType = 3;
		}

		// Get value for indicator type.
		var value = [
			/* INDICATOR_TYPE_BLUETOOTH */ settings.phoneConnected,
			/* INDICATOR_TYPE_ALARMS */ settings.alarmCount > 0,
			/* INDICATOR_TYPE_NOTIFICATIONS */ settings.notificationCount > 0,
			/* Do Not Disturb */ settings has :doNotDisturb && settings.doNotDisturb
		][indicatorType];

		dc.setColor(value ? gThemeColour : gMeterBackgroundColour, Graphics.COLOR_TRANSPARENT);

		// Icon.
		dc.drawText(
			x,
			y,
			gIconsFont,
			["8", ":", "5", "C"][indicatorType], // Get icon font char for indicator type.
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
}
