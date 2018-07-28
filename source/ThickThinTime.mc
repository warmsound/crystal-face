using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

	private var mThemeColour, mBackgroundColour;
	private var mHoursFont, mMinutesFont, mSecondsFont;

	// "y" parameter passed to drawText(), read from layout.xml.
	private var mSecondsY;
	
	// Vertical layouts only: offset between bottom of hours and top of minutes.
	private var mVerticalOffset;

	// Tight clipping rectangle for drawing seconds during partial update.
	// "y" corresponds to top of glyph, which will be lower than "y" parameter of drawText().
	// drawText() starts from the top of the font ascent, which is above the top of most glyphs.
	private var mSecondsClipRectX;
	private var mSecondsClipRectY;
	private var mSecondsClipRectWidth;
	private var mSecondsClipRectHeight;

	private var mHideSeconds = false;

	private var mAnteMeridiem, mPostMeridiem;
	private var AM_PM_X_OFFSET = 2;
	private var mMeridiemSide;

	// #10 Adjust position of seconds to compensate for hidden hours leading zero.
	private var mSecondsClipXAdjust = 0;

	function initialize(params) {
		Drawable.initialize(params);

		mVerticalOffset = params[:verticalOffset];

		mSecondsY = params[:secondsY];

		mSecondsClipRectX = params[:secondsX];
		mSecondsClipRectY = params[:secondsClipY];
		mSecondsClipRectWidth = params[:secondsClipWidth];
		mSecondsClipRectHeight = params[:secondsClipHeight];

		mAnteMeridiem = Ui.loadResource(Rez.Strings.AnteMeridiem);
		mPostMeridiem = Ui.loadResource(Rez.Strings.PostMeridiem);

		mMeridiemSide = params[:meridiemSide];
	}

	function setFonts(hoursFont, minutesFont, secondsFont) {
		mHoursFont = hoursFont;
		mMinutesFont = minutesFont;
		mSecondsFont = secondsFont;
	}

	function setHideSeconds(hideSeconds) {
		mHideSeconds = hideSeconds;
	}
	
	function draw(dc) {
		mThemeColour = App.getApp().getProperty("ThemeColour");
		mBackgroundColour = App.getApp().getProperty("BackgroundColour");

		drawHoursMinutes(dc);
		drawSeconds(dc, /* isPartialUpdate */ false);
	}

	function drawHoursMinutes(dc) {    		
		var clockTime = Sys.getClockTime();
		var hours = clockTime.hour;
		var minutes = clockTime.min.format("%02d");

		var is24Hour = Sys.getDeviceSettings().is24Hour;
		var isPm = false;
		var amPmText = "";

		if (!is24Hour) {

			// #6 Ensure noon is shown as PM.
			if (hours >= 12) {
				isPm = true;

				// But ensure noon is shown as 12, not 00.
				if (hours > 12) {
					hours = hours % 12;
				}

			// #27 Ensure midnight is shown as 12, not 00.
			} else if (hours == 0) {
				hours = 12;
			}
							
			if (isPm) {
				amPmText = mPostMeridiem;
			} else {
				amPmText = mAnteMeridiem;
			}
		}

		// #10 If in 12-hour mode with Hide Hours Leading Zero set, hide leading zero.
		var isLeadingZeroHidden;
		if (!is24Hour && App.getApp().getProperty("HideHoursLeadingZero")) {
			hours = hours.format("%d");

		// Otherwise, show leading zero.
		} else {
			hours = hours.format("%02d");
		}
		isLeadingZeroHidden = (hours.length() == 1);

		var x;
		var halfDCWidth = dc.getWidth() / 2;
		var halfDCHeight = dc.getHeight() / 2;

		// Vertical (two-line) layout.
		if (mVerticalOffset) {

			// N.B. Font metrics have been manually adjusted in .fnt files so that ascent = glyph height.
			var hoursAscent = Graphics.getFontAscent(mHoursFont);

			// #10 hours may be single digit, but calculate layout as if always double-digit.
			// N.B. Assumes font has tabular (monospaced) numerals.
			var maxHoursWidth = dc.getTextWidthInPixels(/* hours */ "00", mHoursFont);
			x = halfDCWidth + (maxHoursWidth / 2); // Right edge of double-digit hours.

			// Draw hours, horizontally centred if double-digit, vertically bottom aligned.
			dc.setColor(App.getApp().getProperty("HoursColour"), Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				halfDCHeight - hoursAscent - (mVerticalOffset / 2),
				mHoursFont,
				hours,
				Graphics.TEXT_JUSTIFY_RIGHT
			);

			// Draw minutes, horizontally centred, vertically top aligned.
			dc.setColor(App.getApp().getProperty("MinutesColour"), Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				halfDCHeight + (mVerticalOffset / 2),
				mMinutesFont,
				minutes,
				Graphics.TEXT_JUSTIFY_RIGHT
			);

			x += AM_PM_X_OFFSET; // Breathing space between minutes and AM/PM.

			// If required, draw AM/PM after hours, vertically centred.
			if (!is24Hour) {
				dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x,
					halfDCHeight - (hoursAscent / 2) - (mVerticalOffset / 2),
					mSecondsFont,
					amPmText,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

		// Horizontal (single-line) layout.
		} else {

			// Centre combined hours and minutes text (not the same as right-aligning hours and left-aligning minutes).
			// Font has tabular figures (monospaced numbers) even across different weights, so does not matter which of hours or
			// minutes font is used to calculate total width. 
			var totalWidth = dc.getTextWidthInPixels(hours + minutes, mHoursFont);
			x = halfDCWidth - (totalWidth / 2);

			// Draw hours.
			dc.setColor(App.getApp().getProperty("HoursColour"), Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				halfDCHeight,
				mHoursFont,
				hours,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
			x += dc.getTextWidthInPixels(hours, mHoursFont);

			// Draw minutes.
			dc.setColor(App.getApp().getProperty("MinutesColour"), Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				halfDCHeight,
				mMinutesFont,
				minutes,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// If required, draw AM/PM after minutes, or before hours, vertically centred.
			if (!is24Hour) {
				dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);

				if (mMeridiemSide == :left) {
					dc.drawText(
						halfDCWidth - (totalWidth / 2) - AM_PM_X_OFFSET - 2, // Breathing space between minutes and AM/PM.
						halfDCHeight,
						mSecondsFont,
						amPmText,
						Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
					);

					// #10 If mMeridiemSide is left, then assume this is a rectangle-205x148 layout, i.e. single-line layout with
					// seconds immediately to right of minutes (rather than beneath minutes).
					// If no leading hours zero is shown, move seconds left by half the width of an hours character.
					// N.B. Assumes font has tabular (monospaced) numerals.
					if (isLeadingZeroHidden) {
						mSecondsClipXAdjust = -dc.getTextWidthInPixels("0", mHoursFont) / 2;
					} else {
						mSecondsClipXAdjust = 0;
					}
					
				} else {
					x = x + dc.getTextWidthInPixels(minutes, mMinutesFont);
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
	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// If isPartialUpdate flag is set to true, strictly limit the updated screen area: set clip rectangle before clearing old text
	// and drawing new. Clipping rectangle should not change between seconds.
	function drawSeconds(dc, isPartialUpdate) {
		if (mHideSeconds) {
			return;
		}
		
		var clockTime = Sys.getClockTime();
		var seconds = clockTime.sec.format("%02d");

		if (isPartialUpdate) {

			dc.setClip(
				mSecondsClipRectX + mSecondsClipXAdjust,
				mSecondsClipRectY,
				mSecondsClipRectWidth,
				mSecondsClipRectHeight
			);

			// Can't optimise setting colour once, at start of low power mode, at this goes wrong on real hardware: alternates
			// every second with inverse (e.g. blue text on black, then black text on blue).
			dc.setColor(mThemeColour, /* Graphics.COLOR_RED */ mBackgroundColour);	

			// Clear old rect (assume nothing overlaps seconds text).
			dc.clear();

		} else {

			// Drawing will not be clipped, so ensure background is transparent in case font height overlaps with another
			// drawable.
			dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);
		}

		dc.drawText(
			mSecondsClipRectX + mSecondsClipXAdjust,
			mSecondsY,
			mSecondsFont,
			seconds,
			Graphics.TEXT_JUSTIFY_LEFT
		);	
	}
}