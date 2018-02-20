using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

	private var mThemeColour, mBackgroundColour;
	private var mHoursFont, mMinutesFont, mSecondsFont;

	// Right edge of seconds.
	private var mSecondsRightX;
	
	// Seconds vertically-centred.
	private var mSecondsY;
	
	// Distance between top of font ascent and top of numeric glyph (corresponds to yoffset in .fnt file).
	// Reduces height of clipping rectangle so that seconds can be vertically closer to minutes without clipping minutes text.
	private var mSecondsMinYOffset;

	// TODO: May need to specify mSecondsMaxHeight (maximum height of glyph).

	private var mSecondsClipRect = {
			:x => 0,
			:y => 0,
			:width => 0,
			:height => 0
	};

	private var mAnteMeridiem, mPostMeridiem;

	function initialize(params) {
		Drawable.initialize(params);

		mHoursFont = Ui.loadResource(Rez.Fonts.HoursFont);
		mMinutesFont = Ui.loadResource(Rez.Fonts.MinutesFont);
		mSecondsFont = Ui.loadResource(Rez.Fonts.SecondsFont);

		mSecondsY = params[:secondsY];
		mSecondsMinYOffset = params[:secondsMinYOffset];

		mAnteMeridiem = Ui.loadResource(Rez.Strings.AnteMeridiem);
		mPostMeridiem = Ui.loadResource(Rez.Strings.PostMeridiem);
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

		if (!is24Hour && (hours > 12)) {
			hours = hours % 12;
			isPm = true;
		}

		// Hours always have leading zero, regardless of hour mode, to allow more room for move bar.
		hours = hours.format("%02d");

		dc.setColor(mThemeColour, Graphics.COLOR_TRANSPARENT);

		// Centre combined hours and minutes text (not the same as right-aligning hours and left-aligning minutes).
		// Font has tabular figures (monospaced numbers) even across different weights, so does not matter which of hours or
		// minutes font is used to calculate total width. 
		var totalWidth = dc.getTextWidthInPixels(hours + minutes, mHoursFont);
		var x = (dc.getWidth() / 2) - (totalWidth / 2);
		var halfDCHeight = dc.getHeight() / 2;

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

		// Store right-align X-position of seconds, to avoid having to recalculate when drawing seconds only.
		mSecondsRightX = x;

		// If required, draw am/pm after minutes, vertically centred.
		if (!is24Hour) {
			
			var amPmText;
			if (isPm) {
				amPmText = mPostMeridiem;
			} else {
				amPmText = mAnteMeridiem;
			}

			dc.drawText(
				x,
				halfDCHeight,
				mSecondsFont,
				amPmText,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// If isPartialUpdate flag is set to true, strictly limit the updated screen area: clear only the required rect, but also set
	// the appropriate clip rect before drawring the new text.
	// Seconds are right-aligned beneath minutes.
	// Vertically centre-align with move bar.
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

		// Cache new seconds clip rect for low power mode.
		var secondsDimensions = dc.getTextDimensions(seconds, mSecondsFont);

		// Top-left corner of vertically centred text.
		// Y-position adjusted for font y-offset, to reduce clipping height to absolute minimum.
		mSecondsClipRect[:x] = mSecondsRightX - secondsDimensions[0];
		mSecondsClipRect[:y] = mSecondsY - (secondsDimensions[1] / 2) + mSecondsMinYOffset;

		// Add a pixel in each dimension, as rectangle dimensions appear to be exclusive.
		mSecondsClipRect[:width] = secondsDimensions[0] + 1;
		mSecondsClipRect[:height] = secondsDimensions[1] + 1; // mSecondsMaxHeight + 1;

		if (isPartialUpdate) {
			dc.setClip(
				mSecondsClipRect[:x],
				mSecondsClipRect[:y],
				mSecondsClipRect[:width],
				mSecondsClipRect[:height]
			);
		}

		dc.drawText(
			mSecondsRightX, // Recalculated in draw().
			mSecondsY,
			mSecondsFont,
			seconds,
			Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		if (isPartialUpdate) {
			dc.clearClip();
		}
	}
}