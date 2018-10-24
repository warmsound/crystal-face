using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

	private var mThemeColour, mBackgroundColour;
	private var mLastHours, mHoursFont0, mHoursFont1;
	private var mMinutesFont, mSecondsFont;

	// "y" parameter passed to drawText(), read from layout.xml.
	private var mSecondsY;
	
	// Vertical layouts only: offset between bottom of hours and top of minutes.
	private var mTwoLineOffset;

	// Wide rectangle: time should be moved up slightly to centre within available space.
	private var mAdjustY = 0;

	// Tight clipping rectangle for drawing seconds during partial update.
	// "y" corresponds to top of glyph, which will be lower than "y" parameter of drawText().
	// drawText() starts from the top of the font ascent, which is above the top of most glyphs.
	private var mSecondsClipRectX;
	private var mSecondsClipRectY;
	private var mSecondsClipRectWidth;
	private var mSecondsClipRectHeight;

	private var mHideSeconds = false;
	private var AM_PM_X_OFFSET = 2;

	// #10 Adjust position of seconds to compensate for hidden hours leading zero.
	private var mSecondsClipXAdjust = 0;

	function initialize(params) {
		Drawable.initialize(params);

		mTwoLineOffset = params[:twoLineOffset];

		if (params[:adjustY] != null) {
			mAdjustY = params[:adjustY];
		}

		mSecondsY = params[:secondsY];

		mSecondsClipRectX = params[:secondsX];
		mSecondsClipRectY = params[:secondsClipY];
		mSecondsClipRectWidth = params[:secondsClipWidth];
		mSecondsClipRectHeight = params[:secondsClipHeight];

		mMinutesFont = Ui.loadResource(Rez.Fonts.MinutesFont);
		mSecondsFont = Ui.loadResource(Rez.Fonts.SecondsFont);
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

	function getFontIDForHoursDigit(char) {
		/*
		switch (char) {
			default:
			case '0':
				return Rez.Fonts.HoursFont0;
			case '1':
				return Rez.Fonts.HoursFont1;
			case '2':
				return Rez.Fonts.HoursFont2;
			case '3':
				return Rez.Fonts.HoursFont3;
			case '4':
				return Rez.Fonts.HoursFont4;
			case '5':
				return Rez.Fonts.HoursFont5;
			case '6':
				return Rez.Fonts.HoursFont6;
			case '7':
				return Rez.Fonts.HoursFont7;
			case '8':
				return Rez.Fonts.HoursFont8;
			case '9':
				return Rez.Fonts.HoursFont9;
		}
		*/
		var f = Rez.Fonts;
		var hoursFonts = [
			f.HoursFont0,
			f.HoursFont1,
			f.HoursFont2,
			f.HoursFont3,
			f.HoursFont4,
			f.HoursFont5,
			f.HoursFont6,
			f.HoursFont7,
			f.HoursFont8,
			f.HoursFont9,
		];
		return hoursFonts[char.toString().toNumber()];
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
				amPmText = "P";
			} else {
				amPmText = "A";
			}
		}

		// #10 If in 12-hour mode with Hide Hours Leading Zero set, hide leading zero.
		// #69 Setting now applies to both 12- and 24-hour modes.
		if (/* !is24Hour && */ App.getApp().getProperty("HideHoursLeadingZero")) {
			hours = hours.format(INTEGER_FORMAT);

		// Otherwise, show leading zero.
		} else {
			hours = hours.format("%02d");
		}
		
		// #19 Save memory by loading single character subset font(s) for hours.
		// If hour is changing, reload fonts. Old fonts should be garbage collected.
		if (!hours.equals(mLastHours)) {
			mLastHours = hours;
			hours = hours.toCharArray();
			mHoursFont0 = Ui.loadResource(getFontIDForHoursDigit(hours[0]));
			if (hours.size() == 2) { // Double-digit.
				if (hours[1].equals(hours[0])) { // "11", "22".
					mHoursFont1 = mHoursFont0;
				} else {
					mHoursFont1 = Ui.loadResource(getFontIDForHoursDigit(hours[1]));
				}
			} else {
				mHoursFont1 = null;
			}
		} else {
			hours = hours.toCharArray();
		}

		var y;
		var halfDCWidth = dc.getWidth() / 2;
		var halfDCHeight = (dc.getHeight() / 2) + mAdjustY;

		// Font has tabular figures (monospaced numbers) even across different weights, so can use minutes font (not
			// subsetted) to calculate char width. 
		var charWidth = dc.getTextWidthInPixels("0", mMinutesFont);

		// Vertical (two-line) layout.
		if (mTwoLineOffset) {

			
			// N.B. Font metrics have been manually adjusted in .fnt files so that ascent = glyph height.
			var hoursAscent = Graphics.getFontAscent(mMinutesFont);
			y = halfDCHeight - hoursAscent - (mTwoLineOffset / 2); 

			// Draw hours, horizontally centred if double-digit, vertically bottom aligned.
			dc.setColor(App.getApp().getProperty("HoursColour"), Graphics.COLOR_TRANSPARENT);
			if (hours.size() == 2) {
				dc.drawText(
					halfDCWidth,
					y,
					mHoursFont0,
					hours[0],
					Graphics.TEXT_JUSTIFY_RIGHT
				);
				dc.drawText(
					halfDCWidth,
					y,
					mHoursFont1,
					hours[1],
					Graphics.TEXT_JUSTIFY_LEFT
				);			
			// #10 hours may be single digit, but calculate layout as if always double-digit.
			} else {
				dc.drawText(
					halfDCWidth,
					y,
					mHoursFont0,
					hours[0],
					Graphics.TEXT_JUSTIFY_LEFT
				);
			}			

			// Draw minutes, horizontally centred, vertically top aligned.
			dc.setColor(App.getApp().getProperty("MinutesColour"), Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				halfDCWidth,
				halfDCHeight + (mTwoLineOffset / 2),
				mMinutesFont,
				minutes,
				Graphics.TEXT_JUSTIFY_CENTER
			);

			// If required, draw AM/PM after hours, vertically centred.
			if (!is24Hour) {
				dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					halfDCWidth + charWidth + AM_PM_X_OFFSET, // Breathing space between minutes and AM/PM.
					halfDCHeight - (hoursAscent / 2) - (mTwoLineOffset / 2),
					mSecondsFont,
					amPmText,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

		// Horizontal (single-line) layout.
		} else {

			// Draw hours.
			dc.setColor(App.getApp().getProperty("HoursColour"), Graphics.COLOR_TRANSPARENT);
			if (hours.size() == 2) {
				dc.drawText(
					halfDCWidth - charWidth,
					halfDCHeight,
					mHoursFont0,
					hours[0],
					Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
				);
				dc.drawText(
					halfDCWidth - charWidth,
					halfDCHeight,
					mHoursFont1,
					hours[1],
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			} else {
				dc.drawText(
					halfDCWidth - charWidth,
					halfDCHeight,
					mHoursFont0,
					hours[0],
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}

			// Draw minutes.
			dc.setColor(App.getApp().getProperty("MinutesColour"), Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				halfDCWidth,
				halfDCHeight,
				mMinutesFont,
				minutes,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// If required, draw AM/PM after minutes, vertically centred.
			if (!is24Hour) {
				dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					halfDCWidth + (charWidth * 2) + AM_PM_X_OFFSET, // Breathing space between minutes and AM/PM.
					halfDCHeight,
					mSecondsFont,
					amPmText,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
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