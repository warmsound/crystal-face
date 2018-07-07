using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;

const INDICATOR_1_TYPE = "Indicator1Type";
const INDICATOR_2_TYPE = "Indicator2Type";
const INDICATOR_3_TYPE = "Indicator3Type";

class Indicators extends Ui.Drawable {

	private var mIconsFont;
	private var mSpacingX;
	private var mSpacingY;

	private var INDICATOR_TYPES = [
		:INDICATOR_TYPE_BLUETOOTH,
		:INDICATOR_TYPE_ALARMS,
		:INDICATOR_TYPE_NOTIFICATIONS,
		:INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS
	];

	function initialize(params) {
		Drawable.initialize(params);

		mSpacingX = params[:spacingX];
		mSpacingY = params[:spacingY];
	}

	function setFont(iconsFont) {
		mIconsFont = iconsFont;
	}

	function draw(dc) {

		// Vertical layout.
		if (mSpacingX) {
			switch (App.getApp().getProperty("IndicatorCount")) {
				case 3:
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_1_TYPE), locX - mSpacingX, locY);
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_2_TYPE), locX, locY);
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_3_TYPE), locX + mSpacingX, locY);
					break;
				case 2:
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_1_TYPE), locX - (mSpacingX / 2), locY);
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_2_TYPE), locX + (mSpacingX / 2), locY);
					break;
				case 1:
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_1_TYPE), locX, locY);
					break;
				case 0:
					break;
			}

		// Horizontal layout.
		} else if (mSpacingY) {
			switch (App.getApp().getProperty("IndicatorCount")) {
				case 3:
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_1_TYPE), locX, locY - mSpacingY);
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_2_TYPE), locX, locY);
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_3_TYPE), locX, locY + mSpacingY);
					break;
				case 2:
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_1_TYPE), locX, locY - (mSpacingY / 2));
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_2_TYPE), locX, locY + (mSpacingY / 2));
					break;
				case 1:
					drawIndicator(dc, App.getApp().getProperty(INDICATOR_1_TYPE), locX, locY);
					break;
				case 0:
					break;
			}
		}
	}

	function drawIndicator(dc, rawIndicatorType, x, y) {
		var indicatorType = INDICATOR_TYPES[rawIndicatorType];
		var value = getValueForIndicatorType(indicatorType);

		var colour;
		if (value) {
			colour = App.getApp().getProperty("ThemeColour");
		} else {
			colour = App.getApp().getProperty("MeterBackgroundColour");
		}
		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);

		// Show notifications icon if connected and there are notifications, bluetoothicon otherwise.
		if (indicatorType == :INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS) {
			var settings = Sys.getDeviceSettings();
			if (settings.phoneConnected && (settings.notificationCount > 0)) {
				indicatorType = :INDICATOR_TYPE_NOTIFICATIONS;
			} else {
				indicatorType = :INDICATOR_TYPE_BLUETOOTH;
			}
		}

		// Icon.
		dc.drawText(
			x,
			y,
			mIconsFont,
			App.getApp().getInitialView()[0].getIconFontChar(indicatorType),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}

	function getValueForIndicatorType(type) {
		var value = false;

		var settings = Sys.getDeviceSettings();

		switch (type) {
			case :INDICATOR_TYPE_BLUETOOTH:
			case :INDICATOR_TYPE_BLUETOOTH_OR_NOTIFICATIONS:
				value = settings.phoneConnected;
				break;

			case :INDICATOR_TYPE_ALARMS:
				value = (settings.alarmCount > 0);
				break;

			case :INDICATOR_TYPE_NOTIFICATIONS:
				value = (settings.notificationCount > 0);
				break;
		}

		return value;
	}
}
