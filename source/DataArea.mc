using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DataArea extends Ui.Drawable {

	private var mRow1Y;
	private var mRow2Y;

	private var mNormalFont;

	private var mLeftGoalCurrent;
	private var mLeftGoalMax;

	private var mRightGoalCurrent;
	private var mRightGoalMax;

	function initialize(params) {
		Drawable.initialize(params);

		mRow1Y = params[:row1Y];
		mRow2Y = params[:row2Y];
	}

	function setFont(normalFont) {
		mNormalFont = normalFont;
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
		var localTimeInCity = App.getApp().getProperty("LocalTimeInCity");

		// Check for has :Storage, in case we're loading settings in the simulator from a different device.
		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((localTimeInCity != null) && (localTimeInCity.length() != 0) && (App has :Storage)) {
			//drawTimeZone();
			var timeZone1 = App.Storage.getValue("CityLocalTime");

			// If available, use city returned from web request; otherwise, use raw city from settings.
			// N.B. error response will NOT contain city.
			if ((timeZone1 != null) && (timeZone1["city"] != null)) {
				localTimeInCity = timeZone1["city"];
			}

			// Time zone 1 city.
			dc.setColor(App.getApp().getProperty("MonoDarkColour"), Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				locX + (width / 2),
				mRow1Y,
				mNormalFont,
				// Limit string length.
				localTimeInCity.substring(0, 10),
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// Time zone 1 time.
			var timeZone1Time;
			if (timeZone1) {

				// Web request responded with HTTP or server error.
				if (timeZone1["error"] != null) {

					// HTTP error: show response code (no i18n).
					if (timeZone1["error"]["responseCode"] != null) {
						timeZone1Time = timeZone1["error"]["responseCode"] + " error";

					// Server error: e.g. unknown city.
					} else {
						timeZone1Time = "???";
					}

				// Web request responded with time zone data for city.
				} else {
					var timeZoneGmtOffset;

					// Use next GMT offset if it's now applicable (new data will be requested shortly).
					if ((timeZone1["next"] != null) && (Time.now().value() >= timeZone1["next"]["when"])) {
						timeZoneGmtOffset = timeZone1["next"]["gmtOffset"];
					} else {
						timeZoneGmtOffset = timeZone1["current"]["gmtOffset"];
					}
					timeZoneGmtOffset = new Time.Duration(timeZoneGmtOffset);
					
					var localGmtOffset = Sys.getClockTime().timeZoneOffset;
					localGmtOffset = new Time.Duration(localGmtOffset);

					// (Local time) - (Local GMT offset) + (Time zone GMT offset)
					timeZone1Time = Time.now().subtract(localGmtOffset).add(timeZoneGmtOffset);
					timeZone1Time = Gregorian.info(timeZone1Time, Time.FORMAT_SHORT);
					timeZone1Time = App.getApp().getView().getFormattedTime(timeZone1Time.hour, timeZone1Time.min);
					timeZone1Time = timeZone1Time[:hour] + ":" + timeZone1Time[:min] + timeZone1Time[:amPm]; 
				}

			// Awaiting response to web request sent by BackgroundService.
			} else {
				timeZone1Time = "...";
			}

			dc.setColor(App.getApp().getProperty("MonoLightColour"), Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				locX + (width / 2),
				mRow2Y,
				mNormalFont,
				timeZone1Time,
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

		} else {
			//drawGoalVales(dc);
			dc.setColor(App.getApp().getProperty("MonoLightColour"), Gfx.COLOR_TRANSPARENT);

			if (mLeftGoalCurrent != null) {
				dc.drawText(
					locX,
					mRow1Y,
					mNormalFont,
					mLeftGoalCurrent,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			if (mRightGoalCurrent != null) {
				dc.drawText(
					locX + width,
					mRow1Y,
					mNormalFont,
					mRightGoalCurrent,
					Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			dc.setColor(App.getApp().getProperty("MonoDarkColour"), Gfx.COLOR_TRANSPARENT);

			if (mLeftGoalMax != null) {
				dc.drawText(
					locX,
					mRow2Y,
					mNormalFont,
					mLeftGoalMax,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			if (mRightGoalMax != null) {
				dc.drawText(
					locX + width,
					mRow2Y,
					mNormalFont,
					mRightGoalMax,
					Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}
		}
	}
}
