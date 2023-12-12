using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

class DataArea extends Ui.Drawable {

	private var mRow0Y;
	private var mRow1Y;
	private var mRow2Y;

	private var mLeftGoalType;
	private var mLeftGoalIsValid;
	private var mLeftGoalstaled;
	private var mLeftGoalCurrent;
	private var mLeftGoalMax;

	private var mRightGoalType;
	private var mRightGoalIsValid;
	private var mRightGoalstaled;
	private var mRightGoalCurrent;
	private var mRightGoalMax;

	var mGoalIconY;
	var mGoalIconLeftX;
	var mGoalIconRightX;

	function initialize(params) {
		Drawable.initialize(params);

		mRow0Y = params[:row0Y];
		mRow1Y = params[:row1Y];
		mRow2Y = params[:row2Y];

		mGoalIconY = params[:goalIconY];
		mGoalIconLeftX = params[:goalIconLeftX];
		mGoalIconRightX = params[:goalIconRightX];
	}

	function setGoalValues(leftType, leftValues, rightType, rightValues) {
		mLeftGoalType = leftType;
		mLeftGoalIsValid = leftValues[:isValid];
		mLeftGoalstaled = leftValues[:staled];

		if (leftValues[:isValid] && (leftValues[:current] instanceof Lang.Number || leftValues[:current] instanceof Lang.Float) && (leftValues[:max] instanceof Lang.Number || leftValues[:max] instanceof Lang.Float) ) {
			mLeftGoalCurrent = leftValues[:current].format(INTEGER_FORMAT);
			mLeftGoalMax = (mLeftGoalType == GOAL_TYPE_BATTERY || mLeftGoalType == GOAL_TYPE_BODY_BATTERY || mLeftGoalType == GOAL_TYPE_STRESS_LEVEL) ? "%" : leftValues[:max].format(INTEGER_FORMAT);
		} else {
			if (leftValues[:isValid]) {
				/*DEBUG*/ logMessage("Should have been screened, why invalid? " + leftValues[:current] + " - " + leftValues[:max]);
			}
			mLeftGoalCurrent = null;
			mLeftGoalMax = null;
		}

		mRightGoalType = rightType;
		mRightGoalIsValid = rightValues[:isValid];
		mRightGoalstaled = leftValues[:staled];

		if (rightValues[:isValid] && (rightValues[:current] instanceof Lang.Number || rightValues[:current] instanceof Lang.Float) && (rightValues[:max] instanceof Lang.Number || rightValues[:max] instanceof Lang.Float) ) {
			mRightGoalCurrent = rightValues[:current].format(INTEGER_FORMAT);
			mRightGoalMax = (mRightGoalType == GOAL_TYPE_BATTERY || mRightGoalType == GOAL_TYPE_BODY_BATTERY || mRightGoalType == GOAL_TYPE_STRESS_LEVEL) ? "%" : rightValues[:max].format(INTEGER_FORMAT);
		} else {
			if (rightValues[:isValid]) {
				/*DEBUG*/ logMessage("Should have been screened, why invalid? " + rightValues[:current] + " - " + rightValues[:max]);
			}
			mRightGoalCurrent = null;
			mRightGoalMax = null;
		}
	}

	function draw(dc) {
		drawGoalIcon(dc, mGoalIconLeftX, mLeftGoalType, mLeftGoalIsValid, mLeftGoalstaled, Graphics.TEXT_JUSTIFY_LEFT);
		drawGoalIcon(dc, mGoalIconRightX, mRightGoalType, mRightGoalIsValid, mRightGoalstaled, Graphics.TEXT_JUSTIFY_RIGHT);

		var view = App.getApp().getView();
		var city = view.mWeatherStationName;
		if (view.mShowWeatherStationName && city != null && city.length() > 0) {
			dc.setColor(gMonoDarkColour, Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				locX + (width / 2),
				mRow0Y,
				gNormalFont,
				// Limit string length.
				city.substring(0, 16),
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}

		// #78 Setting with value of empty string may cause corresponding property to be null.
		city = view.mLocalCityName;
		if (city != null && city.length() > 0) {
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
			if (view.mLocalCityLat != null && view.mLocalCityLat >= -90.0 && view.mLocalCityLat <= 90.0 && view.mLocalCityLon != null && view.mLocalCityLon >= -180.0 && view.mLocalCityLon <= 180.0) {
				try {
					var where = new Position.Location({
						:latitude  => view.mLocalCityLat,
						:longitude => view.mLocalCityLon,
						:format    => :degrees
					});


					var local = Gregorian.localMoment(where, Time.now());
					local = Gregorian.info(local, Time.FORMAT_SHORT);

					time = $.getFormattedTime(local.hour, local.min, local.sec);
					time = time[:hour] + ":" + time[:min] + time[:amPm]; 
				}
				catch (e) {
					time = "???";
				}
			}
			else {
				time = "???";
			}

			dc.setColor(gMonoLightColour, Gfx.COLOR_TRANSPARENT);
			dc.drawText(
				locX + (width / 2),
				mRow2Y,
				gNormalFont,
				time,
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
		else {
			drawGoalValues(dc, locX, mLeftGoalCurrent, mLeftGoalMax, Graphics.TEXT_JUSTIFY_LEFT);
			drawGoalValues(dc, locX + width, mRightGoalCurrent, mRightGoalMax, Graphics.TEXT_JUSTIFY_RIGHT);
		}

		/*var spacingX = Sys.getDeviceSettings().screenWidth / 11;
		var spacingY = Sys.getDeviceSettings().screenHeight / 6;

		var left = mGoalIconLeftX - spacingX / 8;
		var right = mGoalIconRightX + spacingX / 8;
		var y = mGoalIconY - spacingY / 8;

		dc.drawRectangle(left, y, spacingX * 3, spacingY);
		dc.drawRectangle(right - spacingX * 3, y, spacingX * 3, spacingY);*/
	}

	function drawGoalIcon(dc, x, type, isValid, staled, align) {
		if (type == GOAL_TYPE_OFF) {
			return;
		}
		
		var icon = {
			GOAL_TYPE_BATTERY => "9",
			GOAL_TYPE_CALORIES => "6",
			GOAL_TYPE_STEPS => "0",
			GOAL_TYPE_FLOORS_CLIMBED => "1",
			GOAL_TYPE_ACTIVE_MINUTES => "2",
			GOAL_TYPE_BODY_BATTERY => "E", // SG Addition
			GOAL_TYPE_STRESS_LEVEL => "G", // SG Addition
		}[type];

		dc.setColor(isValid && !staled ? gThemeColour : gMeterBackgroundColour, Gfx.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mGoalIconY,
			gIconsFont,
			icon,
			align
		);
	}

	function drawGoalValues(dc, x, currentValue, maxValue, align) {
        //DEBUG*/ var myStats = Sys.getSystemStats(); logMessage("Total memory: " + myStats.totalMemory + " Used memory: " + myStats.usedMemory + " Free memory: " + myStats.freeMemory);
		var digitStyle = App.getApp().getView().mDigitStyle;

		// #107 Only draw values if digit style is not Hidden.
		if (digitStyle != 2 /* HIDDEN */) {
			if (currentValue != null) {
				dc.setColor(gMonoLightColour, Gfx.COLOR_TRANSPARENT);
				dc.drawText(
					x,

					// #107 Draw current value vertically centred if digit style is Current (i.e. not drawing max/target).
					(digitStyle == 1 /* CURRENT */) ? ((mRow1Y + mRow2Y) / 2) : mRow1Y,

					gNormalFont,
					currentValue,
					align | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			// #107 Only draw max/target goal value if digit style is set to Current/Target.
			if ((maxValue != null) && (digitStyle == 0) /* CURRENT_TARGET */) {
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
}
