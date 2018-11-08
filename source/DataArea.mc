using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DataArea extends Ui.Drawable {

	private var mRow1Y;
	private var mRow2Y;

	private var mLeftGoalCurrent;
	private var mLeftGoalMax;

	private var mRightGoalCurrent;
	private var mRightGoalMax;

	function initialize(params) {
		Drawable.initialize(params);

		mRow1Y = params[:row1Y];
		mRow2Y = params[:row2Y];
	}

	function setGoalValues(leftValues, rightValues) {
		if (leftValues[:isValid]) {
			mLeftGoalCurrent = leftValues[:current].format(INTEGER_FORMAT);
			if (App.getApp().getProperty("LeftGoalType") == GOAL_TYPE_BATTERY) {
				mLeftGoalMax = "%";
			} else {
				mLeftGoalMax = leftValues[:max].format(INTEGER_FORMAT);
			}
		} else {
			mLeftGoalCurrent = null;
			mLeftGoalMax = null;
		}

		if (rightValues[:isValid]) {
			mRightGoalCurrent = rightValues[:current].format(INTEGER_FORMAT);
			if (App.getApp().getProperty("RightGoalType") == GOAL_TYPE_BATTERY) {
				mRightGoalMax = "%";
			} else {
				mRightGoalMax = rightValues[:max].format(INTEGER_FORMAT);
			}
		} else {
			mRightGoalCurrent = null;
			mRightGoalMax = null;
		}
	}

	function draw(dc) {
		var city = App.getApp().getProperty("LocalTimeInCity");

		// Check for has :Storage, in case we're loading settings in the simulator from a different device.
		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((city != null) && (city.length() != 0) && (App has :Storage)) {
			//drawTimeZone();
			var cityLocalTime = App.Storage.getValue("CityLocalTime");

			// If available, use city returned from web request; otherwise, use raw city from settings.
			// N.B. error response will NOT contain city.
			if ((cityLocalTime != null) && (cityLocalTime["city"] != null)) {
				city = cityLocalTime["city"];
			}

			// Time zone 1 city.
			dc.setColor(gMonoDarkColour, Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				locX + (width / 2),
				mRow1Y,
				gNormalFont,
				// Limit string length.
				city.substring(0, 10),
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// Time zone 1 time.
			var time;
			if (cityLocalTime) {

				// Web request responded with server error e.g. unknown city.
				if (cityLocalTime["error"] != null) {

					time = "???";

				// Web request responded with time zone data for city.
				} else {
					var timeZoneGmtOffset;

					// Use next GMT offset if it's now applicable (new data will be requested shortly).
					if ((cityLocalTime["next"] != null) && (Time.now().value() >= cityLocalTime["next"]["when"])) {
						timeZoneGmtOffset = cityLocalTime["next"]["gmtOffset"];
					} else {
						timeZoneGmtOffset = cityLocalTime["current"]["gmtOffset"];
					}
					timeZoneGmtOffset = new Time.Duration(timeZoneGmtOffset);
					
					var localGmtOffset = Sys.getClockTime().timeZoneOffset;
					localGmtOffset = new Time.Duration(localGmtOffset);

					// (Local time) - (Local GMT offset) + (Time zone GMT offset)
					time = Time.now().subtract(localGmtOffset).add(timeZoneGmtOffset);
					time = Gregorian.info(time, Time.FORMAT_SHORT);
					time = App.getApp().getView().getFormattedTime(time.hour, time.min);
					time = time[:hour] + ":" + time[:min] + time[:amPm]; 
				}

			// Awaiting response to web request sent by BackgroundService.
			} else {
				time = "...";
			}

			dc.setColor(gMonoLightColour, Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				locX + (width / 2),
				mRow2Y,
				gNormalFont,
				time,
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

		} else {
			//drawGoalVales(dc);
			dc.setColor(gMonoLightColour, Gfx.COLOR_TRANSPARENT);

			if (mLeftGoalCurrent != null) {
				dc.drawText(
					locX,
					mRow1Y,
					gNormalFont,
					mLeftGoalCurrent,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			if (mRightGoalCurrent != null) {
				dc.drawText(
					locX + width,
					mRow1Y,
					gNormalFont,
					mRightGoalCurrent,
					Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			dc.setColor(gMonoDarkColour, Gfx.COLOR_TRANSPARENT);

			if (mLeftGoalMax != null) {
				dc.drawText(
					locX,
					mRow2Y,
					gNormalFont,
					mLeftGoalMax,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			if (mRightGoalMax != null) {
				dc.drawText(
					locX + width,
					mRow2Y,
					gNormalFont,
					mRightGoalMax,
					Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}
		}
	}
}
