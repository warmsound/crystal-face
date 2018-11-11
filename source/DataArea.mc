using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DataArea extends Ui.Drawable {

	private var mRow1Y;
	private var mRow2Y;

	private var mLeftGoalType;
	private var mLeftGoalIsValid;
	private var mLeftGoalCurrent;
	private var mLeftGoalMax;

	private var mRightGoalType;
	private var mRightGoalIsValid;
	private var mRightGoalCurrent;
	private var mRightGoalMax;

	private var mGoalIconY;
	private var mGoalIconLeftX;
	private var mGoalIconRightX;

	function initialize(params) {
		Drawable.initialize(params);

		mRow1Y = params[:row1Y];
		mRow2Y = params[:row2Y];

		mGoalIconY = params[:goalIconY];
		mGoalIconLeftX = params[:goalIconLeftX];
		mGoalIconRightX = params[:goalIconRightX];
	}

	function setGoalValues(leftType, leftValues, rightType, rightValues) {
		mLeftGoalType = leftType;
		mLeftGoalIsValid = leftValues[:isValid];

		if (leftValues[:isValid]) {
			mLeftGoalCurrent = leftValues[:current].format(INTEGER_FORMAT);
			if (mLeftGoalType == GOAL_TYPE_BATTERY) {
				mLeftGoalMax = "%";
			} else {
				mLeftGoalMax = leftValues[:max].format(INTEGER_FORMAT);
			}
		} else {
			mLeftGoalCurrent = null;
			mLeftGoalMax = null;
		}

		mRightGoalType = rightType;
		mRightGoalIsValid = rightValues[:isValid];

		if (rightValues[:isValid]) {
			mRightGoalCurrent = rightValues[:current].format(INTEGER_FORMAT);
			if (mRightGoalType == GOAL_TYPE_BATTERY) {
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
		drawGoalIcon(dc, mGoalIconLeftX, mLeftGoalType, mLeftGoalIsValid, Graphics.TEXT_JUSTIFY_LEFT);
		drawGoalIcon(dc, mGoalIconRightX, mRightGoalType, mRightGoalIsValid, Graphics.TEXT_JUSTIFY_RIGHT);

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
			drawGoalValues(dc, locX, mLeftGoalCurrent, mLeftGoalMax, Graphics.TEXT_JUSTIFY_LEFT);
			drawGoalValues(dc, locX + width, mRightGoalCurrent, mRightGoalMax, Graphics.TEXT_JUSTIFY_RIGHT);
		}
	}

	function drawGoalIcon(dc, x, type, isValid, align) {
		var icon = {
			GOAL_TYPE_BATTERY => "9",
			GOAL_TYPE_CALORIES => "6",
			GOAL_TYPE_STEPS => "0",
			GOAL_TYPE_FLOORS_CLIMBED => "1",
			GOAL_TYPE_ACTIVE_MINUTES => "2",
		}[type];

		var colour;
		if (isValid) {
			colour = gThemeColour;
		} else {
			colour = gMeterBackgroundColour;
		}

		dc.setColor(colour, Gfx.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mGoalIconY,
			gIconsFont,
			icon,
			align
		);
	}

	function drawGoalValues(dc, x, currentValue, maxValue, align) {
		if (currentValue != null) {
			dc.setColor(gMonoLightColour, Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mRow1Y,
				gNormalFont,
				currentValue,
				align | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}

		if (maxValue != null) {
			dc.setColor(gMonoDarkColour, Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mRow2Y,
				gNormalFont,
				maxValue,
				align | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
	}
}
