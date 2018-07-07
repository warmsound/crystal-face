using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Application as App;

class Indicators extends Ui.Drawable {

	private var mIconsFont;
	private var mSpacing;

	private var INDICATOR_TYPES = [
		:INDICATOR_TYPE_BLUETOOTH,
		:INDICATOR_TYPE_ALARMS,
		:INDICATOR_TYPE_NOTIFICATIONS
	];

	function initialize(params) {
		Drawable.initialize(params);

		mSpacing = params[:spacing];
	}

	function setFont(iconsFont) {
		mIconsFont = iconsFont;
	}

	function draw(dc) {
		switch (App.getApp().getProperty("IndicatorCount")) {
			case 3:
				drawIndicator(dc, App.getApp().getProperty("Indicator1Type"), locY - mSpacing);
				drawIndicator(dc, App.getApp().getProperty("Indicator2Type"), locY);
				drawIndicator(dc, App.getApp().getProperty("Indicator3Type"), locY + mSpacing);
				break;
			case 2:
				drawIndicator(dc, App.getApp().getProperty("Indicator1Type"), locY - (mSpacing / 2));
				drawIndicator(dc, App.getApp().getProperty("Indicator2Type"), locY + (mSpacing / 2));
				break;
			case 1:
				drawIndicator(dc, App.getApp().getProperty("Indicator1Type"), locY);
				break;
			case 0:
				break;
		}
	}

	// "indicatorType" parameter is raw property value (it's converted to symbol below).
	function drawIndicator(dc, indicatorType, y) {
		var value = getValueForIndicatorType(indicatorType);
		var colour;

		if (value) {
			colour = App.getApp().getProperty("ThemeColour");
		} else {
			colour = App.getApp().getProperty("MeterBackgroundColour");			
		}

		// Icon.
		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			locX,
			y,
			mIconsFont,
			App.getApp().getInitialView()[0].getIconFontChar(INDICATOR_TYPES[indicatorType]),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}

	// "type" parameter is raw property value (it's converted to symbol below).
	// Return empty string if value cannot be retrieved (e.g. unavailable, or unsupported).
	function getValueForIndicatorType(type) {
		var value = false;

		var settings = Sys.getDeviceSettings();

		switch (INDICATOR_TYPES[type]) {
			case :INDICATOR_TYPE_BLUETOOTH:
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
