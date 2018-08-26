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
			if (App.getApp().getProperty("LeftGoalType") == -1) { // :GOAL_TYPE_BATTERY
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
			if (App.getApp().getProperty("RightGoalType") == -1) { // :GOAL_TYPE_BATTERY
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
		var timeZone1City = App.getApp().getProperty("TimeZone1City");
		if (timeZone1City != "") {
			//drawTimeZone();

			// Time zone 1 city.
			dc.setColor(App.getApp().getProperty("MonoDarkColour"), Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				locX + (width / 2),
				mRow1Y,
				mNormalFont,
				// Limit string length.
				timeZone1City.substring(0, 10),
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// Time zone 1 time.
			var timeZone1Time = "...";
			var timeZone1 = App.Storage.getValue("TimeZone1");
			if (timeZone1) {
				var timeZoneGmtOffset = timeZone1["current"]["gmtOffset"];
				timeZoneGmtOffset = new Time.Duration(timeZoneGmtOffset);
				
				var localGmtOffset = Sys.getClockTime().timeZoneOffset;
				localGmtOffset = new Time.Duration(localGmtOffset);

				// (Local time) - (Local GMT offset) + (Time zone GMT offset)
				timeZone1Time = Time.now().subtract(localGmtOffset).add(timeZoneGmtOffset);
				timeZone1Time = Gregorian.info(timeZone1Time, Time.FORMAT_SHORT);

				var amPm = "";
				var hour = timeZone1Time.hour;

				if (!Sys.getDeviceSettings().is24Hour) {
					var isPm = (hour >= 12);
					if (isPm) {
						// Show noon as 12, not 00.
						if (hour > 12) {
							hour = hour - 12;
						}
						amPm = "p";
					} else {
						// Show midnght as 12, not 00.
						if (hour == 0) {
							hour = 12;
						}
						amPm = "a";
					}
				}

				if (!App.getApp().getProperty("HideHoursLeadingZero")) {
					hour = hour.format("%02d");
				}				
				timeZone1Time = hour + ":" + timeZone1Time.min.format("%02d") + amPm;
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
