using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

	private var mThemeColour, mBackgroundColour;
	private var mHoursFont, mMinutesFont, mSecondsFont;

	// Right edge of seconds for horizontal layouts; left edge of seconds for vertical layouts.
	private var mSecondsX;
	
	// Seconds vertically-centred for horizontal layouts; bottom-aligned for vertical layouts.
	private var mSecondsY;

	private var mSecondsAscent;
	private var mSecondsDimensions;
	
	// Distance between top of font ascent and top of numeric glyph (corresponds to yoffset in .fnt file).
	// Reduces height of clipping rectangle so that seconds can be vertically closer to minutes without clipping minutes text.
	private var mSecondsMinYOffset;

	// Non-null for vertical layouts i.e. hours above minutes.
	private var mVerticalOffset;

	// TODO: May need to specify mSecondsMaxHeight (maximum height of glyph).

	private var mSecondsClipRect = {
			:x => 0,
			:y => 0,
			:width => 0,
			:height => 0
	};

	private var mHideSeconds = false;

	private var mAnteMeridiem, mPostMeridiem;
	private var AM_PM_X_OFFSET = 2;

	function initialize(params) {
		Drawable.initialize(params);

		mSecondsY = params[:secondsY];
		mSecondsMinYOffset = params[:secondsMinYOffset];
		mVerticalOffset = params[:verticalOffset];

		mAnteMeridiem = Ui.loadResource(Rez.Strings.AnteMeridiem);
		mPostMeridiem = Ui.loadResource(Rez.Strings.PostMeridiem);
	}

	function setFonts(hoursFont, minutesFont, secondsFont) {
		mHoursFont = hoursFont;
		mMinutesFont = minutesFont;
		mSecondsFont = secondsFont;

		mSecondsAscent = Graphics.getFontAscent(mSecondsFont);
	}

	function setHideSeconds(hideSeconds) {
		mHideSeconds = hideSeconds;
	}
	
	function draw(dc) {
		mThemeColour = App.getApp().getProperty("ThemeColour");
		mBackgroundColour = App.getApp().getProperty("BackgroundColour");

		drawHoursMinutes(dc);
		if (!mHideSeconds) {
			drawSeconds(dc, /* isPartialUpdate */ false);
		}
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
			x += dc.getTextWidthInPixels(minutes, mMinutesFont);

			// If required, draw AM/PM after minutes, vertically centred.
			if (!is24Hour) {
				dc.drawText(
					x + AM_PM_X_OFFSET, // Breathing space between minutes and AM/PM.
					halfDCHeight,
					mSecondsFont,
					amPmText,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}
		}

		// Cache values for low power mode.
		mSecondsX = x;
		mSecondsDimensions = dc.getTextDimensions("00", mSecondsFont);
	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// If isPartialUpdate flag is set to true, strictly limit the updated screen area: clear only the required rect, but also set
	// the appropriate clip rect before drawring the new text.
	// Horizontal layouts: seconds are right-aligned beneath minutes, vertically centre-align with move bar.
	// Vertical layouts: seconds are left-aligned after minutes, and vertically bottom-aligned.
	function drawSeconds(dc, isPartialUpdate) {
		var clockTime = Sys.getClockTime();
		var seconds = clockTime.sec.format("%02d");

		if (isPartialUpdate) {

			// Clear old rect (assume nothing overlaps seconds text).
			dc.setColor(mThemeColour, mBackgroundColour);			
			dc.setClip(
				mSecondsClipRect[:x],
				mSecondsClipRect[:y],
				mSecondsClipRect[:width],
				mSecondsClipRect[:height]
			);
			dc.clear();

		} else {

			// Drawing will not be clipped, so ensure background is transparent in case font height overlaps with another
			// drawable.
			dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);
		}

		if (mVerticalOffset) {

			// Top-left corner of bottom-aligned text.
			mSecondsClipRect[:x] = mSecondsX;
			mSecondsClipRect[:y] = mSecondsY - mSecondsAscent;

			// Add a pixel in each dimension, as rectangle dimensions appear to be exclusive.
			mSecondsClipRect[:width] = mSecondsDimensions[0] + 1;
			mSecondsClipRect[:height] = mSecondsDimensions[1] + 1; // mSecondsMaxHeight + 1;

		} else {

			// Top-left corner of vertically centred text.
			// Y-position adjusted for font y-offset, to reduce clipping height to absolute minimum.
			mSecondsClipRect[:x] = mSecondsX - mSecondsDimensions[0];
			mSecondsClipRect[:y] = mSecondsY - (mSecondsDimensions[1] / 2) + mSecondsMinYOffset;

			// Add a pixel in each dimension, as rectangle dimensions appear to be exclusive.
			mSecondsClipRect[:width] = mSecondsDimensions[0] + 1;
			mSecondsClipRect[:height] = mSecondsDimensions[1] - mSecondsMinYOffset + 1; // mSecondsMaxHeight + 1;

		}

		if (isPartialUpdate) {
			dc.setClip(
				mSecondsClipRect[:x],
				mSecondsClipRect[:y],
				mSecondsClipRect[:width],
				mSecondsClipRect[:height]
			);
		}

		if (mVerticalOffset) {
			dc.drawText(
				mSecondsX, // Recalculated in draw().
				mSecondsY - mSecondsAscent,
				mSecondsFont,
				seconds,
				Graphics.TEXT_JUSTIFY_LEFT
			);
		} else {
			dc.drawText(
				mSecondsX, // Recalculated in draw().
				mSecondsY,
				mSecondsFont,
				seconds,
				Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
		

		if (isPartialUpdate) {
			dc.clearClip();
		}
	}
}