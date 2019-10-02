using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class AlwaysOnDisplay extends Ui.Drawable {

	private var mHoursFont, mMinutesFont, mSecondsFont, mDateFont;

	// Wide rectangle: time should be moved up slightly to centre within available space.
	private var mAdjustY = 0;

	private var AM_PM_X_OFFSET = 2;

	function initialize(params) {
		Drawable.initialize(params);

		if (params[:adjustY] != null) {
			mAdjustY = params[:adjustY];
		}

		if (params[:amPmOffset] != null) {
			AM_PM_X_OFFSET = params[:amPmOffset];
		}

		mHoursFont = Ui.loadResource(Rez.Fonts.AlwaysOnHoursFont);
		mMinutesFont = Ui.loadResource(Rez.Fonts.AlwaysOnMinutesFont);
		mSecondsFont = Ui.loadResource(Rez.Fonts.AlwaysOnSecondsFont);
        mDateFont = Ui.loadResource(Rez.Fonts.AlwaysOnDateFont);
	}
	
	function draw(dc) {
		drawHoursMinutes(dc);
	}

	function drawHoursMinutes(dc) {
		var clockTime = Sys.getClockTime();
		var formattedTime = App.getApp().getView().getFormattedTime(clockTime.hour, clockTime.min);
		formattedTime[:amPm] = formattedTime[:amPm].toUpper();

		var hours = formattedTime[:hour];
		var minutes = formattedTime[:min];
		var amPmText = formattedTime[:amPm];

		var x;
		var halfDCWidth = dc.getWidth() / 2;
		var halfDCHeight = (dc.getHeight() / 2) + mAdjustY;

		// Centre combined hours and minutes text (not the same as right-aligning hours and left-aligning minutes).
		// Font has tabular figures (monospaced numbers) even across different weights, so does not matter which of hours or
		// minutes font is used to calculate total width. 
		var totalWidth = dc.getTextWidthInPixels(hours + minutes, mHoursFont);
		x = halfDCWidth - (totalWidth / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

		// Draw hours.		
		dc.drawText(
			x,
			halfDCHeight,
			mHoursFont,
			hours,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		x += dc.getTextWidthInPixels(hours, mHoursFont);

		// Draw minutes.
		dc.drawText(
			x,
			halfDCHeight,
			mMinutesFont,
			minutes,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// If required, draw AM/PM after minutes, vertically centred.
		if (amPmText.length() > 0) {
			x += dc.getTextWidthInPixels(minutes, mMinutesFont);
			dc.drawText(
				x + AM_PM_X_OFFSET, // Breathing space between minutes and AM/PM.
				halfDCHeight,
				mSecondsFont,
				amPmText,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
	}
}