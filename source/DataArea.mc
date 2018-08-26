using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;

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
		/* if (App.getApp().getProperty("TimeZone1City") != "") {
			//drawTimeZone();
		} else */ {
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
