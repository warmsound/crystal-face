using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;

class Indicators extends Ui.Drawable {

	private var mIconsFont;
	private var mSpacingY;
	private var mBatteryWidth;
	private var mBatteryHeight;

	private var mIndicator1Type;
	private var mIndicator2Type;
	private var mIndicator3Type;

	private enum /* INDICATOR_TYPES */ {
		INDICATOR_TYPE_BLUETOOTH,
		INDICATOR_TYPE_ALARMS,
		INDICATOR_TYPE_NOTIFICATIONS,
		INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS,
		INDICATOR_TYPE_BATTERY
	}

	function initialize(params) {
		Drawable.initialize(params);

		mSpacingY = params[:spacingY];
		mBatteryWidth = params[:batteryWidth];
		mBatteryHeight = params[:batteryHeight];

		onSettingsChanged();
	}

	function setFont(iconsFont) {
		mIconsFont = iconsFont;
	}

	function onSettingsChanged() {
		mIndicator1Type = App.getApp().getProperty("Indicator1Type");
		mIndicator2Type = App.getApp().getProperty("Indicator2Type");
		mIndicator3Type = App.getApp().getProperty("Indicator3Type");
	}

	function draw(dc) {
		var indicatorCount = App.getApp().getProperty("IndicatorCount");
		if (indicatorCount == 3) {
			drawIndicator(dc, mIndicator1Type, locX, locY - mSpacingY);
			drawIndicator(dc, mIndicator2Type, locX, locY);
			drawIndicator(dc, mIndicator3Type, locX, locY + mSpacingY);
		} else if (indicatorCount == 2) {
			drawIndicator(dc, mIndicator1Type, locX, locY - (mSpacingY / 2));
			drawIndicator(dc, mIndicator2Type, locX, locY + (mSpacingY / 2));
		} else if (indicatorCount == 1) {
			drawIndicator(dc, mIndicator1Type, locX, locY);
		}
	}

	function drawIndicator(dc, indicatorType, x, y) {

		// Battery indicator.
		if (indicatorType == INDICATOR_TYPE_BATTERY) {
			App.getApp().getView().drawBatteryMeter(dc, x, y, mBatteryWidth, mBatteryHeight);
			return;
		}

		var value = getValueForIndicatorType(indicatorType);

		var colour;
		if (value) {
			colour = App.getApp().getProperty("ThemeColour");
		} else {
			colour = App.getApp().getProperty("MeterBackgroundColour");
		}
		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);

		// Show notifications icon if connected and there are notifications, bluetoothicon otherwise.
		if (indicatorType == INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS) {
			var settings = Sys.getDeviceSettings();
			if (settings.phoneConnected && (settings.notificationCount > 0)) {
				indicatorType = INDICATOR_TYPE_NOTIFICATIONS;
			} else {
				indicatorType = INDICATOR_TYPE_BLUETOOTH;
			}
		}

		/*
		var iconFontChar;
		switch (indicatorType) {
			case INDICATOR_TYPE_BLUETOOTH:
				iconFontChar = "8";
				break;
			case INDICATOR_TYPE_ALARMS:
				iconFontChar = ":";
				break;
			case INDICATOR_TYPE_NOTIFICATIONS:
				iconFontChar = "5";
				break;
		}
		*/

		// Icon.
		dc.drawText(
			x,
			y,
			mIconsFont,
			["8", ":", "5"][indicatorType], // iconFontChar
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}

	function getValueForIndicatorType(type) {
		var value = false;

		var settings = Sys.getDeviceSettings();

		switch (type) {
			case INDICATOR_TYPE_BLUETOOTH:
			case INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS:
				value = settings.phoneConnected;
				break;

			case INDICATOR_TYPE_ALARMS:
				value = (settings.alarmCount > 0);
				break;

			case INDICATOR_TYPE_NOTIFICATIONS:
				value = (settings.notificationCount > 0);
				break;
		}

		return value;
	}
}
