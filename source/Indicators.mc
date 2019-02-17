using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;

class Indicators extends Ui.Drawable {

	private var mSpacing;
	private var mIsHorizontal = false;

	private var mIndicator1Type;
	private var mIndicator2Type;
	private var mIndicator3Type;

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

		onSettingsChanged();
	}

	function onSettingsChanged() {
		mIndicator1Type = App.getApp().getProperty("Indicator1Type");
		mIndicator2Type = App.getApp().getProperty("Indicator2Type");
		mIndicator3Type = App.getApp().getProperty("Indicator3Type");
	}

	function draw(dc) {
		var indicatorCount = App.getApp().getProperty("IndicatorCount");

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
		if (indicatorCount == 3) {
			drawIndicator(dc, mIndicator1Type, locX, locY - mSpacing);
			drawIndicator(dc, mIndicator2Type, locX, locY);
			drawIndicator(dc, mIndicator3Type, locX, locY + mSpacing);
		} else if (indicatorCount == 2) {
			drawIndicator(dc, mIndicator1Type, locX, locY - (mSpacing / 2));
			drawIndicator(dc, mIndicator2Type, locX, locY + (mSpacing / 2));
		} else if (indicatorCount == 1) {
			drawIndicator(dc, mIndicator1Type, locX, locY);
		}
	}

	function drawIndicator(dc, indicatorType, x, y) {

		// Battery indicator.
		if (indicatorType == 4 /* INDICATOR_TYPE_BATTERY */) {
			if (Sys.getDeviceSettings().screenShape == Sys.SCREEN_SHAPE_ROUND) {
				drawBatteryMeter(dc, x, y, 24, 12);
			} else {
				drawBatteryMeter(dc, x, y, 20, 10);
			}
			return;
		}

		// Show notifications icon if connected and there are notifications, bluetoothicon otherwise.
		var settings = Sys.getDeviceSettings();
		if (indicatorType == 3 /* INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS */) {
			if (settings.phoneConnected && (settings.notificationCount > 0)) {
				indicatorType = 2; // INDICATOR_TYPE_NOTIFICATIONS
			} else {
				indicatorType = 0; // INDICATOR_TYPE_BLUETOOTH
			}
		}

		// Get value for indicator type.
		var value = [
			/* INDICATOR_TYPE_BLUETOOTH */ settings.phoneConnected,
			/* INDICATOR_TYPE_ALARMS */ settings.alarmCount > 0,
			/* INDICATOR_TYPE_NOTIFICATIONS */ settings.notificationCount > 0
		][indicatorType];

		// Special exception for bluetooth. If bluetooth is disabled, don't draw indicator at all
		if (indicatorType == 0 && getBluetoothConnectionState() == 0 /*System.CONNECTION_STATE_DISABLED*/) {
			return;
		}

		var colour;
		if (value) {
			colour = gThemeColour;
		} else {
			colour = gMeterBackgroundColour;
		}
		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);

		// Icon.
		dc.drawText(
			x,
			y,
			gIconsFont,
			["8", ":", "5"][indicatorType], // Get icon font char for indicator type.
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
	
	// Get the tri-state bluetooth status:
	//   CONNECTION_STATE_DISABLED (0), CONNECTION_STATE_NOT_CONNECTED (1), CONNECTION_STATE_CONNECTED (2)
	private var haveBluetoothConnectionInfo = null;
	function getBluetoothConnectionState() {
		if (haveBluetoothConnectionInfo == null) {
			var deviceSettings = System.getDeviceSettings();
			if (deviceSettings has :connectionInfo && deviceSettings.connectionInfo[:bluetooth] != null) {
			   haveBluetoothConnectionInfo = true;
			} else {
			   haveBluetoothConnectionInfo = false;
			}
		}
		
		if (haveBluetoothConnectionInfo) {
			return System.getDeviceSettings().connectionInfo[:bluetooth].state;
		}
		
		return null;
	}	
}
