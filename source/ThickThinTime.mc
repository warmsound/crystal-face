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
	private var mSecondsClipRect = {
			:x => 0,
			:y => 0,
			:width => 0,
			:height => 0
	};

	// Has clipping rectangle previously been set for partial updates?
	private var mClipIsSet = false;

	private var mHideSeconds = false;

	private var mAnteMeridiem, mPostMeridiem;
	private var AM_PM_X_OFFSET = 2;
	private var mMeridiemSide;

	function initialize(params) {
		Drawable.initialize(params);

		mVerticalOffset = params[:verticalOffset];

		mSecondsY = params[:secondsY];

		mSecondsClipRect[:x] = params[:secondsX];
		mSecondsClipRect[:y] = params[:secondsClipY];
		mSecondsClipRect[:width] = params[:secondsClipWidth];
		mSecondsClipRect[:height] = params[:secondsClipHeight];

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
			}
							
			if (isPm) {
				amPmText = mPostMeridiem;
			} else {
				amPmText = mAnteMeridiem;
			}
		}

		// Hours always have leading zero, regardless of hour mode, to allow more room for move bar.
		hours = hours.format("%02d");

		dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);

		var x;
		var halfDCWidth = dc.getWidth() / 2;
		var halfDCHeight = dc.getHeight() / 2;

		// Vertical (two-line) layout.
		if (mVerticalOffset) {

			// N.B. Font metrics have been manually adjusted in .fnt files so that ascent = glyph height.
			var hoursAscent = Graphics.getFontAscent(mHoursFont);

			// Draw hours, horizontally centred, vertically bottom aligned.
			dc.drawText(
				halfDCWidth,
				halfDCHeight - hoursAscent - (mVerticalOffset / 2),
				mHoursFont,
				hours,
				Graphics.TEXT_JUSTIFY_CENTER
			);

			// Draw minutes, horizontally centred, vertically top aligned.
			dc.drawText(
				halfDCWidth,
				halfDCHeight + (mVerticalOffset / 2),
				mMinutesFont,
				minutes,
				Graphics.TEXT_JUSTIFY_CENTER
			);

			x = halfDCWidth + (dc.getTextWidthInPixels(hours, mHoursFont) / 2) + AM_PM_X_OFFSET; // Breathing space between minutes and AM/PM.

			// If required, draw AM/PM after hours, vertically centred.
			if (!is24Hour) {
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

			// If required, draw AM/PM after minutes, or before hours, vertically centred.
			if (!is24Hour) {
				if (mMeridiemSide == :left) {
					dc.drawText(
						halfDCWidth - (totalWidth / 2) - AM_PM_X_OFFSET - 2, // Breathing space between minutes and AM/PM.
						halfDCHeight,
						mSecondsFont,
						amPmText,
						Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
					);
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

			// Set clip once, at start of low power mode.
			if (!mClipIsSet) {
				dc.setClip(
					mSecondsClipRect[:x],
					mSecondsClipRect[:y],
					mSecondsClipRect[:width],
					mSecondsClipRect[:height]
				);
				mClipIsSet = true;
			}

			// Can't optimise setting colour once, at start of low power mode, at this goes wrong on real hardware: alternates
			// every second with inverse (e.g. blue text on black, then black text on blue).
			dc.setColor(mThemeColour, /* Graphics.COLOR_RED */ mBackgroundColour);	

			// Clear old rect (assume nothing overlaps seconds text).					
			dc.clear();

		} else {
			mClipIsSet = false;

			// Drawing will not be clipped, so ensure background is transparent in case font height overlaps with another
			// drawable.
			dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);
		}

		dc.drawText(
			mSecondsClipRect[:x],
			mSecondsY,
			mSecondsFont,
			seconds,
			Graphics.TEXT_JUSTIFY_LEFT
		);	
	}
}